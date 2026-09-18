import AppKit

/// One status-bar-layer window belonging to another process.
struct MenuBarItem: Identifiable, Hashable {
    var id: CGWindowID { windowID }
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    /// Quartz coordinates: origin top-left of the main display, y grows downward.
    let frame: CGRect
    let isOnScreen: Bool

    /// Same rect in AppKit coordinates (origin bottom-left of the main display).
    var nsFrame: CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    var icon: NSImage? { NSRunningApplication(processIdentifier: ownerPID)?.icon }
}
