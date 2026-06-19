/// Pure, AppKit-free model of the pet's horizontal chase toward the cursor.
///
/// Each tick, `step(toward:)` eases the pet one bounded step toward a target X (the
/// cursor's position, in the menu bar's local coordinates), turns it to face the
/// direction of travel, and reports whether it actually moved — so the caller can
/// switch between the run cycle and the idle/sit pose. Kept free of AppKit so the
/// follow behavior can be unit-tested in isolation (it replaces the old DirectionTracker).
public struct ChaseModel {
    public enum Facing: Equatable { case left, right }

    public private(set) var position: Double
    public private(set) var facing: Facing
    public private(set) var isMoving: Bool
    private let deadzone: Double

    public init(position: Double = 0, facing: Facing = .left, deadzone: Double = 1) {
        self.position = position
        self.facing = facing
        self.deadzone = deadzone
        self.isMoving = false
    }

    /// Advance toward `target`, moving at most `maxStep` this tick, with the result
    /// clamped to `[minX, maxX]`. Within `deadzone` of the (clamped) target the pet
    /// holds still and keeps its current facing.
    public mutating func step(toward target: Double, maxStep: Double, minX: Double, maxX: Double) {
        let clampedTarget = min(max(target, minX), maxX)
        let delta = clampedTarget - position
        guard abs(delta) > deadzone else {
            isMoving = false
            return
        }
        let move = min(max(delta, -maxStep), maxStep)
        position = min(max(position + move, minX), maxX)
        facing = move > 0 ? .right : .left
        isMoving = true
    }
}
