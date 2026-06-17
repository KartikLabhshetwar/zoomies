import XCTest
@testable import ZoomiesCore

final class AnimalLibraryTests: XCTestCase {
    func testHasFourAnimals() {
        XCTAssertEqual(AnimalLibrary.all.count, 4)
    }
    func testEveryAnimalHasFrames() {
        for animal in AnimalLibrary.all {
            XCTAssertGreaterThan(animal.frameCount, 0, "\(animal.id) has no frames")
            XCTAssertEqual(animal.frameNames.count, animal.frameCount)
        }
    }
    func testIDsAreUnique() {
        let ids = AnimalLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
    func testFrameNameFormat() {
        let cat = AnimalLibrary.animal(withID: "cat")
        XCTAssertEqual(cat.frameName(0), "cat_0")
        XCTAssertEqual(cat.frameName(3), "cat_3")
    }
    func testDefaultIsCat() {
        XCTAssertEqual(AnimalLibrary.default.id, "cat")
    }
    func testUnknownIDFallsBackToDefault() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "dragon"), AnimalLibrary.default)
    }
}
