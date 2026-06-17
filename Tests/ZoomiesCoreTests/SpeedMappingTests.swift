import XCTest
@testable import ZoomiesCore

final class SpeedMappingTests: XCTestCase {
    func testIdleLoadGivesIdleFPS() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0.0), SpeedMapping.idleFPS, accuracy: 0.0001)
    }
    func testFullLoadGivesMaxFPS() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 1.0), SpeedMapping.maxFPS, accuracy: 0.0001)
    }
    func testHalfLoadIsMidpoint() {
        let mid = (SpeedMapping.idleFPS + SpeedMapping.maxFPS) / 2
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0.5), mid, accuracy: 0.0001)
    }
    func testLoadIsClampedBelowZero() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: -5), SpeedMapping.idleFPS, accuracy: 0.0001)
    }
    func testLoadIsClampedAboveOne() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 5), SpeedMapping.maxFPS, accuracy: 0.0001)
    }
    func testFrameIntervalIsReciprocalOfFPS() {
        XCTAssertEqual(SpeedMapping.frameInterval(forLoad: 1.0), 1.0 / SpeedMapping.maxFPS, accuracy: 0.0001)
    }
}
