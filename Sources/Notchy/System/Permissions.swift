import ApplicationServices
import CoreGraphics

enum Permissions {
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }
    /// Prompts once; user grants in System Settings > Privacy & Security > Screen Recording.
    @discardableResult static func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }
    /// Prompts once; needed to post synthetic clicks (CGEvent) at other apps' items.
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
