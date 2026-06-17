import AppKit
import ZoomiesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var animator: SpriteAnimator!
    private let cpu = CPUMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        animator = SpriteAnimator(statusItem: statusItem)
        let saved = UserDefaults.standard.string(forKey: "selectedAnimal") ?? AnimalLibrary.default.id
        animator.setAnimal(AnimalLibrary.animal(withID: saved))

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Zoomies", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        cpu.onUpdate = { [weak self] load in
            self?.animator.setLoad(load)
        }
        cpu.start(interval: 2.0)
        animator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        cpu.stop()
        animator.stop()
    }
}
