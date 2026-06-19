# Contributing to Zoomies

Thanks for taking the time to contribute! This guide covers everything you need — from filing a bug to tweaking the cat sprite.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Sprite Frames](#sprite-frames)
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

The most welcome suggestions: animation improvements and performance wins. Scope-expanding features (network monitoring, notifications, etc.) are less likely to land — Zoomies is intentionally tiny.

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

This generates `Zoomies.xcodeproj`, builds the app (Debug, unsigned), and launches it. The cat appears in your menu bar.

The generated `.xcodeproj` is git-ignored — never edit it directly. All project config lives in `project.yml`.

### Useful commands

```sh
make build      # build without launching
make test       # run the full unit test suite
make stop       # quit the running app
make sprites    # regenerate the oneko sprite frames into the asset catalog
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
   tune the oneko run-cycle timing
   fix speed mapping at 0% load
   ```

6. **Open a pull request** against `main`.

---

## Sprite Frames

The menu-bar cat is **oneko** — the classic "Neko" sprite (by [adryd](https://github.com/adryd325/oneko.js), MIT). Its two run frames are sliced out of the sprite sheet at build time.

### Source

- `resources/oneko/oneko.gif` — a 256×128 sheet (an 8×4 grid of 32×32 cells), plus its `LICENSE`.

### Slicer

`Tools/SpriteGenerator/main.swift` cuts oneko's left-facing run cells (grid column 4, rows 2–3), tight-crops them, and writes **color** imagesets into `Sources/Zoomies/Assets.xcassets/` as `oneko_0` / `oneko_1`.

To regenerate the frames after changing the sheet or the chosen cells:

```sh
make sprites
```

Commit the regenerated imagesets alongside your change. If you swap in a different sprite sheet, update the `runFrames` cells and the source/license note at the top of `Tools/SpriteGenerator/main.swift`, then run `make run` and confirm the cat animates smoothly at both slow and fast speeds.

---

## Pull Request Guidelines

- **One concern per PR** — a feature, a bug fix, or a refactor. Not all three.
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
