import ApplicationServices

enum Permissions {
    static var hasAccessibility: Bool { AXIsProcessTrusted() }
    /// Prompts once; needed to post synthetic clicks (CGEvent) at other apps' items.
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
