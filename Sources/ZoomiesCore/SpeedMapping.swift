import Foundation

public enum SpeedMapping {
    public static let idleFPS: Double = 2
    public static let maxFPS: Double = 9
    /// Render-rate floor/ceiling after the user's speed multiplier is applied.
    /// The floor keeps the cat from freezing; the ceiling bounds menu-bar redraw cost
    /// (important on low-powered Macs).
    public static let minRenderFPS: Double = 1
    public static let maxRenderFPS: Double = 30

    /// Shapes the load→pace response. A straight linear ramp makes the pet look like it's
    /// sprinting at 20–30% load, so we raise load to this power to ease the curve in: light
    /// and medium load stay a calm trot, and the speed-up concentrates near full load where
    /// the Mac is actually busy. Matters most for the RAM source, which idles ~60% on a
    /// healthy Mac. 1.0 = linear; higher = gentler low end.
    public static let loadCurveExponent: Double = 3

    /// Load-driven frame rate (no user speed applied): idleFPS at 0 load → maxFPS at full,
    /// following the ease-in curve so light load stays gentle.
    public static func fps(forLoad load: Double) -> Double {
        let clamped = min(max(load, 0), 1)
        let eased = pow(clamped, loadCurveExponent)
        return idleFPS + (maxFPS - idleFPS) * eased
    }

    /// Load-driven frame rate scaled by the user's speed multiplier, clamped to a safe
    /// render range. Because the multiplier scales the whole curve (including idle), the
    /// Speed slider visibly changes the cat's pace even when the Mac is idle.
    public static func fps(forLoad load: Double, speed: Double) -> Double {
        min(max(fps(forLoad: load) * speed, minRenderFPS), maxRenderFPS)
    }

    public static func frameInterval(forLoad load: Double) -> Double {
        1.0 / fps(forLoad: load)
    }

    public static func frameInterval(forLoad load: Double, speed: Double) -> Double {
        1.0 / fps(forLoad: load, speed: speed)
    }

    // MARK: - Chase speed

    /// How fast the pet runs toward the cursor (points/second) at idle and full load.
    public static let idleChaseSpeed: Double = 220
    public static let maxChaseSpeed: Double = 900

    /// Load-driven chase speed scaled by the user's speed multiplier. Like the frame
    /// rate, a busier Mac (or a higher Speed setting) makes the pet sprint to the cursor.
    public static func chaseSpeed(forLoad load: Double, speed: Double) -> Double {
        let clamped = min(max(load, 0), 1)
        return (idleChaseSpeed + (maxChaseSpeed - idleChaseSpeed) * clamped) * speed
    }
}
