import AppKit
import ZoomiesCore

/// Builds and owns the menu-bar click menu. Animal selection flows through
/// `AppSettings` so the menu, Surprise Me, and the Settings window stay in sync.
final class MenuController: NSObject, NSMenuDelegate {
    private let menu = NSMenu()
    private let loadItem = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
    private var animalSubmenu: NSMenu?
    private let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        super.init()
    }

    func buildMenu() -> NSMenu {
        menu.delegate = self

        loadItem.isEnabled = false
        menu.addItem(loadItem)
        menu.addItem(.separator())

        let animalItem = NSMenuItem(title: "Animal", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for animal in AnimalLibrary.all {
            let item = NSMenuItem(title: animal.name, action: #selector(selectAnimal(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = animal.id
            submenu.addItem(item)
        }
        animalItem.submenu = submenu
        animalSubmenu = submenu
        menu.addItem(animalItem)

        let surprise = NSMenuItem(title: "Surprise Me", action: #selector(surpriseMe), keyEquivalent: "")
        surprise.target = self
        menu.addItem(surprise)
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

    // Refresh checkmarks when the menu opens — the selection may have changed via
    // Surprise Me or the Settings window since it was last built.
    func menuWillOpen(_ menu: NSMenu) {
        let id = AppSettings.shared.selectedAnimalID
        animalSubmenu?.items.forEach { $0.state = (($0.representedObject as? String) == id) ? .on : .off }
    }

    @objc private func selectAnimal(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        AppSettings.shared.selectedAnimalID = id
    }

    @objc private func surpriseMe() {
        let current = AppSettings.shared.selectedAnimalID
        let pick = AnimalLibrary.all.map(\.id).filter { $0 != current }.randomElement()
        if let pick { AppSettings.shared.selectedAnimalID = pick }
    }

    @objc private func openSettings() {
        onOpenSettings()
    }
}
