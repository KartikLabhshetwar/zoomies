import AppKit
import ZoomiesCore

/// Builds and owns the menu-bar click menu: a live load readout plus Settings and Quit.
final class MenuController: NSObject {
    private let menu = NSMenu()
    private let loadItem = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
    private let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init()
    }

    func buildMenu() -> NSMenu {
        loadItem.isEnabled = false
        menu.addItem(loadItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: "Quit Zoomies",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    /// Live load readout shown at the top of the menu (e.g. "CPU: 23%").
    func setLoadText(_ text: String) {
        loadItem.title = text
    }

    @objc private func openSettings() {
        onOpenSettings()
    }
}
