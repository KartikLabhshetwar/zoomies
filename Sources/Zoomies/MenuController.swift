import AppKit
import ServiceManagement
import ZoomiesCore

final class MenuController: NSObject {
    private let animator: SpriteAnimator
    private let menu = NSMenu()
    private let cpuItem = NSMenuItem(title: "CPU: --%", action: nil, keyEquivalent: "")
    private var animalSubmenu: NSMenu?

    private var selectedAnimalID: String {
        get { UserDefaults.standard.string(forKey: "selectedAnimal") ?? AnimalLibrary.default.id }
        set { UserDefaults.standard.set(newValue, forKey: "selectedAnimal") }
    }

    init(animator: SpriteAnimator) {
        self.animator = animator
        super.init()
    }

    func buildMenu() -> NSMenu {
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)
        menu.addItem(.separator())

        let animalItem = NSMenuItem(title: "Animal", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for animal in AnimalLibrary.all {
            let item = NSMenuItem(title: animal.name, action: #selector(selectAnimal(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = animal.id
            item.state = (animal.id == selectedAnimalID) ? .on : .off
            submenu.addItem(item)
        }
        animalItem.submenu = submenu
        animalSubmenu = submenu
        menu.addItem(animalItem)
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Zoomies",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    func updateCPU(_ load: Double) {
        cpuItem.title = "CPU: \(Int((load * 100).rounded()))%"
    }

    @objc private func selectAnimal(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        selectedAnimalID = id
        animator.setAnimal(AnimalLibrary.animal(withID: id))
        animalSubmenu?.items.forEach {
            $0.state = (($0.representedObject as? String) == id) ? .on : .off
        }
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            NSLog("Zoomies: launch-at-login toggle failed: \(error.localizedDescription)")
        }
    }
}
