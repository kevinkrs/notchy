import AppKit
import ApplicationServices

/// Forwards a click from the overflow panel to the real menu bar item.
@MainActor
enum ItemClicker {
    /// 1. `reveal()` (delegate expands the section so the item gets a real on-screen frame),
    /// 2. poll `rescan()` briefly until the item is on screen,
    /// 3. on screen → post CGEvent left mouse down/up at its centre,
    ///    still off screen (macOS overflow) → `kAXPressAction` on the item's element as fallback.
    /// Accessibility is already granted (the scanner needs it), so no permission check here.
    static func click(_ item: MenuBarItem, reveal: @MainActor () -> Void, rescan: @MainActor () -> MenuBarItem?) async {
        reveal()
        var fresh: MenuBarItem?
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(40))
            fresh = rescan()
            if fresh?.isOnScreen == true { break }
        }
        guard let fresh else {
            return Diagnostics.log("clicker", "\(item.title) vanished after reveal")
        }
        if fresh.isOnScreen {
            await postClick(at: CGPoint(x: fresh.frame.midX, y: fresh.frame.midY))
        } else {
            // ponytail: pressing an off-screen extra opens its menu at the screen edge; good enough for
            // the macOS-overflow case, revisit if users complain.
            Diagnostics.log("clicker", "\(fresh.title) still off screen, AX press fallback")
            let err = AXUIElementPerformAction(fresh.element, kAXPressAction as CFString)
            if err != .success { Diagnostics.log("clicker", "\(fresh.title): AX press failed \(err.rawValue)") }
        }
    }

    /// `point` in Quartz coordinates (what `MenuBarItem.frame` already is).
    private static func postClick(at point: CGPoint) async {
        CGWarpMouseCursorPosition(point)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(30))
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }
}
