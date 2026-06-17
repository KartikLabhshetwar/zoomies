import Foundation
import Darwin

public struct CPUTicks: Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public var total: UInt64 { user + system + idle + nice }
    public var busy: UInt64 { user + system + nice }
}

public enum CPUMath {
    /// Busy fraction in 0...1 from two cumulative tick snapshots.
    public static func busyFraction(previous: CPUTicks, current: CPUTicks) -> Double {
        let totalDelta = Double(current.total) - Double(previous.total)
        guard totalDelta > 0 else { return 0 }
        let busyDelta = Double(current.busy) - Double(previous.busy)
        return min(max(busyDelta / totalDelta, 0), 1)
    }
}

public final class CPUMonitor {
    public private(set) var load: Double = 0
    public var onUpdate: ((Double) -> Void)?

    private var previous: CPUTicks?
    private var timer: Timer?

    public init() {}

    public var percentString: String { "\(Int((load * 100).rounded()))%" }

    public func start(interval: TimeInterval = 2.0) {
        stop()
        sample() // prime the previous snapshot
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard let ticks = Self.readSystemTicks() else { return } // keep last good value
        if let prev = previous {
            load = CPUMath.busyFraction(previous: prev, current: ticks)
            onUpdate?(load)
        }
        previous = ticks
    }

    /// Reads aggregate system CPU ticks via the public mach API. Returns nil on failure.
    static func readSystemTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // cpu_ticks order: 0=USER, 1=SYSTEM, 2=IDLE, 3=NICE
        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }
}
