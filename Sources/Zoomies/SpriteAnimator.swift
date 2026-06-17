import AppKit
import ZoomiesCore

final class SpriteAnimator {
    private weak var statusItem: NSStatusItem?
    private var frames: [NSImage] = []
    private var index = 0
    private var load: Double = 0
    private var timer: Timer?
    private var scheduledFPS: Int = -1   // fps bucket the current timer was scheduled for

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func setAnimal(_ animal: Animal) {
        frames = FrameLoader.load(animal)
        index = 0
        showCurrentFrame()
        restartTimer()
    }

    /// Updates the load and re-paces the animation only when the speed bucket
    /// actually changes — avoids resetting the frame clock on every CPU sample
    /// (which would otherwise cause a periodic stutter).
    func setLoad(_ load: Double) {
        self.load = load
        if reduceMotion {
            if timer != nil { restartTimer() }   // entered reduce-motion: drop to static
        } else {
            let fps = Int(SpeedMapping.fps(forLoad: load).rounded())
            if fps != scheduledFPS { restartTimer() }
        }
    }

    func start() { restartTimer() }

    func stop() {
        timer?.invalidate()
        timer = nil
        scheduledFPS = -1
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = nil
        guard !frames.isEmpty else { return }
        // Respect Reduce Motion: show a single static frame, no animation.
        guard !reduceMotion else { showCurrentFrame(); scheduledFPS = -1; return }
        scheduledFPS = Int(SpeedMapping.fps(forLoad: load).rounded())
        let interval = SpeedMapping.frameInterval(forLoad: load)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func advance() {
        guard !frames.isEmpty else { return }
        index = (index + 1) % frames.count
        showCurrentFrame()
    }

    private func showCurrentFrame() {
        guard let button = statusItem?.button, !frames.isEmpty else { return }
        button.image = frames[index]
    }
}
