import CoreGraphics

/// Finds other apps' menu bar items via the window list. Needs no permission.
enum ItemScanner {
    /// All windows on the status bar layer (`kCGStatusWindowLevel` == 25) owned by other
    /// processes, minus `excluding` (Notchy's own item windows), sorted by `frame.minX`.
    /// Works while items are pushed off screen: the windows still exist with negative x.
    static func scan(excluding: Set<CGWindowID>) -> [MenuBarItem] {
        fatalError("TODO: agent B")
    }
}
