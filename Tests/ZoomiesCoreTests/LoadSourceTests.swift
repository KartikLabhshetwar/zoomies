import XCTest
@testable import ZoomiesCore

final class LoadSourceTests: XCTestCase {
    func testCPUSourceUsesCPU() {
        XCTAssertEqual(LoadSource.cpu.effective(cpu: 0.3, memory: 0.9), 0.3, accuracy: 0.0001)
    }
    func testMemorySourceUsesMemory() {
        XCTAssertEqual(LoadSource.memory.effective(cpu: 0.3, memory: 0.9), 0.9, accuracy: 0.0001)
    }
    func testMaxSourceUsesHigher() {
        XCTAssertEqual(LoadSource.max.effective(cpu: 0.3, memory: 0.9), 0.9, accuracy: 0.0001)
        XCTAssertEqual(LoadSource.max.effective(cpu: 0.7, memory: 0.2), 0.7, accuracy: 0.0001)
    }
    func testRawValueRoundTrips() {
        for source in LoadSource.allCases {
            XCTAssertEqual(LoadSource(rawValue: source.rawValue), source)
        }
    }
    func testMemorySamplerReturnsValidFraction() {
        let f = MemorySampler.usedFraction()
        XCTAssertGreaterThanOrEqual(f, 0.0)
        XCTAssertLessThanOrEqual(f, 1.0)
    }
}
