import XCTest
@testable import ZoomiesCore

final class SpeedMappingTests: XCTestCase {
    func testIdleLoadGivesIdleFPS() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0.0), SpeedMapping.idleFPS, accuracy: 0.0001)
    }
    func testFullLoadGivesMaxFPS() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 1.0), SpeedMapping.maxFPS, accuracy: 0.0001)
    }
    func testHalfLoadFollowsEaseInCurve() {
        // Ease-in: half load lands well below the old linear midpoint, so the pet
        // doesn't look half-sprinting when the machine is only half busy.
        let eased = SpeedMapping.idleFPS
            + (SpeedMapping.maxFPS - SpeedMapping.idleFPS) * pow(0.5, SpeedMapping.loadCurveExponent)
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0.5), eased, accuracy: 0.0001)
        let linearMid = (SpeedMapping.idleFPS + SpeedMapping.maxFPS) / 2
        XCTAssertLessThan(SpeedMapping.fps(forLoad: 0.5), linearMid)
    }

    func testLowLoadStaysCalm() {
        // Regression for the "running too fast at 20–30%" bug. The run cycle is only
        // two frames, so light load must stay close to the idle trot — not the
        // 6–7.5 fps sprint the old linear curve produced here.
        XCTAssertLessThanOrEqual(SpeedMapping.fps(forLoad: 0.2), SpeedMapping.idleFPS * 1.5)
        XCTAssertLessThanOrEqual(SpeedMapping.fps(forLoad: 0.3), SpeedMapping.idleFPS * 1.5)
    }

    func testCurveIsMonotonicallyIncreasing() {
        var previous = SpeedMapping.fps(forLoad: 0)
        for step in 1...10 {
            let next = SpeedMapping.fps(forLoad: Double(step) / 10)
            XCTAssertGreaterThan(next, previous)
            previous = next
        }
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

    // MARK: - Speed multiplier

    func testSpeedScalesIdleFPS() {
        // The whole point of the fix: at idle, speed still changes the pace.
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0, speed: 2), SpeedMapping.idleFPS * 2, accuracy: 0.0001)
    }
    func testSpeedScalesFullLoadFPS() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 1, speed: 0.5), SpeedMapping.maxFPS * 0.5, accuracy: 0.0001)
    }
    func testSpeedOfOneMatchesUnscaled() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0.5, speed: 1), SpeedMapping.fps(forLoad: 0.5), accuracy: 0.0001)
    }
    func testSpeedResultClampedToCeiling() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 1, speed: 100), SpeedMapping.maxRenderFPS, accuracy: 0.0001)
    }
    func testSpeedResultClampedToFloor() {
        XCTAssertEqual(SpeedMapping.fps(forLoad: 0, speed: 0.001), SpeedMapping.minRenderFPS, accuracy: 0.0001)
    }

    // MARK: - Chase speed (how fast the pet runs toward the cursor, points/second)

    func testChaseSpeedIdleEqualsIdleBaseAtSpeedOne() {
        XCTAssertEqual(SpeedMapping.chaseSpeed(forLoad: 0, speed: 1), SpeedMapping.idleChaseSpeed, accuracy: 0.0001)
    }
    func testChaseSpeedFullLoadEqualsMaxAtSpeedOne() {
        XCTAssertEqual(SpeedMapping.chaseSpeed(forLoad: 1, speed: 1), SpeedMapping.maxChaseSpeed, accuracy: 0.0001)
    }
    func testChaseSpeedScalesWithSpeedMultiplier() {
        XCTAssertEqual(SpeedMapping.chaseSpeed(forLoad: 0, speed: 2), SpeedMapping.idleChaseSpeed * 2, accuracy: 0.0001)
    }
    func testChaseSpeedClampsLoadBelowZero() {
        XCTAssertEqual(SpeedMapping.chaseSpeed(forLoad: -1, speed: 1), SpeedMapping.idleChaseSpeed, accuracy: 0.0001)
    }
    func testChaseSpeedClampsLoadAboveOne() {
        XCTAssertEqual(SpeedMapping.chaseSpeed(forLoad: 5, speed: 1), SpeedMapping.maxChaseSpeed, accuracy: 0.0001)
    }
}
