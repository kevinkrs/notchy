import ServiceManagement
import os

public enum LoginItem {
    private static let logger = Logger(subsystem: "com.krauskevin.notchy", category: "loginitem")

    /// `SMAppService.mainApp.status == .enabled`
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// register()/unregister(); errors logged.
    public static func set(_ enabled: Bool) {
        if enabled, SMAppService.mainApp.status == .requiresApproval {
            // Already registered; the user must approve it in System Settings.
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            let action = enabled ? "register" : "unregister"
            logger.error("Failed to \(action, privacy: .public) login item: \(error.localizedDescription, privacy: .public)")
        }
    }
}
