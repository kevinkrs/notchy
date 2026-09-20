import AppKit
import ApplicationServices

/// Moves another app's item into a section by faking the only thing macOS accepts: a ⌘-drag in the
/// menu bar. Ice's recipe: ⌘-mouse-down at the item's frame, mouse-up at the destination, both posted to
/// the session event tap, no dragged events. The item does not have to be on screen: items pushed off by
/// a spacer keep live windows at their negative x. Items macOS drops behind the notch do not, so callers
/// collapse first (everything hidden is pushed, nothing is dropped).
@MainActor
enum ItemMover {
    struct Dividers { let hidden: CGRect; let alwaysHidden: CGRect } // AppKit frames, only x is used

    /// Drop x just beside the divider that bounds `section` on the right (hidden / always hidden) or the
    /// hidden divider's right edge (visible). Works in every state as long as the dividers are not
    /// dropped behind the notch, hence `.collapsed`.
    static func destinationX(for section: Section, dividers d: Dividers) -> CGFloat {
        switch section {
        case .visible: d.hidden.maxX + 4
        case .hidden: d.hidden.minX - 4
        case .alwaysHidden: d.alwaysHidden.minX - 4
        }
    }

    /// Returns true when the item's frame changed. Retries up to three times (Ice does five).
    static func move(_ item: MenuBarItem, to section: Section, dividers: Dividers,
                     rescan: @MainActor () -> MenuBarItem?) async -> Bool {
        let targetX = destinationX(for: section, dividers: dividers)
        let cursor = NSEvent.mouseLocation
        defer { restoreCursor(cursor) }
        for attempt in 1...3 {
            guard let fresh = rescan() else { return false }
            let from = CGPoint(x: fresh.frame.midX, y: fresh.frame.midY)
            Diagnostics.log("mover", "\(fresh.title) #\(attempt) from \(Int(from.x)) to \(Int(targetX)) [\(section)]")
            post(.leftMouseDown, from, flags: .maskCommand)
            // Wait for the grab to register (Ice: frame change within 50 ms).
            for _ in 0..<5 {
                try? await Task.sleep(for: .milliseconds(20))
                if rescan()?.frame != fresh.frame { break }
            }
            post(.leftMouseUp, CGPoint(x: targetX, y: from.y), flags: [])
            try? await Task.sleep(for: .milliseconds(150))
            if let after = rescan(), after.frame.minX != fresh.frame.minX {
                Diagnostics.log("mover", "\(fresh.title) moved to \(Int(after.frame.minX))")
                return true
            }
        }
        Diagnostics.log("mover", "\(item.title): frame unchanged after 3 attempts")
        return false
    }

    private static func post(_ type: CGEventType, _ p: CGPoint, flags: CGEventFlags) {
        let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
        e?.flags = flags
        e?.post(tap: .cgSessionEventTap)
    }

    /// `NSEvent.mouseLocation` is AppKit (bottom-left origin); warp wants Quartz.
    private static func restoreCursor(_ appKit: CGPoint) {
        guard let screen = NSScreen.screens.first else { return }
        CGWarpMouseCursorPosition(CGPoint(x: appKit.x, y: screen.frame.maxY - appKit.y))
    }
}
