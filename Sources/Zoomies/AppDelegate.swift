import AppKit
import Combine
import ZoomiesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var animator: SpriteAnimator!
    private var menuController: MenuController!
    private let cpu = CPUMonitor()
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastLoad: Double = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        animator = SpriteAnimator(statusItem: statusItem)
        animator.setAnimal(settings.selectedAnimal)

        menuController = MenuController(onOpenSettings: { SettingsWindowController.show() })
        statusItem.menu = menuController.buildMenu()

        // React to selection changes from the menu, Surprise Me, or the Settings window.
        settings.$selectedAnimalID
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] id in self?.animator.setAnimal(AnimalLibrary.animal(withID: id)) }
            .store(in: &cancellables)
        settings.$showPercentage
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        cpu.onUpdate = { [weak self] cpuLoad in
            guard let self else { return }
            let memory = MemorySampler.usedFraction()
            let raw = self.settings.source.effective(cpu: cpuLoad, memory: memory)
            self.lastLoad = self.settings.scaled(raw)
            self.animator.setLoad(self.lastLoad)
            self.refreshTitle()
            self.menuController.setLoadText("\(self.settings.source.displayName): \(self.percent)%")
        }
        cpu.start(interval: 2.0)
        animator.start()
    }

    private var percent: Int { Int((lastLoad * 100).rounded()) }

    private func refreshTitle() {
        statusItem.button?.title = settings.showPercentage ? " \(percent)%" : ""
    }

    func applicationWillTerminate(_ notification: Notification) {
        cpu.stop()
        animator.stop()
    }
}
