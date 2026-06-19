import XCTest
@testable import ZoomiesCore

final class AnimalLibraryTests: XCTestCase {
    func testHasSingleOnekoAnimal() {
        XCTAssertEqual(AnimalLibrary.all.count, 1)
        XCTAssertEqual(AnimalLibrary.all.first?.id, "oneko")
    }
    func testDefaultIsOneko() {
        XCTAssertEqual(AnimalLibrary.default.id, "oneko")
        XCTAssertEqual(AnimalLibrary.default.name, "Oneko")
    }
    func testOnekoHasTwoFrames() {
        let oneko = AnimalLibrary.animal(withID: "oneko")
        XCTAssertEqual(oneko.frameCount, 2)
        XCTAssertEqual(oneko.frameNames, ["oneko_0", "oneko_1"])
    }
    func testFrameNameFormat() {
        let oneko = AnimalLibrary.default
        XCTAssertEqual(oneko.frameName(0), "oneko_0")
        XCTAssertEqual(oneko.frameName(1), "oneko_1")
    }
    func testIDsAreUnique() {
        let ids = AnimalLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
    func testUnknownIDFallsBackToDefault() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "dragon"), AnimalLibrary.default)
    }
}
