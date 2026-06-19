import Foundation

public enum PetState: String, CaseIterable, Equatable {
    case idle, walk, walkFast, run

    public var level: Int {
        switch self {
        case .idle: return 0
        case .walk: return 1
        case .walkFast: return 2
        case .run: return 3
        }
    }

    public static func atLevel(_ l: Int) -> PetState {
        [.idle, .walk, .walkFast, .run][min(max(l, 0), 3)]
    }
}

/// Pure, AppKit-free engine. Maps eased system load to one of four gait states with
/// hysteresis (so it never flickers at a boundary) and advances the current state's frame
/// cursor by the GIF's own per-frame durations, sped up by load × the user's speed.
///
/// Kept free of AppKit and of `Date`/wall-clock so it's fully unit-testable: the caller owns
/// the clock and passes `dt` in, and supplies the current state's frame durations.
public struct PetAnimator {
    public private(set) var state: PetState = .idle
    public private(set) var frameIndex: Int = 0

    private var elapsed: Double = 0           // time banked toward the current frame
    private var durations: [Double] = [0.125] // current state's per-frame seconds
    private var load: Double = 0
    private var speed: Double = 1

    // Load needed to climb out of level i upward (index 0,1,2)…
    private static let up:   [Double] = [0.10, 0.38, 0.70]
    // …and to fall out of level i downward (index i-1, i.e. for levels 1,2,3).
    private static let down: [Double] = [0.06, 0.30, 0.60]

    public init() {}

    public mutating func setLoad(_ value: Double)  { load = min(max(value, 0), 1) }
    public mutating func setSpeed(_ value: Double) { speed = max(0.1, value) }

    /// Feed the current state's per-frame durations. Clamps the cursor if the new state
    /// has fewer frames.
    public mutating func setDurations(_ values: [Double]) {
        durations = values.isEmpty ? [0.125] : values
        if frameIndex >= durations.count { frameIndex = 0; elapsed = 0 }
    }

    /// Advance by `dt` seconds. Returns true when the state changed this tick — the caller
    /// must then call `setDurations` with the new state's durations before the next tick.
    @discardableResult
    public mutating func advance(by dt: Double) -> Bool {
        guard dt > 0 else { return false }
        let lvl = state.level
        if lvl < 3, load > Self.up[lvl] {
            state = .atLevel(lvl + 1); frameIndex = 0; elapsed = 0; return true
        }
        if lvl > 0, load < Self.down[lvl - 1] {
            state = .atLevel(lvl - 1); frameIndex = 0; elapsed = 0; return true
        }
        elapsed += dt * playbackRate
        var guardrail = 0
        while elapsed >= durations[frameIndex], guardrail < 4096 {
            elapsed -= durations[frameIndex]
            frameIndex = (frameIndex + 1) % durations.count
            guardrail += 1
        }
        return false
    }

    /// Native pace at idle, winding up with load (eased) and the user's speed multiplier,
    /// capped so a very high Speed setting can't shred the cycle.
    public var playbackRate: Double {
        let eased = load * load
        return min(speed * (0.9 + 0.9 * eased), 5.0)
    }
}
