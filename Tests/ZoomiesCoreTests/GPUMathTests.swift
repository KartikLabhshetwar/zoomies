import XCTest
@testable import ZoomiesCore

final class GPUMathTests: XCTestCase {
    func testUsesDeviceUtilizationPercent() {
        XCTAssertEqual(GPUMath.utilization(perf: ["Device Utilization %": 80], agc: nil),
                       0.80, accuracy: 0.0001)
    }

    func testAcceptsDoubleValues() {
        XCTAssertEqual(GPUMath.utilization(perf: ["Device Utilization %": 65.5], agc: nil),
                       0.655, accuracy: 0.0001)
    }

    func testFallsBackToGPUActivityForIntelAMD() {
        XCTAssertEqual(GPUMath.utilization(perf: ["GPU Activity(%)": 50], agc: nil),
                       0.50, accuracy: 0.0001)
    }

    func testPrefersDeviceOverGPUActivity() {
        let perf: [String: Any] = ["Device Utilization %": 30, "GPU Activity(%)": 90]
        XCTAssertEqual(GPUMath.utilization(perf: perf, agc: nil), 0.30, accuracy: 0.0001)
    }

    func testIgnoresRendererAndTilerSubStages() {
        // Renderer/Tiler are pipeline stages, not the aggregate — without a Device value
        // the result is 0 rather than the (overstated) max of the sub-stages.
        let perf: [String: Any] = ["Renderer Utilization %": 95, "Tiler Utilization %": 70]
        XCTAssertEqual(GPUMath.utilization(perf: perf, agc: nil), 0, accuracy: 0.0001)
    }

    func testPoweredOffGPUReadsZero() {
        let perf: [String: Any] = ["Device Utilization %": 90]
        XCTAssertEqual(GPUMath.utilization(perf: perf, agc: ["poweredOffByAGC": 1]),
                       0, accuracy: 0.0001)
    }

    func testPoweredOnGPUUsesReading() {
        let perf: [String: Any] = ["Device Utilization %": 90]
        XCTAssertEqual(GPUMath.utilization(perf: perf, agc: ["poweredOffByAGC": 0]),
                       0.90, accuracy: 0.0001)
    }

    func testClampsAboveOneHundred() {
        XCTAssertEqual(GPUMath.utilization(perf: ["Device Utilization %": 150], agc: nil),
                       1.0, accuracy: 0.0001)
    }

    func testClampsBelowZero() {
        XCTAssertEqual(GPUMath.utilization(perf: ["Device Utilization %": -10], agc: nil),
                       0, accuracy: 0.0001)
    }

    func testEmptyStatsReturnZero() {
        XCTAssertEqual(GPUMath.utilization(perf: [:], agc: nil), 0, accuracy: 0.0001)
    }
}
