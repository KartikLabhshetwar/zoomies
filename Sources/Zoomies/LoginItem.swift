import ServiceManagement

/// Thin wrapper over SMAppService for the "Launch at Login" toggle.
/// Failures are logged, never fatal (unsigned dev builds may report .requiresApproval).
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Zoomies: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }
}
