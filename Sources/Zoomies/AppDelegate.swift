import AppKit
import Combine
import ZoomiesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var animator: SpriteAnimator!
    private var menuController: MenuController!
    private let mouseMonitor = MouseDirectionMonitor()
    private let cpu = CPUMonitor()
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastCPULoad: Double = 0
    private var lastMemoryLoad: Double = 0
    private var lastRawLoad: Double = 0   // unscaled, for display
    private var lastLoad: Double = 0      // scaled by sensitivity, for animation

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)

        animator = SpriteAnimator(statusItem: statusItem)
        animator.setAnimal(AnimalLibrary.default)

        menuController = MenuController(onOpenSettings: { SettingsWindowController.show() })
        statusItem.menu = menuController.buildMenu()

        settings.$showPercentage
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)
        // Immediately recompute speed when source or sensitivity changes — don't wait
        // for the next 2-second CPU sample, which would make the slider feel broken.
        settings.$source
            .dropFirst()
            .sink { [weak self] _ in self?.recomputeLoad() }
            .store(in: &cancellables)
        settings.$sensitivity
            .dropFirst()
            .sink { [weak self] _ in self?.recomputeLoad() }
            .store(in: &cancellables)

        cpu.onUpdate = { [weak self] cpuLoad in
            guard let self else { return }
            self.lastCPULoad = cpuLoad
            self.lastMemoryLoad = MemorySampler.usedFraction()
            self.recomputeLoad()
        }
        cpu.start(interval: 2.0)
        animator.start()

        // Turn the cat to face whichever way the cursor is moving.
        mouseMonitor.onChange = { [weak self] direction in
            self?.animator.setFacing(direction == .right ? .right : .left)
        }
        mouseMonitor.start()
    }

    private var percent: Int { Int((lastRawLoad * 100).rounded()) }

    private func recomputeLoad() {
        lastRawLoad = settings.source.effective(cpu: lastCPULoad, memory: lastMemoryLoad)
        lastLoad = settings.scaled(lastRawLoad)
        animator.setLoad(lastLoad)
        refreshTitle()
        menuController.setLoadText("\(settings.source.displayName): \(percent)%")
    }

    private func refreshTitle() {
        statusItem.button?.title = settings.showPercentage ? " \(percent)%" : ""
    }

    func applicationWillTerminate(_ notification: Notification) {
        cpu.stop()
        animator.stop()
        mouseMonitor.stop()
    }
}
