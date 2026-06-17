public enum SpeedMapping {
    public static let idleFPS: Double = 3
    public static let maxFPS: Double = 18

    public static func fps(forLoad load: Double) -> Double {
        let clamped = min(max(load, 0), 1)
        return idleFPS + (maxFPS - idleFPS) * clamped
    }

    public static func frameInterval(forLoad load: Double) -> Double {
        return 1.0 / fps(forLoad: load)
    }
}
