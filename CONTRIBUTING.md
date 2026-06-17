# Contributing to Zoomies

Thanks for taking the time to contribute! This guide covers everything you need — from filing a bug to adding a brand-new animal.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Adding a New Animal](#adding-a-new-animal)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Code Style](#code-style)

---

## Code of Conduct

Be respectful. Constructive criticism is welcome; personal attacks are not. If something feels off, open an issue rather than a comment war.

---

## Reporting Bugs

Before opening a bug report, check if one [already exists](https://github.com/KartikLabhshetwar/zoomies/issues).

When filing a new issue, include:

- **macOS version** (e.g. Sonoma 14.5)
- **Chip** — Apple Silicon or Intel
- **Zoomies version** (shown in the menu or from the DMG filename)
- **What you expected** vs **what happened**
- **Steps to reproduce** — the more specific, the faster the fix

---

## Suggesting Features

Open an [issue](https://github.com/KartikLabhshetwar/zoomies/issues/new) with the `enhancement` label. Describe:

- What problem it solves or what it adds
- Any rough idea of how it could work
- Why it fits a lightweight menu-bar app

The most welcome suggestions: new animals, animation improvements, and performance wins. Scope-expanding features (network monitoring, notifications, etc.) are less likely to land — Zoomies is intentionally tiny.

---

## Development Setup

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 15+ | [developer.apple.com/xcode](https://developer.apple.com/xcode/) |
| XcodeGen | latest | `brew install xcodegen` |

### First run

```sh
git clone https://github.com/KartikLabhshetwar/zoomies.git
cd zoomies
make run
```

This generates `Zoomies.xcodeproj`, builds the app (Debug, unsigned), and launches it. The animal appears in your menu bar.

The generated `.xcodeproj` is git-ignored — never edit it directly. All project config lives in `project.yml`.

### Useful commands

```sh
make build      # build without launching
make test       # run the full unit test suite
make stop       # quit the running app
make sprites    # regenerate animal sprite frames into the asset catalog
make clean      # wipe build/ and the generated project
```

---

## Making Changes

1. **Fork** the repo and create a branch from `main`:

   ```sh
   git checkout -b my-feature
   ```

2. **Make your changes.** If you touched `ZoomiesCore` logic, add or update tests in `Tests/ZoomiesCoreTests/`.

3. **Run the tests:**

   ```sh
   make test
   ```

4. **Run the app and verify your change works:**

   ```sh
   make run
   ```

5. **Commit** with a short, present-tense message:

   ```
   add rabbit idle-frame variation
   fix speed mapping at 0% load
   ```

6. **Open a pull request** against `main`.

---

## Adding a New Animal

New animals are the most fun contribution. Here's exactly how to do it.

### 1. Prepare source frames

- Create a folder under `resources/<animal>/` with your source PNGs
- Frames should be **pixel art**, roughly **32–48 px** tall, on a **transparent background**
- Name them `<animal>_0.png`, `<animal>_1.png`, etc.
- Provide at least **3–5 frames** that loop cleanly as a run cycle
- Include the **license / attribution** for the sprite in a comment inside `Tools/SpriteGenerator/main.swift`

### 2. Register the animal in the sprite generator

Open `Tools/SpriteGenerator/main.swift` and add an `AnimalImport` entry to the `animals` array:

```swift
AnimalImport(
    id: "cat",                          // unique string ID, lowercase
    sourcePaths: (0..<4).map { "resources/cat/cat_\($0).png" },
    frameSequence: [0, 1, 2, 3],       // order to play frames (can repeat for hold frames)
    conversion: .alphaThreshold        // or .luminanceToAlpha — see note below
)
```

**Conversion modes:**
- `.luminanceToAlpha` — for dark-on-light sprites (e.g. the horse): dark pixels stay opaque, light pixels become transparent. Use this for sprites that are already the right shape but have a white background.
- `.alphaThreshold` — for colored sprites with transparency: any non-transparent pixel becomes full black. Use this for pixel art that already has an alpha channel.

### 3. Register the animal in the app

Open `Sources/ZoomiesCore/Animal.swift` and add a case to the `Animal` enum following the existing pattern.

### 4. Regenerate the asset catalog

```sh
make sprites
```

This runs the generator and writes the new imageset into `Sources/Zoomies/Assets.xcassets/`. Commit the generated assets along with your source PNGs and code changes.

### 5. Test it

```sh
make run
```

Click the menu bar animal → your new animal should appear in the list and Settings gallery. Make sure it animates smoothly at both slow and fast speeds.

---

## Pull Request Guidelines

- **One concern per PR** — a new animal, a bug fix, or a refactor. Not all three.
- **Keep the app lightweight** — avoid adding dependencies, frameworks, or heavy abstractions.
- **Tests for logic** — any new `ZoomiesCore` code should have unit tests.
- **No generated files in the diff** — `Zoomies.xcodeproj` is git-ignored; don't add it.
- **Update the README** if your change affects setup steps, commands, or features.
- PRs that break `make test` or `make build` will not be merged until fixed.

---

## Code Style

- Follow the existing Swift style in the file you're editing — no need for a formatter
- Prefer small, single-purpose types over large classes
- No comments that just restate the code — only comment non-obvious behavior or constraints
- Pure logic goes in `ZoomiesCore`; AppKit code goes in the `Zoomies` app target

---

Questions? Open an [issue](https://github.com/KartikLabhshetwar/zoomies/issues) or start a [discussion](https://github.com/KartikLabhshetwar/zoomies/discussions).
