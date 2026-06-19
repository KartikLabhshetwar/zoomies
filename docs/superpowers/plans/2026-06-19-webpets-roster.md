# Webpets Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 4 existing menu-bar pets with the full webpets roster (22 creatures, ~57 color variants), driving them as real GIF animation cycles that escalate idle → walk → walk_fast → run with system load.

**Architecture:** Bundle the webpets GIFs (idle/walk/walk_fast/run) under a folder reference. A new pure `PetAnimator` (ZoomiesCore) maps eased system load to one of four states with hysteresis and advances frames by their native GIF durations. A rewritten `FrameLoader` (app target) decodes each state's GIF via `CGImageSource`, registers every frame of every state to one shared bottom-center baseline + scale (so state changes never jump or resize), and pre-mirrors for facing. `PetController` drives it off the existing `CADisplayLink`. Settings gains a scrollable pet grid + per-pet color picker.

**Tech Stack:** Swift 5, AppKit, SwiftUI, CoreGraphics/ImageIO (`CGImageSource`), QuartzCore (`CADisplayLink`), XcodeGen (`project.yml`), XCTest.

## Global Constraints

- Deployment target: macOS 14.0; Swift 5.0 (from `project.yml`).
- Pure engine code (`Sources/ZoomiesCore`) must stay AppKit-free and clock-free (caller passes `dt`) so it is unit-testable — follow the existing `GaitAnimator` precedent.
- Source art: `/tmp/webpets/public/media/<pet>/<color>_<state>_8fps.gif` (clone of https://github.com/sankalpaacharya/webpets). All GIFs have alpha; native facing is **left** (mirror for right).
- Only 4 states are used: `idle`, `walk`, `walk_fast`, `run`. `monkey`, `skeleton`, `totoro` ship no `walk_fast` → those load the `run` GIF for the fast state.
- Bundled resources live under a folder reference (`Sources/Zoomies/Pets`), resolved with `Bundle.main.url(forResource:withExtension:subdirectory:)` exactly as the old `Sprites` folder was.
- Preserve webpets attribution: copy each pet's `license.txt`; credit webpets in README + About.
- Build/test via the Makefile / XcodeGen. Regenerate the project after changing `project.yml` or adding the folder reference.

**Note on build state:** This is a format-swap refactor. Tasks 1–2 change `Sources/ZoomiesCore` and keep **ZoomiesCore + its tests green**, but the **Zoomies app target will not compile** from the end of Task 1 until Task 4 (which rewrites the app-side call sites). This is expected; the app build is verified at Task 4.

---

### Task 1: Pet data model + roster (ZoomiesCore)

**Files:**
- Modify: `Sources/ZoomiesCore/Animal.swift` (full rewrite)
- Test: `Tests/ZoomiesCoreTests/AnimalLibraryTests.swift` (full rewrite)

**Interfaces:**
- Produces:
  - `struct PetColor { let id: String; let displayName: String }` (Equatable, Identifiable)
  - `struct Animal { let id, name: String; let colors: [PetColor]; let defaultColorID: String; let hasWalkFast: Bool; func color(withID:) -> PetColor }`
  - `enum AnimalLibrary { static let all: [Animal]; static let `default`: Animal; static func animal(withID:) -> Animal }`
  - `enum PetNaming { static func humanize(_ id: String) -> String }`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/ZoomiesCoreTests/AnimalLibraryTests.swift
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Zoomies -only-testing:ZoomiesCoreTests/AnimalLibraryTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `PetColor` / `PetNaming` undefined, `Animal` has no `colors`.

- [ ] **Step 3: Rewrite the model**

```swift
// Sources/ZoomiesCore/Animal.swift
public struct PetColor: Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public init(id: String, displayName: String) {
        self.id = id; self.displayName = displayName
    }
}

public struct Animal: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let colors: [PetColor]
    public let defaultColorID: String
    /// Some creatures (monkey, skeleton, totoro) ship no walk_fast cycle; their fast
    /// bucket reuses the run cycle.
    public let hasWalkFast: Bool

    public init(id: String, name: String, colors: [PetColor],
                defaultColorID: String, hasWalkFast: Bool) {
        self.id = id; self.name = name; self.colors = colors
        self.defaultColorID = defaultColorID; self.hasWalkFast = hasWalkFast
    }

    /// The requested color, or the animal's default when that id isn't in its palette.
    public func color(withID id: String) -> PetColor {
        colors.first { $0.id == id }
            ?? colors.first { $0.id == defaultColorID }
            ?? colors[0]
    }
}

public enum PetNaming {
    /// "rubber-duck" -> "Rubber Duck", "socks_black" -> "Socks Black".
    public static func humanize(_ id: String) -> String {
        id.split(whereSeparator: { $0 == "_" || $0 == "-" })
          .map { $0.prefix(1).uppercased() + $0.dropFirst() }
          .joined(separator: " ")
    }
}

public enum AnimalLibrary {
    public static let all: [Animal] = [
        make("chicken",     ["brown", "white"]),
        make("clippy",      ["black", "brown", "green", "yellow"]),
        make("cockatiel",   ["brown", "gray"]),
        make("crab",        ["red"]),
        make("deno",        ["green"]),
        make("dog",         ["akita", "black", "brown", "red", "white"]),
        make("fox",         ["red", "white"]),
        make("horse",       ["black", "brown", "magical", "paint_beige", "paint_black",
                             "paint_brown", "socks_beige", "socks_black", "socks_brown",
                             "warrior", "white"]),
        make("mod",         ["purple"]),
        make("monkey",      ["gray"], hasWalkFast: false),
        make("morph",       ["purple"]),
        make("panda",       ["black", "brown"]),
        make("rat",         ["brown", "gray", "white"]),
        make("rocky",       ["gray"]),
        make("rubber-duck", ["yellow"]),
        make("skeleton",    ["blue", "brown", "green", "orange", "pink", "purple",
                             "red", "warrior", "white", "yellow"], hasWalkFast: false),
        make("snail",       ["brown"]),
        make("snake",       ["green"]),
        make("totoro",      ["gray"], hasWalkFast: false),
        make("turtle",      ["green", "orange"]),
        make("vampire",     ["converted", "countess", "girl"], defaultColor: "countess"),
        make("zappy",       ["yellow"]),
    ]

    public static let `default` = all.first { $0.id == "dog" } ?? all[0]

    public static func animal(withID id: String) -> Animal {
        all.first { $0.id == id } ?? `default`
    }

    /// `defaultColor` defaults to the first listed color (alphabetical), which avoids the
    /// novelty variants (e.g. dog's flaming "red") for every pet except vampire.
    private static func make(_ id: String, _ colors: [String],
                             defaultColor: String? = nil, hasWalkFast: Bool = true) -> Animal {
        Animal(id: id,
               name: PetNaming.humanize(id),
               colors: colors.map { PetColor(id: $0, displayName: PetNaming.humanize($0)) },
               defaultColorID: defaultColor ?? colors[0],
               hasWalkFast: hasWalkFast)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme Zoomies -only-testing:ZoomiesCoreTests/AnimalLibraryTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/ZoomiesCore/Animal.swift Tests/ZoomiesCoreTests/AnimalLibraryTests.swift
git commit -m "feat: pet data model with color variants and 22-creature roster"
```

---

### Task 2: PetAnimator state machine (ZoomiesCore)

Replaces `GaitAnimator`'s role. Pure, AppKit/clock-free.

**Files:**
- Create: `Sources/ZoomiesCore/PetAnimator.swift`
- Create: `Tests/ZoomiesCoreTests/PetAnimatorTests.swift`
- Delete: `Sources/ZoomiesCore/GaitAnimator.swift`, `Tests/ZoomiesCoreTests/GaitAnimatorTests.swift`
- Modify: `Sources/ZoomiesCore/SpeedMapping.swift:13-19` (comment only — drop the stale "two frames" rationale; the curve now scales within-state playback, not a 2-frame flip)

**Interfaces:**
- Produces:
  - `enum PetState: String, CaseIterable { case idle, walk, walkFast, run; var level: Int; static func atLevel(_:) -> PetState }`
  - `struct PetAnimator` with `init()`, `mutating setLoad(_:)`, `mutating setSpeed(_:)`, `mutating setDurations(_:[Double])`, `@discardableResult mutating advance(by dt: Double) -> Bool`, `var state: PetState`, `var frameIndex: Int`, `var playbackRate: Double`.
- The `advance` return value is `true` when the state changed that tick (the caller must then call `setDurations` with the new state's frame durations).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/ZoomiesCoreTests/PetAnimatorTests.swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme Zoomies -only-testing:ZoomiesCoreTests/PetAnimatorTests -destination 'platform=macOS' 2>&1 | tail -20`
Expected: FAIL — `PetAnimator` / `PetState` undefined.

- [ ] **Step 3: Create PetAnimator**

```swift
// Sources/ZoomiesCore/PetAnimator.swift
import Foundation

public enum PetState: String, CaseIterable, Equatable {
    case idle, walk, walkFast, run

    public var level: Int {
        switch self {
        case .idle: return 0; case .walk: return 1
        case .walkFast: return 2; case .run: return 3
        }
    }

    public static func atLevel(_ l: Int) -> PetState {
        [.idle, .walk, .walkFast, .run][min(max(l, 0), 3)]
    }
}

/// Pure, AppKit-free engine. Maps eased system load to one of four gait states with
/// hysteresis (so it never flickers at a boundary) and advances the current state's frame
/// cursor by the GIF's own per-frame durations, sped up by load × the user's speed.
public struct PetAnimator {
    public private(set) var state: PetState = .idle
    public private(set) var frameIndex: Int = 0

    private var elapsed: Double = 0           // time banked toward the current frame
    private var durations: [Double] = [0.125] // current state's per-frame seconds
    private var load: Double = 0
    private var speed: Double = 1

    // Load needed to climb out of level i upward (index 0,1,2)…
    private static let up:   [Double] = [0.10, 0.38, 0.70]
    // …and to fall out of level i downward (index i-1, i.e. for levels 1,2,3).
    private static let down: [Double] = [0.06, 0.30, 0.60]

    public init() {}

    public mutating func setLoad(_ value: Double)  { load = min(max(value, 0), 1) }
    public mutating func setSpeed(_ value: Double) { speed = max(0.1, value) }

    /// Feed the current state's per-frame durations. Clamps the cursor if the new state
    /// has fewer frames.
    public mutating func setDurations(_ values: [Double]) {
        durations = values.isEmpty ? [0.125] : values
        if frameIndex >= durations.count { frameIndex = 0; elapsed = 0 }
    }

    /// Advance by `dt` seconds. Returns true when the state changed this tick — the caller
    /// must then call `setDurations` with the new state's durations before the next tick.
    @discardableResult
    public mutating func advance(by dt: Double) -> Bool {
        guard dt > 0 else { return false }
        let lvl = state.level
        if lvl < 3, load > Self.up[lvl] {
            state = .atLevel(lvl + 1); frameIndex = 0; elapsed = 0; return true
        }
        if lvl > 0, load < Self.down[lvl - 1] {
            state = .atLevel(lvl - 1); frameIndex = 0; elapsed = 0; return true
        }
        elapsed += dt * playbackRate
        var guardrail = 0
        while elapsed >= durations[frameIndex], guardrail < 4096 {
            elapsed -= durations[frameIndex]
            frameIndex = (frameIndex + 1) % durations.count
            guardrail += 1
        }
        return false
    }

    /// Native pace at idle, winding up with load (eased) and the user's speed multiplier,
    /// capped so a very high Speed setting can't shred the cycle.
    public var playbackRate: Double {
        let eased = load * load
        return min(speed * (0.9 + 0.9 * eased), 5.0)
    }
}
```

- [ ] **Step 4: Delete the old gait engine and its tests**

```bash
git rm Sources/ZoomiesCore/GaitAnimator.swift Tests/ZoomiesCoreTests/GaitAnimatorTests.swift
```

- [ ] **Step 5: Update the stale SpeedMapping comment**

In `Sources/ZoomiesCore/SpeedMapping.swift`, replace the `loadCurveExponent` doc comment (lines ~13–19) so it no longer claims "the run cycle is only two frames." New comment:

```swift
    /// Shapes the load→pace response. A straight linear ramp makes the pet look like it's
    /// sprinting at 20–30% load, so we raise load to this power to ease the curve in: light
    /// and medium load stay a calm trot, and the speed-up concentrates near full load where
    /// the Mac is actually busy. Matters most for the RAM source, which idles ~60% on a
    /// healthy Mac. 1.0 = linear; higher = gentler low end.
    public static let loadCurveExponent: Double = 3
```

- [ ] **Step 6: Run the full ZoomiesCore suite**

Run: `xcodebuild test -scheme Zoomies -only-testing:ZoomiesCoreTests -destination 'platform=macOS' 2>&1 | tail -25`
Expected: PASS, no reference to `GaitAnimator` remains.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: PetAnimator state machine replaces GaitAnimator"
```

---

### Task 3: Import assets + wire the bundle (tooling + resources)

**Files:**
- Create: `Tools/ImportPets/main.swift`
- Delete: `Tools/SpriteGenerator/` (obsolete sheet generator)
- Create (generated): `Sources/Zoomies/Pets/<pet>/{<color>_<state>.gif, icon_<color>.png, license.txt}`
- Delete: `resources/{dog,fox,oneko,chocobo}/`, `Sources/Zoomies/Sprites/*.png`
- Modify: `project.yml:30-36` (swap the `Sprites` folder reference for `Pets`)

**Interfaces:**
- Produces the bundled asset tree consumed by `FrameLoader` in Task 4: state GIFs at
  `Pets/<pet>/<color>_<state>.gif` (state ∈ idle/walk/walk_fast/run) and thumbnails at
  `Pets/<pet>/icon_<color>.png`.

- [ ] **Step 1: Write the importer**

```swift
// Tools/ImportPets/main.swift
// Usage: swift Tools/ImportPets/main.swift <webpets-checkout> <dest-dir>
// Copies the idle/walk/walk_fast/run GIFs + icon PNGs + license for every color variant,
// and prints an AnimalLibrary cross-check so the hand-written roster can be verified.
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: import <webpetsRoot> <destDir>\n".utf8))
    exit(2)
}
let media = URL(fileURLWithPath: args[1]).appendingPathComponent("public/media")
let dest  = URL(fileURLWithPath: args[2])
let fm = FileManager.default
let states = ["idle", "walk", "walk_fast", "run"]
let skip: Set<String> = ["background", "icon", "walkers_wide"]

try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
var report: [(String, [String], Bool)] = []   // pet, colors, hasWalkFast

for pet in (try fm.contentsOfDirectory(atPath: media.path)).sorted() where !skip.contains(pet) {
    let petSrc = media.appendingPathComponent(pet)
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: petSrc.path, isDirectory: &isDir), isDir.boolValue else { continue }
    let files = (try? fm.contentsOfDirectory(atPath: petSrc.path)) ?? []
    let colors = files.filter { $0.hasSuffix("_idle_8fps.gif") }
                      .map { String($0.dropLast("_idle_8fps.gif".count)) }
                      .sorted()
    guard !colors.isEmpty else { continue }

    let petDst = dest.appendingPathComponent(pet)
    try? fm.createDirectory(at: petDst, withIntermediateDirectories: true)
    var hasWalkFast = true

    for color in colors {
        for state in states {
            let src = petSrc.appendingPathComponent("\(color)_\(state)_8fps.gif")
            if fm.fileExists(atPath: src.path) {
                let dst = petDst.appendingPathComponent("\(color)_\(state).gif")
                try? fm.removeItem(at: dst); try? fm.copyItem(at: src, to: dst)
            } else if state == "walk_fast" {
                hasWalkFast = false
            }
        }
        let icon = petSrc.appendingPathComponent("icon_\(color).png")
        if fm.fileExists(atPath: icon.path) {
            let dst = petDst.appendingPathComponent("icon_\(color).png")
            try? fm.removeItem(at: dst); try? fm.copyItem(at: icon, to: dst)
        }
    }
    for lic in ["license.txt", "LICENSE", "license"] {
        let s = petSrc.appendingPathComponent(lic)
        if fm.fileExists(atPath: s.path) {
            let d = petDst.appendingPathComponent("license.txt")
            try? fm.removeItem(at: d); try? fm.copyItem(at: s, to: d); break
        }
    }
    report.append((pet, colors, hasWalkFast))
}

print("Imported \(report.count) pets:")
for (pet, colors, fast) in report {
    print("  \(pet): \(colors.count) colors\(fast ? "" : "  (no walk_fast)")")
}
```

- [ ] **Step 2: Run the importer against the webpets clone**

Run:
```bash
swift Tools/ImportPets/main.swift /tmp/webpets Sources/Zoomies/Pets 2>&1 | tail -30
```
Expected: "Imported 22 pets:" with monkey/skeleton/totoro flagged `(no walk_fast)`. (If `/tmp/webpets` is gone: `git clone --depth 1 https://github.com/sankalpaacharya/webpets /tmp/webpets`.)

- [ ] **Step 3: Verify the asset tree matches the roster**

Run:
```bash
echo "pets dirs: $(ls Sources/Zoomies/Pets | wc -l)"
echo "state gifs: $(find Sources/Zoomies/Pets -name '*.gif' | wc -l)"
echo "icons: $(find Sources/Zoomies/Pets -name 'icon_*.png' | wc -l)"
echo "licenses: $(find Sources/Zoomies/Pets -name 'license.txt' | wc -l)"
# Spot check that the dog default (akita) has all 4 states:
ls Sources/Zoomies/Pets/dog/akita_*.gif
```
Expected: 22 dirs; ~216 gifs (57×4 minus the 12 missing walk_fast); 57 icons; licenses present; akita shows idle/walk/walk_fast/run.

- [ ] **Step 4: Remove obsolete sheet assets and the old generator**

```bash
git rm -r resources/dog resources/fox resources/oneko resources/chocobo
git rm Sources/Zoomies/Sprites/oneko_sheet.png Sources/Zoomies/Sprites/dog_sheet.png \
       Sources/Zoomies/Sprites/fox_sheet.png Sources/Zoomies/Sprites/chocobo_sheet.png
git rm -r Tools/SpriteGenerator
```

- [ ] **Step 5: Point the bundle at `Pets`**

In `project.yml`, change the `Zoomies` target `sources` block (lines ~30–36) from:

```yaml
      - path: Sources/Zoomies
        excludes:
          - "Info.plist"
          - "Sprites"
      - path: Sources/Zoomies/Sprites
        type: folder
```

to:

```yaml
      - path: Sources/Zoomies
        excludes:
          - "Info.plist"
          - "Pets"
      - path: Sources/Zoomies/Pets
        type: folder
```

- [ ] **Step 6: Regenerate the project**

Run: `xcodegen generate 2>&1 | tail -5` (or `make generate` if the Makefile wraps it).
Expected: "Created project at .../Zoomies.xcodeproj". (App target won't compile yet — Task 4.)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: import webpets GIF assets; drop old sheets and SpriteGenerator"
```

---

### Task 4: Runtime swap — GIF loader, controller, settings wiring (app target)

After this task the app compiles and runs with the new pets.

**Files:**
- Modify: `Sources/Zoomies/FrameLoader.swift` (full rewrite)
- Modify: `Sources/Zoomies/PetController.swift` (full rewrite)
- Modify: `Sources/Zoomies/AppSettings.swift` (add `colorID`)
- Modify: `Sources/Zoomies/AppDelegate.swift:30-50` (wire color + setPet)

**Interfaces:**
- Consumes: `Animal`, `PetColor`, `PetState`, `PetAnimator` (Tasks 1–2); assets at `Pets/<pet>/<color>_<state>.gif` and `Pets/<pet>/icon_<color>.png` (Task 3).
- Produces:
  - `FrameLoader.PetClips { let states: [PetState: FrameLoader.StateClip]; let thumbnail: NSImage? }`
  - `FrameLoader.StateClip { let left: [NSImage]; let right: [NSImage]; let durations: [Double] }`
  - `FrameLoader.loadClips(_ animal: Animal, colorID: String) -> PetClips`
  - `FrameLoader.loadThumbnail(_ animal: Animal, colorID: String) -> NSImage?`
  - `PetController.setPet(_ animal: Animal, colorID: String)`
  - `AppSettings.colorID: String`

- [ ] **Step 1: Rewrite FrameLoader for GIFs**

```swift
// Sources/Zoomies/FrameLoader.swift
import AppKit
import ImageIO
import ZoomiesCore

enum FrameLoader {
    /// Content height in points the tallest frame is scaled to. The menu bar is ~22pt;
    /// shorter states (idle) render smaller and stay planted on the shared baseline.
    static let iconHeight: CGFloat = 22
    /// Gap (points) kept on the trailing edge so the sprite doesn't hug the % label.
    static let trailingPad: CGFloat = 4

    struct StateClip {
        let left: [NSImage]
        let right: [NSImage]
        let durations: [Double]
    }
    struct PetClips {
        let states: [PetState: StateClip]
        let thumbnail: NSImage?
    }

    private static let stateFile: [PetState: String] = [
        .idle: "idle", .walk: "walk", .walkFast: "walk_fast", .run: "run"
    ]

    // MARK: - Public API

    /// Decode every state's GIF for one pet+color, register all frames of all states to a
    /// single bottom-center baseline and scale (so switching idle↔walk↔run never jumps or
    /// resizes), and pre-mirror for right-facing. Native art faces left.
    static func loadClips(_ animal: Animal, colorID: String) -> PetClips {
        let color = animal.color(withID: colorID).id

        // 1. Decode raw frames + durations per state (walkFast falls back to run).
        var raw: [PetState: (frames: [CGImage], durations: [Double])] = [:]
        for state in PetState.allCases {
            var key = state
            if state == .walkFast, !animal.hasWalkFast { key = .run }
            if let url = gifURL(pet: animal.id, color: color, state: stateFile[key]!) {
                let decoded = decodeGIF(url)
                if !decoded.frames.isEmpty { raw[state] = decoded }
            }
        }
        guard !raw.isEmpty else { return PetClips(states: [:], thumbnail: loadThumbnail(animal, colorID: colorID)) }

        // 2. Shared registration across ALL frames of ALL states.
        let allFrames = raw.values.flatMap { $0.frames }
        let boxes = allFrames.map { contentBox($0) }
        let maxContentH = boxes.map { $0.h }.max() ?? 1
        let maxContentW = boxes.map { $0.w }.max() ?? 1
        let backing = NSScreen.main?.backingScaleFactor ?? 2
        let scale = (iconHeight * backing) / CGFloat(max(maxContentH, 1))
        let canvasHpx = Int((iconHeight * backing).rounded())
        let contentWpx = Int((CGFloat(maxContentW) * scale).rounded())
        let padPx = Int((trailingPad * backing).rounded())
        let canvasWpx = max(contentWpx + padPx, 1)
        let ptSize = NSSize(width: CGFloat(canvasWpx) / backing, height: iconHeight)

        // 3. Render each frame anchored bottom-center; mirror for right.
        var states: [PetState: StateClip] = [:]
        for state in PetState.allCases {
            guard let r = raw[state] else { continue }
            let left = r.frames.map { f in
                render(f, box: contentBox(f), scale: scale,
                       canvasWpx: canvasWpx, canvasHpx: canvasHpx,
                       contentWpx: contentWpx, ptSize: ptSize)
            }
            let right = left.map { mirrored($0) }
            states[state] = StateClip(left: left, right: right, durations: r.durations)
        }
        return PetClips(states: states, thumbnail: loadThumbnail(animal, colorID: colorID))
    }

    static func loadThumbnail(_ animal: Animal, colorID: String) -> NSImage? {
        let color = animal.color(withID: colorID).id
        guard let url = Bundle.main.url(forResource: "icon_\(color)", withExtension: "png",
                                        subdirectory: "Pets/\(animal.id)") else { return nil }
        return NSImage(contentsOf: url)
    }

    // MARK: - GIF decode

    private static func gifURL(pet: String, color: String, state: String) -> URL? {
        Bundle.main.url(forResource: "\(color)_\(state)", withExtension: "gif",
                        subdirectory: "Pets/\(pet)")
    }

    private static func decodeGIF(_ url: URL) -> (frames: [CGImage], durations: [Double]) {
        guard let data = try? Data(contentsOf: url),
              let src = CGImageSourceCreateWithData(data as CFData, nil) else { return ([], []) }
        var frames: [CGImage] = []
        var durations: [Double] = []
        for i in 0..<CGImageSourceGetCount(src) {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            frames.append(img)
            let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            let clamped = gif?[kCGImagePropertyGIFDelayTime] as? Double
            let d = (unclamped.map { $0 > 0 ? $0 : nil } ?? nil) ?? clamped ?? 0.125
            durations.append(d < 0.02 ? 0.125 : d)
        }
        return (frames, durations)
    }

    // MARK: - Registration / rendering

    /// Tight alpha bounding box of `img` in CoreGraphics bottom-left pixel coordinates:
    /// (x from left, y from bottom, w, h). Used both to size the cohort and to anchor each
    /// frame's feet to a common baseline.
    private struct Box { let x: Int; let y: Int; let w: Int; let h: Int }

    private static func contentBox(_ img: CGImage) -> Box {
        let w = img.width, h = img.height, bpr = w * 4
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Box(x: 0, y: 0, w: w, h: h)
        }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return Box(x: 0, y: 0, w: w, h: h) }
        let p = data.bindMemory(to: UInt8.self, capacity: bpr * h)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where p[(y * w + x) * 4 + 3] > 10 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return Box(x: 0, y: 0, w: w, h: h) }
        return Box(x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1)
    }

    /// Draw `img` (scaled by `scale`) into a fixed canvas so its content box sits on the
    /// baseline (y=0) and is horizontally centered within the content region. Everything is
    /// in bottom-left coords, so no flips: place the full image so its content corner lands
    /// where we want it.
    private static func render(_ img: CGImage, box: Box, scale: CGFloat,
                              canvasWpx: Int, canvasHpx: Int, contentWpx: Int,
                              ptSize: NSSize) -> NSImage {
        let targetLeft = (CGFloat(contentWpx) - CGFloat(box.w) * scale) / 2
        let drawX = targetLeft - CGFloat(box.x) * scale
        let drawY = -CGFloat(box.y) * scale
        guard let ctx = CGContext(data: nil, width: canvasWpx, height: canvasHpx,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: ptSize)
        }
        ctx.interpolationQuality = .high   // smooth downscale of mid-res pixel art
        ctx.clear(CGRect(x: 0, y: 0, width: canvasWpx, height: canvasHpx))
        ctx.draw(img, in: CGRect(x: drawX, y: drawY,
                                 width: CGFloat(img.width) * scale,
                                 height: CGFloat(img.height) * scale))
        let out = NSImage(size: ptSize)
        if let cg = ctx.makeImage() {
            let rep = NSBitmapImageRep(cgImage: cg)
            rep.size = ptSize
            out.addRepresentation(rep)
        }
        return out
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
        let size = image.size
        let out = NSImage(size: size)
        out.lockFocus()
        let t = NSAffineTransform()
        t.translateX(by: size.width, yBy: 0)
        t.scaleX(by: -1, yBy: 1)
        t.concat()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        out.unlockFocus()
        return out
    }
}
```

- [ ] **Step 2: Rewrite PetController to drive PetAnimator**

```swift
// Sources/Zoomies/PetController.swift
import AppKit
import QuartzCore
import ZoomiesCore

/// Drives the GIF-based pet inside the menu-bar status item. A display-synced
/// `CADisplayLink` ticks a pure `PetAnimator`, which picks the gait state (idle/walk/
/// walk_fast/run) from system load and advances frames by their native durations. The
/// button image is only reassigned when the visible frame actually changes.
final class PetController {
    private weak var statusItem: NSStatusItem?

    private var clips = FrameLoader.PetClips(states: [:], thumbnail: nil)
    private var animator = PetAnimator()
    private var direction: DirectionTracker.Direction = .left

    private var load: Double = 0
    private var speed: Double = 1.0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var shownState: PetState?
    private var shownFrame = -1
    private var shownLeft = true

    private let cursorMonitor = MouseDirectionMonitor()

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        cursorMonitor.onChange = { [weak self] newDirection in
            guard let self, newDirection != self.direction else { return }
            self.direction = newDirection
            self.render(force: true)
        }
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        displayLink?.invalidate()
        cursorMonitor.stop()
    }

    func setPet(_ animal: Animal, colorID: String) {
        clips = FrameLoader.loadClips(animal, colorID: colorID)
        animator = PetAnimator()
        animator.setSpeed(speed)
        animator.setLoad(load)
        syncDurations()
        shownState = nil; shownFrame = -1
        render(force: true)
    }

    func setLoad(_ load: Double)  { self.load = load;  animator.setLoad(load) }
    func setSpeed(_ speed: Double) { self.speed = speed; animator.setSpeed(speed) }

    func start() { startDisplayLink(); cursorMonitor.start() }
    func stop() {
        displayLink?.invalidate(); displayLink = nil; cursorMonitor.stop()
    }

    // MARK: - Display link

    private func startDisplayLink() {
        guard displayLink == nil, let view = statusItem?.button else { return }
        let link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 30, preferred: 30)
        link.isPaused = reduceMotion
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
        render(force: true)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let raw = lastTimestamp > 0 ? link.timestamp - lastTimestamp : link.duration
        lastTimestamp = link.timestamp
        if animator.advance(by: min(max(raw, 0), 0.1)) {
            syncDurations()   // state changed — hand the animator the new cycle's durations
        }
        render()
    }

    @objc private func accessibilityChanged() {
        displayLink?.isPaused = reduceMotion
        lastTimestamp = 0
        render(force: true)
    }

    // MARK: - Rendering

    private func syncDurations() {
        if let d = clips.states[animator.state]?.durations { animator.setDurations(d) }
    }

    private func render(force: Bool = false) {
        guard let button = statusItem?.button else { return }
        // Reduce motion: hold the idle pose if we have one, else the calmest state.
        let state = reduceMotion ? (clips.states[.idle] != nil ? .idle : animator.state)
                                 : animator.state
        guard let clip = clips.states[state] else { return }
        let frames = direction == .left ? clip.left : clip.right
        guard !frames.isEmpty else { return }
        let frame = reduceMotion ? 0 : min(animator.frameIndex, frames.count - 1)
        let isLeft = direction == .left

        guard force || state != shownState || frame != shownFrame || isLeft != shownLeft
        else { return }
        shownState = state; shownFrame = frame; shownLeft = isLeft
        button.image = frames[frame]
    }
}
```

- [ ] **Step 3: Add colorID to AppSettings**

In `Sources/Zoomies/AppSettings.swift`: add the published property, key, and validating init.

```swift
    /// Which color variant of the selected animal roams the menu bar.
    @Published var colorID: String { didSet { defaults.set(colorID, forKey: Keys.colorID) } }
```
Add to `Keys`: `static let colorID = "colorID"`.
Append to `init()` (after `animalID` is set):
```swift
        let animal = AnimalLibrary.animal(withID: animalID)
        let storedColor = defaults.string(forKey: Keys.colorID)
        colorID = animal.colors.contains { $0.id == storedColor } ? storedColor!
                                                                   : animal.defaultColorID
```

- [ ] **Step 4: Wire color + setPet in AppDelegate**

In `Sources/Zoomies/AppDelegate.swift`, replace the initial pet setup (line ~31) and the `$animalID` sink (lines ~46–50):

```swift
        pet = PetController(statusItem: statusItem)
        pet.setPet(AnimalLibrary.animal(withID: settings.animalID), colorID: settings.colorID)
        pet.setSpeed(settings.speed)
```

```swift
        // Switching animal: keep the current color if the new pet has it, else snap to its
        // default (which re-fires through the colorID sink). Either way one setPet runs.
        settings.$animalID
            .dropFirst()
            .sink { [weak self] id in
                guard let self else { return }
                let animal = AnimalLibrary.animal(withID: id)
                if animal.colors.contains(where: { $0.id == self.settings.colorID }) {
                    self.pet.setPet(animal, colorID: self.settings.colorID)
                } else {
                    self.settings.colorID = animal.defaultColorID
                }
            }
            .store(in: &cancellables)
        settings.$colorID
            .dropFirst()
            .sink { [weak self] color in
                guard let self else { return }
                self.pet.setPet(AnimalLibrary.animal(withID: self.settings.animalID), colorID: color)
            }
            .store(in: &cancellables)
```

- [ ] **Step 5: Build and run**

Run:
```bash
xcodegen generate >/dev/null 2>&1
xcodebuild -scheme Zoomies -configuration Debug build 2>&1 | tail -15
```
Expected: BUILD SUCCEEDED.

Then launch and confirm a pet (default = Dog/akita) sits idle in the menu bar and breaks into a walk/run as you spike CPU (e.g. `yes > /dev/null &` then `kill %1`). Confirm the pet faces the direction the mouse last moved and that switching states shows no jump/resize.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: GIF frame loader + state-driven PetController with color selection"
```

---

### Task 5: Settings UI — scrollable grid + color picker

**Files:**
- Modify: `Sources/Zoomies/BehaviorPane.swift` (Animal section + new color section)

**Interfaces:**
- Consumes: `AnimalLibrary.all`, `Animal.colors`, `FrameLoader.loadThumbnail`, `AppSettings.animalID`, `AppSettings.colorID`.

- [ ] **Step 1: Make the animal grid scrollable and add a color picker**

Replace the `// MARK: Animal` section in `BehaviorPane.body` with the scrollable grid plus a color section that only appears when the selected pet has more than one color:

```swift
            // MARK: Animal
            Section {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(AnimalLibrary.all) { animal in
                            AnimalCell(animal: animal,
                                       isSelected: animal.id == settings.animalID) {
                                settings.animalID = animal.id
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 260)   // scrolls through all 22 creatures
            } header: {
                Text("Animal")
            } footer: {
                Text("The critter that lives in your menu bar.")
            }

            // MARK: Color
            let selected = AnimalLibrary.animal(withID: settings.animalID)
            if selected.colors.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(selected.colors) { color in
                                ColorSwatch(animal: selected, color: color,
                                            isSelected: color.id == settings.colorID) {
                                    settings.colorID = color.id
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Color")
                }
            }
```

Update the grid column count for the larger roster (replace the `columns` declaration):

```swift
    // Four columns keep the 22-creature grid compact without tiny cells.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
```

- [ ] **Step 2: Point the cell thumbnail at the default color and add the swatch view**

In `AnimalCell.loadIcon()` replace the body with:

```swift
    private func loadIcon() {
        guard icon == nil else { return }
        icon = FrameLoader.loadThumbnail(animal, colorID: animal.defaultColorID)
    }
```

Add a `ColorSwatch` view (next to `AnimalCell`):

```swift
private struct ColorSwatch: View {
    let animal: Animal
    let color: PetColor
    let isSelected: Bool
    let action: () -> Void

    @State private var icon: NSImage? = nil

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let icon {
                        Image(nsImage: icon).interpolation(.none).resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15))
                    }
                }
                .frame(width: 34, height: 34)
                Text(color.displayName)
                    .font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(width: 60)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .onAppear { if icon == nil { icon = FrameLoader.loadThumbnail(animal, colorID: color.id) } }
    }
}
```

- [ ] **Step 3: Build and run**

Run: `xcodebuild -scheme Zoomies -configuration Debug build 2>&1 | tail -8`
Expected: BUILD SUCCEEDED.

Launch, open Settings → Behavior: scroll the 22 pets, pick one with variants (e.g. Skeleton or Horse), and confirm the Color row appears and switching a color updates the menu-bar pet live. Confirm a single-color pet (e.g. Crab) hides the Color row.

- [ ] **Step 4: Commit**

```bash
git add Sources/Zoomies/BehaviorPane.swift
git commit -m "feat: scrollable pet grid and per-pet color picker in Settings"
```

---

### Task 6: Docs, credits, and final verification

**Files:**
- Modify: `README.md`
- Modify: `Sources/Zoomies/AboutPane.swift`

- [ ] **Step 1: Update README**

Replace the pet roster / sprite description with the webpets roster (22 creatures, ~57 color variants, idle→walk→walk_fast→run driven by load) and add a credit line:

```markdown
## Pets

Pets are the [webpets](https://github.com/sankalpaacharya/webpets) sprite set — 22 creatures
(dog, fox, panda, skeleton, horse, crab, totoro, vampire, and more), most with several color
variants. Each ships idle / walk / walk_fast / run cycles; Zoomies plays the cycle that
matches how busy your Mac is and mirrors it to face your cursor. Art © their respective
authors; per-pet licenses live in `Sources/Zoomies/Pets/<pet>/license.txt`.
```

(Remove any remaining mention of oneko/dog/fox/chocobo sprite sheets, the Neko Archive / oneko.js layouts, and `SpriteGenerator`.)

- [ ] **Step 2: Add a credit to the About pane**

Add a line crediting the webpets sprite set in `AboutPane.swift` (match the existing layout — a `Text` link/footnote near the existing credits). Example:

```swift
            Text("Pets from the webpets sprite set by Sankalpa Acharya.")
                .font(.footnote)
                .foregroundStyle(.secondary)
```

- [ ] **Step 3: Grep for stale references**

Run:
```bash
grep -rniE "oneko|chocobo|isClassic|GaitAnimator|SpriteGenerator|classicScript|loadRunVariants|runFrameCount" \
  Sources Tests README.md || echo "clean"
```
Expected: `clean` (no matches). Fix any stragglers.

- [ ] **Step 4: Full test + release-style build**

Run:
```bash
xcodebuild test -scheme Zoomies -only-testing:ZoomiesCoreTests -destination 'platform=macOS' 2>&1 | tail -15
xcodebuild -scheme Zoomies -configuration Release build 2>&1 | tail -8
```
Expected: tests PASS; BUILD SUCCEEDED.

- [ ] **Step 5: Manual smoke test**

Launch the Release build. Verify: default Dog idles and escalates with CPU load without jumping; facing flips with the mouse; Settings lets you pick any of the 22 pets and (where available) a color, applied live; enabling Reduce Motion holds a calm frame.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "docs: README + About credits for the webpets roster"
```

---

## Self-Review

**Spec coverage:**
- Remove 4 old pets → Task 3 (assets) + Task 6 (grep gate). ✓
- All 22 creatures + color picker → Task 1 (roster), Task 5 (UI). ✓
- Load → idle/walk/walk_fast/run → Task 2 (PetAnimator). ✓
- Smooth motion (no jump/flicker, speed-responsive, reduce-motion) → Task 2 (hysteresis, playbackRate) + Task 4 (shared registration, render-on-change, reduce-motion hold). ✓
- Preserve attribution → Task 3 (copy license.txt) + Task 6 (README/About). ✓
- GIF-native strategy → Task 4 (CGImageSource decode). ✓
- Non-goals (swipe/with_ball/lie, per-pet color memory, chasing) → excluded. ✓

**Placeholder scan:** Step 2 of Task 6 references the existing About layout rather than full code — acceptable as it's a one-line additive `Text` matched to a file whose exact contents the implementer reads; all engine/loader/controller steps contain complete code. No TBD/TODO.

**Type consistency:** `loadClips`/`loadThumbnail`/`StateClip`/`PetClips` names match between FrameLoader (Task 4) and PetController/BehaviorPane (Tasks 4–5). `PetState` cases (`idle/walk/walkFast/run`) and `setDurations`/`advance(by:)->Bool` consistent between PetAnimator (Task 2) and PetController (Task 4). `colorID` consistent across AppSettings/AppDelegate/BehaviorPane.

**Open verification points (flagged in-task, resolved at run time):** downscale interpolation (`.high` chosen; switch to `.none` if shimmer), exact `iconHeight` (22pt), and confirming every pet's native facing is left during the Task 5 smoke test.
