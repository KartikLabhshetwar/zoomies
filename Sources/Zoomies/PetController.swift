import AppKit
import QuartzCore
import ZoomiesCore

/// Drives the GIF-based pet inside the menu-bar status item.
///
/// A main-thread `Timer` (run in `.common` mode so it keeps firing during menu tracking)
/// ticks a pure `PetAnimator`, which picks the gait state (idle/walk/walk_fast/run) from
/// system load and advances frames by their native GIF durations. A `Timer` is used rather
/// than `CADisplayLink`: a status-item button's window is never key/active, so an
/// `NSView`-vended display link never fires for it. System load and the user's speed only
/// move the animator's inputs, so the cycle never resets. Each tick reassigns the button
/// image only when the visible frame actually changes, keeping a menu-bar pet cheap.
final class PetController {
    private weak var statusItem: NSStatusItem?

    private var clips = FrameLoader.PetClips(states: [:], thumbnail: nil)
    private var animator = PetAnimator()
    private var direction: DirectionTracker.Direction = .left

    private var load: Double = 0
    private var speed: Double = 1.0

    /// ~30 Hz is smooth to the eye and light on battery; the source GIFs only run ~8 fps,
    /// so the animator advances frames by their own durations regardless of tick rate.
    private static let tickInterval: TimeInterval = 1.0 / 30.0
    private var timer: Timer?
    private var lastTimestamp: CFTimeInterval = 0
    // Last image shown, so the button image is only reassigned when it truly changes.
    private var shownState: PetState?
    private var shownFrame = -1
    private var shownLeft = true

    private let cursorMonitor = MouseDirectionMonitor()

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        cursorMonitor.onChange = { [weak self] newDirection in
            guard let self, newDirection != self.direction else { return }
            self.direction = newDirection
            self.render(force: true)   // flip facing immediately, mid-stride
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timer?.invalidate()
        cursorMonitor.stop()
    }

    func setPet(_ animal: Animal, colorID: String) {
        clips = FrameLoader.loadClips(animal, colorID: colorID)
        animator = PetAnimator()
        animator.setSpeed(speed)
        animator.setLoad(load)
        syncDurations()
        shownState = nil; shownFrame = -1
        render(force: true)
    }

    /// New system load (0...1). Only nudges the gait; the eased pace does the rest.
    func setLoad(_ load: Double)  { self.load = load;  animator.setLoad(load) }
    func setSpeed(_ speed: Double) { self.speed = speed; animator.setSpeed(speed) }

    func start() { startTicking(); cursorMonitor.start() }

    func stop() {
        timer?.invalidate(); timer = nil
        cursorMonitor.stop()
    }

    // MARK: - Tick loop

    private func startTicking() {
        guard timer == nil else { return }
        lastTimestamp = 0
        let t = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the pet animating while a menu is open or the user is scrolling.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        render(force: true)
    }

    private func tick() {
        // Reduce-motion: hold a calm frame, but keep facing responsive via render().
        guard !reduceMotion else { render(); return }
        let now = CACurrentMediaTime()
        // Clamp dt so a long gap (display sleep/wake) can't fling the cycle.
        let raw = lastTimestamp > 0 ? now - lastTimestamp : Self.tickInterval
        lastTimestamp = now
        if animator.advance(by: min(max(raw, 0), 0.1)) {
            syncDurations()   // state changed — hand the animator the new cycle's durations
        }
        render()
    }

    @objc private func accessibilityChanged() {
        lastTimestamp = 0                 // resume cleanly, no dt spike
        render(force: true)
    }

    // MARK: - Rendering

    private func syncDurations() {
        if let d = clips.states[animator.state]?.durations { animator.setDurations(d) }
    }

    /// Pick the image for the current gait state + facing, assigning it only when it changed
    /// (or `force`). With reduce-motion on, hold a calm idle frame.
    private func render(force: Bool = false) {
        guard let button = statusItem?.button else { return }
        let state: PetState = reduceMotion
            ? (clips.states[.idle] != nil ? .idle : animator.state)
            : animator.state
        guard let clip = clips.states[state] else { return }
        let frames = direction == .left ? clip.left : clip.right
        guard !frames.isEmpty else { return }
        let frame = reduceMotion ? 0 : min(animator.frameIndex, frames.count - 1)
        let isLeft = direction == .left

        guard force || state != shownState || frame != shownFrame || isLeft != shownLeft
        else { return }
        shownState = state; shownFrame = frame; shownLeft = isLeft
        button.image = frames[frame]
    }
}
