import XCTest
@testable import ZoomiesCore

final class CPUMathTests: XCTestCase {
    func testAllIdleIsZeroBusy() {
        let a = CPUTicks(user: 0, system: 0, idle: 100, nice: 0)
        let b = CPUTicks(user: 0, system: 0, idle: 200, nice: 0)
        XCTAssertEqual(CPUMath.busyFraction(previous: a, current: b), 0.0, accuracy: 0.0001)
    }
    func testFullyBusyIsOne() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 50, system: 50, idle: 0, nice: 0)
        XCTAssertEqual(CPUMath.busyFraction(previous: a, current: b), 1.0, accuracy: 0.0001)
    }
    func testHalfBusy() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 25, system: 25, idle: 50, nice: 0)
        XCTAssertEqual(CPUMath.busyFraction(previous: a, current: b), 0.5, accuracy: 0.0001)
    }
    func testNiceCountsAsBusy() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 0, system: 0, idle: 50, nice: 50)
        XCTAssertEqual(CPUMath.busyFraction(previous: a, current: b), 0.5, accuracy: 0.0001)
    }
    func testNoElapsedTimeReturnsZero() {
        let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 10)
        XCTAssertEqual(CPUMath.busyFraction(previous: a, current: a), 0.0, accuracy: 0.0001)
    }
}
