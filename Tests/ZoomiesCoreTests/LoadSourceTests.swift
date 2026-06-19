import XCTest
@testable import ZoomiesCore

final class LoadSourceTests: XCTestCase {
    func testCPUSourceUsesCPU() {
        XCTAssertEqual(LoadSource.cpu.effective(cpu: 0.3, gpu: 0.5, memory: 0.9), 0.3, accuracy: 0.0001)
    }
    func testGPUSourceUsesGPU() {
        XCTAssertEqual(LoadSource.gpu.effective(cpu: 0.3, gpu: 0.8, memory: 0.2), 0.8, accuracy: 0.0001)
    }
    func testMemorySourceUsesMemory() {
        XCTAssertEqual(LoadSource.memory.effective(cpu: 0.3, gpu: 0.5, memory: 0.9), 0.9, accuracy: 0.0001)
    }
    func testMaxSourcePicksHighestOfAll() {
        XCTAssertEqual(LoadSource.max.effective(cpu: 0.3, gpu: 0.5, memory: 0.9), 0.9, accuracy: 0.0001)
        XCTAssertEqual(LoadSource.max.effective(cpu: 0.7, gpu: 0.4, memory: 0.2), 0.7, accuracy: 0.0001)
        XCTAssertEqual(LoadSource.max.effective(cpu: 0.1, gpu: 0.9, memory: 0.3), 0.9, accuracy: 0.0001)
    }
    func testRawValueRoundTrips() {
        for source in LoadSource.allCases {
            XCTAssertEqual(LoadSource(rawValue: source.rawValue), source)
        }
    }
    func testAllCasesCount() {
        XCTAssertEqual(LoadSource.allCases.count, 4)   // cpu, gpu, memory, max
    }
    func testGPUMonitorReturnsValidFraction() {
        let f = GPUMonitor.currentLoad()
        XCTAssertGreaterThanOrEqual(f, 0.0)
        XCTAssertLessThanOrEqual(f, 1.0)
    }
    func testMemorySamplerReturnsValidFraction() {
        let f = MemorySampler.usedFraction()
        XCTAssertGreaterThanOrEqual(f, 0.0)
        XCTAssertLessThanOrEqual(f, 1.0)
    }
}
