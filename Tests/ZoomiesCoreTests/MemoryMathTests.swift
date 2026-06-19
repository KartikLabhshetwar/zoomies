import XCTest
@testable import ZoomiesCore

final class MemoryMathTests: XCTestCase {
    // Page counts captured live from this machine's `vm_stat` (32 GB, 16 KB pages).
    // Activity Monitor showed "Memory Used" ≈ 72% at the same moment.
    func testMatchesActivityMonitorMemoryUsed() {
        let fraction = MemoryMath.usedFraction(
            internalPages: 982_213,
            purgeable:      19_313,
            wired:         228_784,
            compressed:    318_254,
            pageSize:       16_384,
            totalBytes: 34_359_738_368
        )
        XCTAssertEqual(fraction, 0.72, accuracy: 0.01)
    }

    func testZeroTotalReturnsZeroNotNaN() {
        let fraction = MemoryMath.usedFraction(internalPages: 1, purgeable: 0, wired: 1,
                                               compressed: 1, pageSize: 16_384, totalBytes: 0)
        XCTAssertEqual(fraction, 0)
    }

    func testPurgeableAboveInternalDoesNotUnderflow() {
        // appPages must floor at 0 — UInt64 underflow would otherwise wrap to a huge value.
        let fraction = MemoryMath.usedFraction(internalPages: 10, purgeable: 100, wired: 0,
                                               compressed: 0, pageSize: 16_384,
                                               totalBytes: 1_073_741_824)
        XCTAssertEqual(fraction, 0)
    }

    func testResultClampsToOne() {
        let fraction = MemoryMath.usedFraction(internalPages: .max / 4, purgeable: 0,
                                               wired: 0, compressed: 0, pageSize: 16_384,
                                               totalBytes: 1_073_741_824)
        XCTAssertEqual(fraction, 1)
    }

    func testPurgeableMemoryIsNotCountedAsUsed() {
        // Marking pages purgeable should lower "used" (they're reclaimable).
        let withPurge = MemoryMath.usedFraction(internalPages: 1000, purgeable: 400, wired: 0,
                                                compressed: 0, pageSize: 16_384,
                                                totalBytes: 1_073_741_824)
        let noPurge = MemoryMath.usedFraction(internalPages: 1000, purgeable: 0, wired: 0,
                                              compressed: 0, pageSize: 16_384,
                                              totalBytes: 1_073_741_824)
        XCTAssertLessThan(withPurge, noPurge)
    }
}
