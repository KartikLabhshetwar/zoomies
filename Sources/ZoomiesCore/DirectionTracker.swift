/// Pure logic that turns a stream of cursor X positions into left/right facing changes.
///
/// Fed the latest horizontal cursor position on every mouse move, it reports a new
/// `Direction` only when the cursor's travel direction actually flips (debounced), and
/// ignores sub-threshold jitter. Kept AppKit-free so it can be unit-tested in isolation.
public struct DirectionTracker {
    public enum Direction: Equatable { case left, right }

    private let threshold: Double
    private var lastX: Double?
    public private(set) var direction: Direction

    public init(threshold: Double = 1.5, initial: Direction = .left) {
        self.threshold = threshold
        self.direction = initial
    }

    /// Feed the latest cursor X (screen points). Returns the new direction if it
    /// changed this update, or `nil` if it held steady / moved less than the threshold.
    public mutating func update(x: Double) -> Direction? {
        defer { lastX = x }
        guard let last = lastX else { return nil }
        let dx = x - last
        guard abs(dx) >= threshold else { return nil }
        let moving: Direction = dx > 0 ? .right : .left
        guard moving != direction else { return nil }
        direction = moving
        return moving
    }
}
