import AppKit
import QuartzCore
import ZoomiesCore

/// Drives the run animation inside the menu-bar status item.
///
/// A single display-synced `CADisplayLink` ticks a pure `GaitAnimator`. System load and the
/// user's speed setting only move a *target* the animator's pace eases toward — the link is
/// never torn down and the stride phase is never reset, so load changes glide instead of
/// hitching. (The old version rebuilt a `Timer` on every load bucket, which reset the phase
/// and snapped the pace — the source of the jerky feel.) Each tick selects a pre-rendered
/// (pose, bob-height) image and only reassigns the button image when the visible frame
/// actually changes, so the smooth motion stays cheap — fitting for a pet whose whole job is
/// to reflect how busy the Mac is.
final class PetController {
    private weak var statusItem: NSStatusItem?

    // Pre-rendered run variants indexed [frame][liftLevel], one set per facing direction.
    private var leftVariants:  [[NSImage]] = []
    private var rightVariants: [[NSImage]] = []
    private var direction: DirectionTracker.Direction = .left
    private var variants: [[NSImage]] { direction == .left ? leftVariants : rightVariants }

    // Pure gait model. `fullPace` is the speed-1 full-load stride rate, so the bounce
    // amplitude (`intensity`) reaches its peak exactly when the Mac is pegged at 1× speed.
    private var animator = GaitAnimator(
        fullPace: SpeedMapping.maxFPS / Double(FrameLoader.runFrameCount))

    private var load:  Double = 0
    private var speed: Double = 1.0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    // Last image shown, so the button image is only reassigned when it truly changes.
    private var shownFrame = -1
    private var shownLevel = -1
    private var shownLeft  = true

    private let cursorMonitor = MouseDirectionMonitor()

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Stride rate (cycles/sec) the gait eases toward, from load × user speed. Reuses the
    /// same load→fps curve as the percentage label; dividing by the pose count converts
    /// "poses per second" into "strides per second".
    private var targetPace: Double {
        SpeedMapping.fps(forLoad: load, speed: speed) / Double(FrameLoader.runFrameCount)
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
            self.render(force: true)   // flip facing immediately, mid-stride
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        displayLink?.invalidate()
        cursorMonitor.stop()
    }

    func setAnimal(_ animal: Animal) {
        let pair = FrameLoader.loadRunVariants(animal)
        leftVariants  = pair.left
        rightVariants = pair.right
        render(force: true)
    }

    /// New system load (0...1). Only nudges the gait's target; the eased pace does the rest,
    /// so a CPU spike reads as the pet winding up rather than teleporting to a new speed.
    func setLoad(_ load: Double) {
        self.load = load
        animator.setTargetPace(targetPace)
    }

    func setSpeed(_ speed: Double) {
        self.speed = speed
        animator.setTargetPace(targetPace)
    }

    func start() {
        startDisplayLink()
        cursorMonitor.start()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        cursorMonitor.stop()
    }

    // MARK: - Display link

    private func startDisplayLink() {
        guard displayLink == nil, let view = statusItem?.button else { return }
        animator.setTargetPace(targetPace)
        let link = view.displayLink(target: self, selector: #selector(tick(_:)))
        // The bob only needs a handful of steps per stride, and a menu-bar pet shouldn't
        // burn battery ticking at 120 Hz — 30 Hz is smooth to the eye yet light on power.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 30, preferred: 30)
        link.isPaused = reduceMotion
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
        render(force: true)
    }

    @objc private func tick(_ link: CADisplayLink) {
        // Clamp dt so a long gap (display sleep/wake, app idle) can't fling the phase.
        let raw = lastTimestamp > 0 ? link.timestamp - lastTimestamp : link.duration
        lastTimestamp = link.timestamp
        animator.advance(by: min(max(raw, 0), 0.1))
        render()
    }

    @objc private func accessibilityChanged() {
        displayLink?.isPaused = reduceMotion
        lastTimestamp = 0                 // resume cleanly, no dt spike
        render(force: true)
    }

    // MARK: - Rendering

    /// Pick the pre-rendered image for the current gait state and assign it only when it
    /// changed (or `force`). With reduce-motion on, hold a calm, planted pose.
    private func render(force: Bool = false) {
        guard let button = statusItem?.button, !variants.isEmpty else { return }

        let frame: Int
        let level: Int
        if reduceMotion {
            frame = 0
            level = 0
        } else {
            frame = animator.frameIndex(frameCount: FrameLoader.runFrameCount)
            // Bounce gently at a trot, fully at a sprint — amplitude rides on intensity.
            let amplitude = 0.45 + 0.55 * animator.intensity
            let raw = animator.bob * amplitude * Double(FrameLoader.bobLevels)
            level = min(max(Int(raw.rounded()), 0), FrameLoader.bobLevels)
        }

        let isLeft = direction == .left
        guard force || frame != shownFrame || level != shownLevel || isLeft != shownLeft
        else { return }
        shownFrame = frame; shownLevel = level; shownLeft = isLeft
        button.image = variants[frame][level]
    }
}
