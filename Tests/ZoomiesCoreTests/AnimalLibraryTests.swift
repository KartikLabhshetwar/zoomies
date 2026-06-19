import XCTest
@testable import ZoomiesCore

final class AnimalLibraryTests: XCTestCase {
    func testRosterHas22Creatures() {
        XCTAssertEqual(AnimalLibrary.all.count, 22)
    }

    func testEveryAnimalHasValidDefaultColor() {
        for a in AnimalLibrary.all {
            XCTAssertFalse(a.colors.isEmpty, "\(a.id) has no colors")
            XCTAssertTrue(a.colors.contains { $0.id == a.defaultColorID },
                          "\(a.id) default \(a.defaultColorID) not in palette")
        }
    }

    func testColorWithIDFallsBackToDefault() {
        let dog = AnimalLibrary.animal(withID: "dog")
        XCTAssertEqual(dog.color(withID: "nope").id, dog.defaultColorID)
        XCTAssertEqual(dog.color(withID: "white").id, "white")
    }

    // Switching from one animal to another whose palette lacks the current color must snap to
    // the new animal's default — the validation AppSettings/AppDelegate rely on when the user
    // picks a different creature (regression guard for "switching animals kept the old pet").
    func testSwitchingAnimalSnapsInvalidColorToDefault() {
        let fox = AnimalLibrary.animal(withID: "fox")           // colors: red, white
        XCTAssertEqual(fox.color(withID: "yellow").id, fox.defaultColorID)  // rubber-duck's yellow
        XCTAssertEqual(fox.color(withID: "white").id, "white")  // a shared/valid color is kept
    }

    func testWalkFastGapsAreFlagged() {
        let noFast: Set<String> = ["monkey", "skeleton", "totoro"]
        for a in AnimalLibrary.all {
            XCTAssertEqual(a.hasWalkFast, !noFast.contains(a.id), "hasWalkFast wrong for \(a.id)")
        }
    }

    func testHumanizeIdToName() {
        XCTAssertEqual(PetNaming.humanize("rubber-duck"), "Rubber Duck")
        XCTAssertEqual(PetNaming.humanize("socks_black"), "Socks Black")
        XCTAssertEqual(PetNaming.humanize("dog"), "Dog")
    }

    func testUnknownAnimalFallsBackToDefault() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "ghost").id, AnimalLibrary.default.id)
    }

    func testSkeletonHasTenColorsHorseEleven() {
        XCTAssertEqual(AnimalLibrary.animal(withID: "skeleton").colors.count, 10)
        XCTAssertEqual(AnimalLibrary.animal(withID: "horse").colors.count, 11)
    }

    func testIDsAreUnique() {
        let ids = AnimalLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
