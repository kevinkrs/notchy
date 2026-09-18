import CoreGraphics

/// Thumbnails of menu bar items via ScreenCaptureKit. Needs Screen Recording permission.
enum ItemCapture {
    /// Captures each item's window independent of its on-screen position
    /// (`SCContentFilter(desktopIndependentWindow:)`). Missing key = capture failed.
    static func capture(_ items: [MenuBarItem]) async -> [CGWindowID: CGImage] {
        fatalError("TODO: agent B")
    }
}
