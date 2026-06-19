import Foundation
import Darwin

/// Pure memory arithmetic, split out from the mach call so it can be unit-tested.
public enum MemoryMath {
    /// Fraction of physical RAM "used", matching Activity Monitor's **Memory Used**:
    ///
    ///     Memory Used = App Memory + Wired + Compressed
    ///     App Memory  = internal (anonymous) pages − purgeable pages
    ///
    /// The previous formula used `active_count`, which both *omits* anonymous pages that
    /// have aged onto the inactive list and *includes* file-backed cache — so it matched
    /// neither Activity Monitor's number nor real memory pressure. Counting App + Wired +
    /// Compressed (excluding reclaimable file cache) is what users see as "memory in use".
    public static func usedFraction(internalPages: UInt64,
                                    purgeable: UInt64,
                                    wired: UInt64,
                                    compressed: UInt64,
                                    pageSize: UInt64,
                                    totalBytes: UInt64) -> Double {
        guard totalBytes > 0 else { return 0 }
        // App memory = anonymous pages the app actually needs (purgeable can be dropped).
        let appPages = internalPages >= purgeable ? internalPages - purgeable : 0
        let usedPages = appPages + wired + compressed
        let usedBytes = Double(usedPages) * Double(pageSize)
        return min(max(usedBytes / Double(totalBytes), 0), 1)
    }
}

/// Reads how much physical memory is in use, as a 0...1 fraction.
/// Uses the public mach `host_statistics64(HOST_VM_INFO64)` API.
public enum MemorySampler {

    /// Fraction of physical RAM in use, matching Activity Monitor's "Memory Used".
    /// Returns 0 if the mach call fails — never traps.
    public static func usedFraction() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        return MemoryMath.usedFraction(
            internalPages: UInt64(stats.internal_page_count),
            purgeable:     UInt64(stats.purgeable_count),
            wired:         UInt64(stats.wire_count),
            compressed:    UInt64(stats.compressor_page_count),
            pageSize:      UInt64(vm_page_size),
            totalBytes:    ProcessInfo.processInfo.physicalMemory
        )
    }
}
