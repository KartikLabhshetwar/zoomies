import XCTest
@testable import ZoomiesCore

final class ChaseModelTests: XCTestCase {
    func testMovesRightTowardTargetAndFacesRight() {
        var m = ChaseModel(position: 0, facing: .left, deadzone: 1)
        m.step(toward: 100, maxStep: 10, minX: 0, maxX: 200)
        XCTAssertEqual(m.position, 10, accuracy: 0.0001)
        XCTAssertEqual(m.facing, .right)
        XCTAssertTrue(m.isMoving)
    }

    func testMovesLeftTowardTargetAndFacesLeft() {
        var m = ChaseModel(position: 100, facing: .right, deadzone: 1)
        m.step(toward: 0, maxStep: 10, minX: 0, maxX: 200)
        XCTAssertEqual(m.position, 90, accuracy: 0.0001)
        XCTAssertEqual(m.facing, .left)
        XCTAssertTrue(m.isMoving)
    }

    func testDoesNotOvershootWhenCloserThanMaxStep() {
        var m = ChaseModel(position: 0, facing: .left, deadzone: 0.5)
        m.step(toward: 3, maxStep: 10, minX: 0, maxX: 200)
        XCTAssertEqual(m.position, 3, accuracy: 0.0001)   // lands exactly on the target
    }

    func testStopsWithinDeadzoneWithoutMovingOrTurning() {
        var m = ChaseModel(position: 50, facing: .right, deadzone: 2)
        m.step(toward: 51, maxStep: 10, minX: 0, maxX: 200)
        XCTAssertEqual(m.position, 50, accuracy: 0.0001)   // inside deadzone → no move
        XCTAssertFalse(m.isMoving)
        XCTAssertEqual(m.facing, .right)                   // facing unchanged
    }

    func testClampsTargetToMaxBound() {
        var m = ChaseModel(position: 0, facing: .left, deadzone: 1)
        m.step(toward: 999, maxStep: 1000, minX: 0, maxX: 200)
        XCTAssertEqual(m.position, 200, accuracy: 0.0001)  // capped at maxX
        XCTAssertEqual(m.facing, .right)
    }

    func testClampsTargetToMinBound() {
        var m = ChaseModel(position: 100, facing: .right, deadzone: 1)
        m.step(toward: -999, maxStep: 1000, minX: 10, maxX: 200)
        XCTAssertEqual(m.position, 10, accuracy: 0.0001)
        XCTAssertEqual(m.facing, .left)
    }

    func testPositionStaysWithinBoundsAndConvergesAcrossManySteps() {
        var m = ChaseModel(position: 0, facing: .left, deadzone: 0.5)
        for _ in 0..<1000 {
            m.step(toward: 137, maxStep: 7, minX: 0, maxX: 200)
            XCTAssertGreaterThanOrEqual(m.position, 0)
            XCTAssertLessThanOrEqual(m.position, 200)
        }
        XCTAssertEqual(m.position, 137, accuracy: 0.5)     // converges onto the target
    }
}
