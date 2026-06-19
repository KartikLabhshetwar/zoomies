import AppKit
import Combine
import ZoomiesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pet: PetController!
    private var menuController: MenuController!
    private let cpu = CPUMonitor()
    private let gpu = GPUMonitor()
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastCPULoad: Double = 0
    private var lastGPULoad: Double = 0
    private var lastMemoryLoad: Double = 0
    private var lastRawLoad: Double = 0   // 0...1 system load — drives both the % and the run speed

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        menuController = MenuController(onOpenSettings: { SettingsWindowController.show() })
        statusItem.menu = menuController.buildMenu()

        pet = PetController(statusItem: statusItem)
        pet.setAnimal(AnimalLibrary.animal(withID: settings.animalID))
        pet.setSpeed(settings.speed)

        settings.$showPercentage
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)
        settings.$source
            .dropFirst()
            .sink { [weak self] _ in self?.recomputeLoad() }
            .store(in: &cancellables)
        // Speed changes re-pace immediately — don't wait for the next sample.
        settings.$speed
            .dropFirst()
            .sink { [weak self] speed in self?.pet.setSpeed(speed) }
            .store(in: &cancellables)
        // Switch the roaming critter live when the user picks a different animal.
        settings.$animalID
            .dropFirst()
            .sink { [weak self] id in self?.pet.setAnimal(AnimalLibrary.animal(withID: id)) }
            .store(in: &cancellables)

        cpu.onUpdate = { [weak self] cpuLoad in
            guard let self else { return }
            self.lastCPULoad = cpuLoad
            self.lastMemoryLoad = MemorySampler.usedFraction()
            self.recomputeLoad()
        }
        gpu.onUpdate = { [weak self] gpuLoad in
            guard let self else { return }
            self.lastGPULoad = gpuLoad
            self.recomputeLoad()
        }
        // 2 s sampling (with timer leeway) keeps wake-ups low for old/low-power Macs;
        // the pet animates off its own frame timer, so this only re-paces it, never stutters.
        cpu.start(interval: 2.0)
        gpu.start()   // 2 s default, sampled off the main thread (see GPUMonitor)
        refreshTitle()
        pet.start()
    }

    private var percent: Int { Int((lastRawLoad * 100).rounded()) }

    private func recomputeLoad() {
        lastRawLoad = settings.source.effective(cpu: lastCPULoad, gpu: lastGPULoad, memory: lastMemoryLoad)
        // Drive the run speed from the SAME load shown as the percentage. Using a
        // different signal (e.g. max of CPU/GPU) made the pet sprint while the label
        // read 20–30%, since a busy unmonitored source secretly drove the animation.
        pet.setLoad(lastRawLoad)
        refreshTitle()
        menuController.setMetrics(cpu: lastCPULoad, gpu: lastGPULoad, ram: lastMemoryLoad)
    }

    private var sourceLabel: String {
        switch settings.source {
        case .cpu:    return "CPU"
        case .gpu:    return "GPU"
        case .memory: return "RAM"
        case .max:    return "MAX"
        }
    }

    private func refreshTitle() {
        guard let button = statusItem.button else { return }
        // Pet image is managed by PetController; we only update the text label here.
        // The leading space adds a gap so the readout doesn't hug the animal sprite.
        button.title = settings.showPercentage ? "  \(sourceLabel) \(percent)%" : ""
    }

    func applicationWillTerminate(_ notification: Notification) {
        cpu.stop()
        gpu.stop()
        pet.stop()
    }
}
