import AppKit
import ApplicationServices

/// One menu bar extra of another app, found through its Accessibility tree
/// (`AXExtrasMenuBar` → children). On macOS 26 the window list is useless here: every
/// status item window is owned by Control Center, so AX is the only way to know the real owner.
struct MenuBarItem: Identifiable, Hashable {
    var id: AXUIElement { element }
    /// The status item's AX element; supports `kAXPressAction`.
    let element: AXUIElement
    let ownerPID: pid_t
    /// App display name.
    let ownerName: String
    /// `AXTitle`, else `AXDescription`, else `ownerName`.
    let title: String
    /// Quartz coordinates (origin top-left of main display). Negative x = pushed off by a spacer.
    let frame: CGRect
    /// Fully inside the usable menu bar area (right of the notch, inside the screen).
    let isOnScreen: Bool

    var icon: NSImage? { NSRunningApplication(processIdentifier: ownerPID)?.icon }

    static func == (a: MenuBarItem, b: MenuBarItem) -> Bool { CFEqual(a.element, b.element) }
    func hash(into h: inout Hasher) { h.combine(CFHash(element)) }
}
