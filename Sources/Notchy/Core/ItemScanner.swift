import AppKit
import ApplicationServices

/// Finds other apps' menu bar extras through Accessibility. Needs the Accessibility permission;
/// prompts and returns `[]` until granted.
enum ItemScanner {
    static func scan() -> [MenuBarItem] {
        guard Permissions.hasAccessibility else {
            Permissions.requestAccessibility()
            return []
        }
        let screen = NSScreen.main
        let leftBound = screen?.auxiliaryTopRightArea?.minX ?? screen?.frame.minX ?? 0
        let rightBound = screen?.frame.maxX ?? .greatestFiniteMagnitude
        let me = getpid()
        var items: [MenuBarItem] = []

        for app in NSWorkspace.shared.runningApplications
        where app.processIdentifier != me
            && (app.activationPolicy != .prohibited || app.bundleIdentifier == "com.apple.controlcenter")
        {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, 0.2) // unresponsive apps must not stall the toggle
            guard let bar: AXUIElement = attribute(axApp, kAXExtrasMenuBarAttribute),
                  let children: [AXUIElement] = attribute(bar, kAXChildrenAttribute)
            else { continue }
            let name = app.localizedName ?? "?"
            for child in children {
                guard let origin: CGPoint = value(child, kAXPositionAttribute, .cgPoint),
                      let size: CGSize = value(child, kAXSizeAttribute, .cgSize), size.width > 0
                else { continue }
                let frame = CGRect(origin: origin, size: size)
                let title = nonEmpty(attribute(child, kAXTitleAttribute))
                    ?? nonEmpty(attribute(child, kAXDescriptionAttribute)) ?? name
                items.append(MenuBarItem(
                    element: child, ownerPID: app.processIdentifier, ownerName: name, title: title, frame: frame,
                    isOnScreen: frame.minX >= leftBound && frame.maxX <= rightBound))
            }
        }
        items.sort { $0.frame.minX < $1.frame.minX }
        Diagnostics.log("scan", items.map { "\($0.ownerName)/\($0.title)@\(Int($0.frame.minX))w\(Int($0.frame.width))\($0.isOnScreen ? "" : "*")" }.joined(separator: " "))
        return items
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var out: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &out) == .success else { return nil }
        return out as? T
    }

    private static func value<T>(_ element: AXUIElement, _ name: String, _ type: AXValueType) -> T? {
        guard let raw: AXValue = attribute(element, name) else { return nil }
        let storage = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { storage.deallocate() }
        return AXValueGetValue(raw, type, storage) ? storage.pointee : nil
    }

    private static func nonEmpty(_ s: String?) -> String? { (s?.isEmpty ?? true) ? nil : s }
}
