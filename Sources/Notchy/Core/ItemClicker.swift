import AppKit

/// Forwards a click from the overflow panel to the real menu bar item.
@MainActor
enum ItemClicker {
    /// 1. `reveal()` (delegate expands the section so the item gets a real on-screen frame),
    /// 2. poll `rescan()` briefly until the item is on screen,
    /// 3. on screen → post CGEvent left mouse down/up at its centre (needs Accessibility),
    ///    still off screen (macOS overflow) → AX press on the owner's menu bar extra as fallback.
    static func click(_ item: MenuBarItem, reveal: @MainActor () -> Void, rescan: @MainActor () -> MenuBarItem?) async {
        fatalError("TODO: agent C")
    }
}
