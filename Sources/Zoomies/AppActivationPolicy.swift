import AppKit

/// Reference-counted Dock/foreground policy for a menu-bar agent app.
/// The app runs as `.accessory` (no Dock icon); while a real window like Settings
/// is open it becomes `.regular` so it can take focus, then returns to `.accessory`.
@MainActor
enum AppActivationPolicy {
    private static var count = 0

    static func enter() {
        count += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func leave() {
        count = max(0, count - 1)
        guard count == 0 else { return }
        Task { @MainActor in NSApp.setActivationPolicy(.accessory) }
    }
}
