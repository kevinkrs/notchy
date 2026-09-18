import AppKit

/// Floating bar just below the menu bar showing hidden items as thumbnails. Items that would
/// vanish behind the notch (too many to fit) are always reachable here.
@MainActor
final class OverflowPanel {
    var onSelect: ((MenuBarItem) -> Void)?
    var onDismiss: (() -> Void)?
    var isVisible: Bool { fatalError("TODO: agent C") }

    init() { fatalError("TODO: agent C") }

    /// Shows (or refreshes) the panel right-aligned under `toggleFrame` (AppKit coords) on `screen`.
    /// Items without an image fall back to `item.icon` + `ownerName`.
    func show(items: [MenuBarItem], images: [CGWindowID: CGImage], toggleFrame: CGRect, on screen: NSScreen) {
        fatalError("TODO: agent C")
    }
    func hide() { fatalError("TODO: agent C") }
}
