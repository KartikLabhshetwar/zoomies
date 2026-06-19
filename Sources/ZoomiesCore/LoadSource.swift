/// What the animation speed reacts to.
public enum LoadSource: String, CaseIterable, Equatable {
    case cpu
    case gpu
    case memory
    case max   // highest of CPU, GPU, or memory

    public var displayName: String {
        switch self {
        case .cpu:    return "CPU"
        case .gpu:    return "GPU"
        case .memory: return "Memory"
        case .max:    return "Busiest"
        }
    }

    /// The effective 0...1 load, given the latest CPU, GPU, and memory readings.
    public func effective(cpu: Double, gpu: Double, memory: Double) -> Double {
        switch self {
        case .cpu:    return cpu
        case .gpu:    return gpu
        case .memory: return memory
        case .max:    return Swift.max(cpu, gpu, memory)
        }
    }
}
