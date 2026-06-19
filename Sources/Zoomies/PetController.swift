import AppKit
import ZoomiesCore

/// Drives the 2-frame run animation inside the menu-bar status item.
/// Speed scales with system load; facing direction tracks the cursor.
final class PetController {
    private weak var statusItem: NSStatusItem?

    private var leftFrames:  [NSImage] = []
    private var rightFrames: [NSImage] = []
    private var direction: DirectionTracker.Direction = .left

    private var frames: [NSImage] { direction == .left ? leftFrames : rightFrames }

    private var index = 0
    private var load:  Double = 0
    private var speed: Double = 1.0
    private var timer: Timer?
    private var scheduledFPS: Int = -1

    private let cursorMonitor = MouseDirectionMonitor()

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil)
        cursorMonitor.onChange = { [weak self] newDirection in
            guard let self, newDirection != self.direction else { return }
            self.direction = newDirection
            self.showCurrentFrame()
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
        cursorMonitor.stop()
    }

    func setAnimal(_ animal: Animal) {
        let pair = FrameLoader.loadRunFrames(animal)
        leftFrames  = pair.left
        rightFrames = pair.right
        index = 0
        showCurrentFrame()
        restartTimer()
    }

    /// Re-paces the animation when the load bucket changes.
    func setLoad(_ load: Double) {
        self.load = load
        if reduceMotion {
            if timer != nil { restartTimer() }
        } else {
            let fps = Int(SpeedMapping.fps(forLoad: load, speed: speed).rounded())
            if fps != scheduledFPS { restartTimer() }
        }
    }

    func setSpeed(_ speed: Double) {
        self.speed = speed
        restartTimer()
    }

    func start() {
        restartTimer()
        cursorMonitor.start()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        scheduledFPS = -1
        cursorMonitor.stop()
    }

    @objc private func accessibilityChanged() { restartTimer() }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        guard !leftFrames.isEmpty else { return }
        guard !reduceMotion else { showCurrentFrame(); scheduledFPS = -1; return }
        scheduledFPS = Int(SpeedMapping.fps(forLoad: load, speed: speed).rounded())
        let interval = SpeedMapping.frameInterval(forLoad: load, speed: speed)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.advance() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func advance() {
        guard !leftFrames.isEmpty else { return }
        index = (index + 1) % leftFrames.count
        showCurrentFrame()
    }

    private func showCurrentFrame() {
        guard let button = statusItem?.button, !frames.isEmpty else { return }
        button.image = frames[index]
    }
}
