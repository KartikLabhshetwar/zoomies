import XCTest
@testable import ZoomiesCore

final class GaitAnimatorTests: XCTestCase {

    // MARK: - Phase advance

    func testStartsAtZeroPhase() {
        let g = GaitAnimator()
        XCTAssertEqual(g.phase, 0, accuracy: 1e-9)
    }

    func testAdvanceMovesPhaseByPace() {
        // pace already at target → no easing, phase advances by pace * dt.
        var g = GaitAnimator(pace: 2)
        g.setTargetPace(2)
        g.advance(by: 0.1)
        XCTAssertEqual(g.phase, 0.2, accuracy: 1e-6)
    }

    func testPhaseWrapsIntoUnitInterval() {
        var g = GaitAnimator(pace: 3)
        g.setTargetPace(3)
        g.advance(by: 0.5)            // raw 1.5 → wrapped 0.5
        XCTAssertEqual(g.phase, 0.5, accuracy: 1e-6)
        XCTAssertGreaterThanOrEqual(g.phase, 0)
        XCTAssertLessThan(g.phase, 1)
    }

    func testZeroPaceHoldsStill() {
        var g = GaitAnimator(pace: 0)
        g.setTargetPace(0)
        g.advance(by: 1.0)
        XCTAssertEqual(g.phase, 0, accuracy: 1e-9)
    }

    // MARK: - Frame selection

    func testFrameIndexAlternatesAcrossTheCycle() {
        var g = GaitAnimator(pace: 1)
        g.setTargetPace(1)
        // phase 0.25 → first half → frame 0
        g.advance(by: 0.25)
        XCTAssertEqual(g.frameIndex(frameCount: 2), 0)
        // phase 0.75 → second half → frame 1
        g.advance(by: 0.5)
        XCTAssertEqual(g.frameIndex(frameCount: 2), 1)
    }

    // MARK: - Procedural bob (vertical bounce)

    func testBobIsLowOnTheContactFrameAndHighOnTheFlightFrame() {
        // Each of the two poses should sit at an extreme of the bounce: the contact
        // pose (frame 0, centred at phase 0.25) planted low, the flight pose (frame 1,
        // centred at phase 0.75) riding high. That pairing is what reads as "running".
        var g = GaitAnimator(pace: 1)
        g.setTargetPace(1)
        g.advance(by: 0.25)
        XCTAssertEqual(g.bob, 0, accuracy: 1e-6)      // contact = lowest
        g.advance(by: 0.5)
        XCTAssertEqual(g.bob, 1, accuracy: 1e-6)      // flight = highest
    }

    func testBobStaysWithinUnitRange() {
        var g = GaitAnimator(pace: 1)
        g.setTargetPace(1)
        for _ in 0..<200 {
            g.advance(by: 0.013)
            XCTAssertGreaterThanOrEqual(g.bob, 0)
            XCTAssertLessThanOrEqual(g.bob, 1)
        }
    }

    // MARK: - Pace easing (the anti-snap behaviour)

    func testPaceEasesTowardTargetMonotonicallyWithoutOvershoot() {
        var g = GaitAnimator(pace: 0)
        g.setTargetPace(4)
        var previous = g.pace
        for _ in 0..<100 {
            g.advance(by: 0.1)
            XCTAssertGreaterThanOrEqual(g.pace, previous)   // never moves backward
            XCTAssertLessThanOrEqual(g.pace, 4 + 1e-9)       // never overshoots
            previous = g.pace
        }
        XCTAssertEqual(g.pace, 4, accuracy: 0.05)            // and gets there
    }

    func testPaceEasingIsFrameRateIndependent() {
        // Exponential smoothing is the exact ODE solution, so one step of 2·dt must
        // match two steps of dt — the gait can't depend on display refresh rate.
        var coarse = GaitAnimator(pace: 0); coarse.setTargetPace(5)
        var fine   = GaitAnimator(pace: 0); fine.setTargetPace(5)
        coarse.advance(by: 0.2)
        fine.advance(by: 0.1); fine.advance(by: 0.1)
        XCTAssertEqual(coarse.pace, fine.pace, accuracy: 1e-9)
    }

    func testIntensityTracksPaceFraction() {
        var g = GaitAnimator(pace: 0, fullPace: 4)
        XCTAssertEqual(g.intensity, 0, accuracy: 1e-9)
        g.setTargetPace(4)
        for _ in 0..<200 { g.advance(by: 0.1) }
        XCTAssertEqual(g.intensity, 1, accuracy: 0.01)       // clamped fraction of fullPace
    }
}
