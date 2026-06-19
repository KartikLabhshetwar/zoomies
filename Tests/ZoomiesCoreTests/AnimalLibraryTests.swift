import XCTest
@testable import ZoomiesCore

final class AnimalLibraryTests: XCTestCase {
    func testRosterIsEightWalkersPlusTwoClassics() {
        XCTAssertEqual(AnimalLibrary.all.count, 10)   // 8 webpets walkers + cat + dalmatian
        // The classic 1.0 sprite-sheet pets are back.
        XCTAssertTrue(AnimalLibrary.all.contains { $0.id == "cat" })
        XCTAssertTrue(AnimalLibrary.all.contains { $0.id == "dalmatian" })
        // Non-leg-walkers and the dropped crab/monkey/totoro/turtle stay gone.
        let removed: Set<String> = ["chicken", "cockatiel", "snake", "snail", "morph",
                                    "clippy", "rocky", "zappy", "rubber-duck", "mod",
                                    "crab", "monkey", "totoro", "turtle"]
        for id in removed {
            XCTAssertFalse(AnimalLibrary.all.contains { $0.id == id }, "\(id) should be removed")
        }
    }

    func testClassicPetsUseLeftFacingSheets() {
        for id in ["cat", "dalmatian"] {
            let a = AnimalLibrary.animal(withID: id)
            XCTAssertFalse(a.facesRight, "\(id) (Neko sheet) faces left")
            if case .sheet = a.source {} else { XCTFail("\(id) should be a sheet pet") }
        }
        // webpets pets stay GIF + right-facing.
        let dog = AnimalLibrary.animal(withID: "dog")
        XCTAssertTrue(dog.facesRight)
        XCTAssertEqual(dog.source, .gif)
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
        XCTAssertEqual(fox.color(withID: "yellow").id, fox.defaultColorID)  // a color fox lacks
        XCTAssertEqual(fox.color(withID: "white").id, "white")  // a shared/valid color is kept
    }

    func testWalkFastGapsAreFlagged() {
        // skeleton lacks walk_fast; the sheet pets (cat, dalmatian) reuse run for the fast bucket.
        let noFast: Set<String> = ["skeleton", "cat", "dalmatian"]
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
