import XCTest
@testable import ZoomiesCore

final class DirectionTrackerTests: XCTestCase {
    func testInitialDirectionDefaultsLeft() {
        XCTAssertEqual(DirectionTracker().direction, .left)
    }

    func testFirstUpdateHasNoChange() {
        var tracker = DirectionTracker()
        XCTAssertNil(tracker.update(x: 100))   // no previous X to compare against
    }

    func testMovingRightReportsRight() {
        var tracker = DirectionTracker(threshold: 1.0, initial: .left)
        _ = tracker.update(x: 100)
        XCTAssertEqual(tracker.update(x: 110), .right)
        XCTAssertEqual(tracker.direction, .right)
    }

    func testMovingLeftReportsLeft() {
        var tracker = DirectionTracker(threshold: 1.0, initial: .right)
        _ = tracker.update(x: 100)
        XCTAssertEqual(tracker.update(x: 90), .left)
        XCTAssertEqual(tracker.direction, .left)
    }

    func testSteadyDirectionReportsNil() {
        var tracker = DirectionTracker(threshold: 1.0, initial: .left)
        _ = tracker.update(x: 100)
        XCTAssertEqual(tracker.update(x: 110), .right)
        XCTAssertNil(tracker.update(x: 120))   // still moving right → no change
    }

    func testSubThresholdJitterIsIgnored() {
        var tracker = DirectionTracker(threshold: 2.0, initial: .left)
        _ = tracker.update(x: 100)
        XCTAssertNil(tracker.update(x: 101))   // dx = 1 < threshold
    }

    func testReversingDirectionFlips() {
        var tracker = DirectionTracker(threshold: 1.0, initial: .left)
        _ = tracker.update(x: 100)
        XCTAssertEqual(tracker.update(x: 110), .right)
        XCTAssertEqual(tracker.update(x: 100), .left)
    }
}
