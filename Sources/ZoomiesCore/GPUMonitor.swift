import Foundation
import IOKit

/// Pure GPU-statistics parsing, split out so the key selection can be unit-tested.
public enum GPUMath {
    /// GPU utilization fraction (0...1) from one accelerator's `PerformanceStatistics`
    /// (and optional `AGCInfo`) dictionary.
    ///
    /// Prefers **"Device Utilization %"** — the aggregate that's populated on Apple Silicon
    /// and Intel/AMD alike — and falls back to "GPU Activity(%)" used by some Intel/AMD
    /// drivers. (The old code took max of Device/Renderer/Tiler; Renderer and Tiler are
    /// pipeline sub-stages, so that overstated utilization.) Returns 0 when the GPU is
    /// parked by the Apple GPU Controller, so an idle-off GPU reads a true 0, not noise.
    public static func utilization(perf: [String: Any], agc: [String: Any]?) -> Double {
        if let off = agc?["poweredOffByAGC"] as? NSNumber, off.intValue == 1 { return 0 }
        for key in ["Device Utilization %", "GPU Activity(%)"] {
            if let n = perf[key] as? NSNumber {
                return min(max(n.doubleValue / 100.0, 0), 1)
            }
        }
        return 0
    }
}

/// Samples GPU utilization via the public IOAccelerator IORegistry entry.
///
/// The registry walk (IOServiceGetMatchingServices + IORegistryEntryCreateCFProperties)
/// is a blocking IPC call that deserializes a sizable dictionary, so it runs on a
/// background `.utility` queue — never the main thread — and reports back on main. A
/// 2 s cadence with timer leeway keeps wake-ups (and battery cost) low on weak Macs;
/// a light exponential moving average smooths the pet's speed and absorbs the occasional
/// stale/zero snapshot the driver returns between its own refreshes.
public final class GPUMonitor {
    /// Smoothed utilization fraction (0...1), updated on the main thread.
    public private(set) var load: Double = 0
    public var onUpdate: ((Double) -> Void)?

    private let queue = DispatchQueue(label: "com.zoomies.gpu", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var smoothed: Double = 0        // touched only on `queue`

    public init() {}

    public func start(interval: TimeInterval = 2.0) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(),
                   repeating: interval,
                   leeway: .milliseconds(Int(interval * 100)))   // ~10% — lets macOS coalesce wakeups
        t.setEventHandler { [weak self] in self?.sample() }
        timer = t
        t.resume()
    }

    public func stop() { timer?.cancel(); timer = nil }

    private func sample() {   // on `queue`, off the main thread
        let raw = Self.currentLoad()
        smoothed = smoothed * 0.4 + raw * 0.6
        let value = smoothed
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.load = value
            self.onUpdate?(value)
        }
    }

    /// Instantaneous GPU utilisation (0...1) from IOKit. Returns 0 on failure or true idle.
    /// Safe to call off the main thread.
    public static func currentLoad() -> Double {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
              IOServiceMatching("IOAccelerator"), &iter) == KERN_SUCCESS else { return 0 }
        defer { IOObjectRelease(iter) }

        var best: Double = 0
        var obj = IOIteratorNext(iter)
        while obj != 0 {
            defer { IOObjectRelease(obj); obj = IOIteratorNext(iter) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(obj, &props,
                  kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let d    = props?.takeRetainedValue() as? [String: Any],
                  let perf = d["PerformanceStatistics"]  as? [String: Any] else { continue }

            best = max(best, GPUMath.utilization(perf: perf, agc: d["AGCInfo"] as? [String: Any]))
        }
        return best
    }
}
