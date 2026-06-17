/// What the animation speed reacts to.
public enum LoadSource: String, CaseIterable, Equatable {
    case cpu
    case memory
    case max   // whichever of CPU / memory is higher

    public var displayName: String {
        switch self {
        case .cpu:    return "CPU"
        case .memory: return "Memory"
        case .max:    return "CPU or Memory"
        }
    }

    /// The effective 0...1 load for this source, given the latest CPU and memory readings.
    public func effective(cpu: Double, memory: Double) -> Double {
        switch self {
        case .cpu:    return cpu
        case .memory: return memory
        case .max:    return Swift.max(cpu, memory)
        }
    }
}
