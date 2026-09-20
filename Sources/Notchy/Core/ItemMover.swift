import AppKit
import ApplicationServices

/// Moves another app's item into a section by faking the only thing macOS accepts: a ⌘-drag in the
/// menu bar. Experiment (2026-09-20): items macOS drops behind the notch keep real frames under the
/// notch, so the grab may work there too.
@MainActor
enum ItemMover {
    struct Dividers { let hidden: CGRect; let alwaysHidden: CGRect } // AppKit frames, only x is used

    /// 1. `reveal()` (delegate goes to `.all` so both dividers and the item get real frames),
    /// 2. poll until the item is no longer spacer-pushed (x > -1000) and dividers are on screen,
    /// 3. ⌘-mouse-down on the item, drag to just beside the target divider, release.
    static func move(_ item: MenuBarItem, to section: Section, reveal: @MainActor () -> Void,
                     rescan: @MainActor () -> MenuBarItem?, dividers: @MainActor () -> Dividers?) async {
        reveal()
        var fresh: MenuBarItem?, divs: Dividers?
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(60))
            fresh = rescan(); divs = dividers()
            if let f = fresh, f.frame.minX > -1000, let d = divs, d.hidden.minX > 0, d.alwaysHidden.minX > 0 { break }
        }
        guard let fresh, let divs, fresh.frame.minX > -1000 else {
            return Diagnostics.log("mover", "\(item.title): no usable frame after reveal")
        }
        let half = fresh.frame.width / 2 + 2
        let targetX: CGFloat = switch section {
        case .visible: divs.hidden.maxX + half            // just right of the hidden divider
        case .hidden: divs.hidden.minX - half             // just left of it (rightmost hidden)
        case .alwaysHidden: divs.alwaysHidden.minX - half // just left of the always-hidden divider
        }
        let y = fresh.frame.midY
        Diagnostics.log("mover", "\(fresh.title) \(fresh.isOnScreen ? "" : "(behind notch) ")from \(Int(fresh.frame.midX)) to \(Int(targetX)) [\(section)]")
        await drag(from: CGPoint(x: fresh.frame.midX, y: y), to: CGPoint(x: targetX, y: y))
    }

    private static func drag(from: CGPoint, to: CGPoint) async {
        func post(_ type: CGEventType, _ p: CGPoint) {
            let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
        CGWarpMouseCursorPosition(from)
        post(.leftMouseDown, from)
        try? await Task.sleep(for: .milliseconds(80))
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            post(.leftMouseDragged, CGPoint(x: from.x + (to.x - from.x) * t, y: from.y))
            try? await Task.sleep(for: .milliseconds(25))
        }
        try? await Task.sleep(for: .milliseconds(80))
        post(.leftMouseUp, to)
    }
}
