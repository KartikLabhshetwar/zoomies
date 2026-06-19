import XCTest
@testable import ZoomiesCore

final class PetAnimatorTests: XCTestCase {
    private func settle(_ a: inout PetAnimator, load: Double, ticks: Int = 8) {
        a.setLoad(load)
        for _ in 0..<ticks { _ = a.advance(by: 0.033) }
    }

    func testStartsIdle() {
        let a = PetAnimator()
        XCTAssertEqual(a.state, .idle)
        XCTAssertEqual(a.frameIndex, 0)
    }

    func testEscalatesWithLoad() {
        var a = PetAnimator()
        settle(&a, load: 0.0);  XCTAssertEqual(a.state, .idle)
        settle(&a, load: 0.25); XCTAssertEqual(a.state, .walk)
        settle(&a, load: 0.55); XCTAssertEqual(a.state, .walkFast)
        settle(&a, load: 0.95); XCTAssertEqual(a.state, .run)
    }

    func testStepsOneLevelPerTick() {
        var a = PetAnimator()
        a.setLoad(1.0)
        XCTAssertTrue(a.advance(by: 0.033));  XCTAssertEqual(a.state, .walk)
        XCTAssertTrue(a.advance(by: 0.033));  XCTAssertEqual(a.state, .walkFast)
        XCTAssertTrue(a.advance(by: 0.033));  XCTAssertEqual(a.state, .run)
    }

    func testHysteresisHoldsNearBoundary() {
        var a = PetAnimator()
        settle(&a, load: 0.55)            // -> walkFast (level 2)
        XCTAssertEqual(a.state, .walkFast)
        settle(&a, load: 0.33)            // just above the down threshold -> holds
        XCTAssertEqual(a.state, .walkFast)
        settle(&a, load: 0.20)            // below it -> drops
        XCTAssertEqual(a.state, .walk)
    }

    func testStateChangeResetsFrameAndReturnsTrue() {
        var a = PetAnimator()
        a.setDurations([0.1, 0.1, 0.1])
        a.setLoad(0.0); _ = a.advance(by: 0.25)   // frame moved off 0
        XCTAssertNotEqual(a.frameIndex, 0)
        a.setLoad(0.25)
        XCTAssertTrue(a.advance(by: 0.033))         // idle -> walk
        XCTAssertEqual(a.frameIndex, 0)
    }

    func testFramesAdvanceByNativeDuration() {
        var a = PetAnimator()
        a.setSpeed(1.0); a.setLoad(0.0)
        a.setDurations([0.1, 0.1])
        _ = a.advance(by: 0.05); XCTAssertEqual(a.frameIndex, 0)  // 0.05*0.9 < 0.1
        _ = a.advance(by: 0.09); XCTAssertEqual(a.frameIndex, 1)  // crosses 0.1
    }

    func testPlaybackRateRisesWithLoadAndSpeed() {
        var slow = PetAnimator(); slow.setLoad(0.0); slow.setSpeed(1.0)
        var busy = PetAnimator(); busy.setLoad(1.0); busy.setSpeed(1.0)
        var fast = PetAnimator(); fast.setLoad(0.0); fast.setSpeed(2.0)
        XCTAssertGreaterThan(busy.playbackRate, slow.playbackRate)
        XCTAssertGreaterThan(fast.playbackRate, slow.playbackRate)
    }
}
