import XCTest
@testable import ZoomiesCore

final class AnimalLibraryTests: XCTestCase {
    func testRosterContainsAllAnimals() {
        let ids = AnimalLibrary.all.map(\.id)
        XCTAssertEqual(ids, ["oneko", "dog", "fox", "dalmatian", "browndog", "chocobo"])
    }

    func testDefaultIsCat() {
        XCTAssertEqual(AnimalLibrary.default.id, "oneko")
        XCTAssertEqual(AnimalLibrary.default.name, "Cat")
    }

    func testOnekoUsesAdrydLayout() {
        XCTAssertFalse(AnimalLibrary.default.isClassic, "oneko uses the adryd layout, not classic")
    }

    func testAllOthersUseClassicLayout() {
        for animal in AnimalLibrary.all where animal.id != "oneko" {
            XCTAssertTrue(animal.isClassic, "\(animal.id) should use the classic Neko Archive layout")
        }
    }

    func testIDsAreUnique() {
        let ids = AnimalLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryAnimalHasAName() {
        for animal in AnimalLibrary.all {
            XCTAssertFalse(animal.name.isEmpty, "\(animal.id) is missing a display name")
        }
    }

    func testUnknownIDFallsBackToDefault() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "dragon"), AnimalLibrary.default)
    }

    func testKnownIDResolves() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "chocobo").name, "Chocobo")
    }
}
