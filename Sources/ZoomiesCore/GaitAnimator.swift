import Foundation

/// Pure, AppKit-free engine that turns a load/speed signal into a smooth, soothing run
/// cycle — the thing that makes a *two-frame* sprite read as running instead of flicking.
///
/// The art only ships two run poses per direction, so a hard A↔B flip looks artificial no
/// matter how it's timed. `GaitAnimator` fixes that two ways:
///
///  * **A continuous procedural bob.** Each display tick it advances a `phase` (0..<1
///    around the stride) and derives a `bob` height from it, so the body rises and falls
///    *between* the two leg poses. The contact pose (frame 0) is planted low and the
///    flight pose (frame 1) rides high — a real gait, not a flat swap.
///
///  * **Eased pace.** System load is bucketed and jumps around; feeding it straight to the
///    animation makes the pet snap between speeds. Instead `pace` glides toward
///    `targetPace` with frame-rate-independent exponential smoothing, so a CPU spike reads
///    as the pet *winding up* rather than teleporting to a new speed.
///
/// Kept free of AppKit (and of `Date`/wall-clock) so the gait is fully unit-testable: the
/// caller owns the clock and passes `dt` in.
public struct GaitAnimator {
    /// Position within the current stride, `0..<1`. Never reset by load changes — that's
    /// what kept the old timer-based version hitching.
    public private(set) var phase: Double = 0

    /// Eased animation rate in stride-cycles per second. Follows `targetPace` smoothly.
    public private(set) var pace: Double

    /// Desired stride rate; `pace` chases this. Set it from load × user speed.
    public private(set) var targetPace: Double

    /// Stride rate treated as "full sprint" for `intensity` (so the bounce can grow with
    /// effort). Defaults to the speed-1 full-load rate of a 2-frame cycle.
    private let fullPace: Double

    /// Time constant (seconds) of the pace easing — roughly how long a speed change takes
    /// to mostly land. Small enough to feel responsive, large enough to never snap.
    private let smoothing: Double

    public init(pace: Double = 0, fullPace: Double = 4.5, smoothing: Double = 0.3) {
        self.pace = max(0, pace)
        self.targetPace = max(0, pace)
        self.fullPace = max(fullPace, 0.0001)
        self.smoothing = max(smoothing, 0.0001)
    }

    /// Point the gait at a new stride rate (cycles/sec). `pace` eases toward it; `phase`
    /// is untouched, so there's no visible jump.
    public mutating func setTargetPace(_ newValue: Double) {
        targetPace = max(0, newValue)
    }

    /// Advance the gait by `dt` seconds: ease the pace, then move and wrap the phase.
    public mutating func advance(by dt: Double) {
        guard dt > 0 else { return }
        // Exact discrete solution of pace' = (target - pace)/τ — independent of dt size,
        // so the gait looks identical at 60 Hz, 120 Hz, or an irregular display tick.
        let alpha = 1 - exp(-dt / smoothing)
        pace += (targetPace - pace) * alpha
        phase += pace * dt
        phase -= floor(phase)            // wrap into 0..<1
    }

    /// Which run pose to show, given how many the cycle has. The poses split the cycle
    /// evenly (2 frames → halves).
    public func frameIndex(frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        let i = Int(phase * Double(frameCount))
        return min(i, frameCount - 1) % frameCount
    }

    /// Vertical bounce, `0` (planted) … `1` (apex), phased so the contact pose sits low
    /// and the flight pose sits high. One smooth down-up oscillation per stride.
    public var bob: Double {
        (1 - sin(2 * .pi * phase)) / 2
    }

    /// How hard the pet is running, `0…1`, as a fraction of `fullPace`. Use it to scale
    /// the bounce amplitude so a slow trot bobs gently and a sprint bounds.
    public var intensity: Double {
        min(max(pace / fullPace, 0), 1)
    }
}
