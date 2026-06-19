<div align="center">

# 🐾 Zoomies

**A tiny macOS menu bar app that turns your CPU load into a sprinting cat.**

The busier your Mac, the faster it runs.

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://github.com/KartikLabhshetwar/zoomies/releases)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![Release](https://img.shields.io/github/v/release/KartikLabhshetwar/zoomies?color=brightgreen)](https://github.com/KartikLabhshetwar/zoomies/releases/latest)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

Inspired by [**RunCat**](https://github.com/runcat-dev/RunCat365) — the running cat that speeds up with your CPU. 🐱

</div>

---

## Download

| File | Chip | macOS |
|------|------|-------|
| [Zoomies-1.0_arm64.dmg](https://github.com/KartikLabhshetwar/zoomies/releases/download/v1.0/Zoomies-1.0_arm64.dmg) | Apple Silicon (M1/M2/M3/M4) | 14+ |
| [Zoomies-1.0_x86_64.dmg](https://github.com/KartikLabhshetwar/zoomies/releases/download/v1.0/Zoomies-1.0_x86_64.dmg) | Intel | 14+ |

1. Download the DMG for your chip
2. Open it and drag **Zoomies.app** into `/Applications`
3. Launch it — the cat appears in your menu bar instantly

> **Tip:** If macOS says the app can't be opened, go to **System Settings → Privacy & Security** and click **Open Anyway**. Zoomies is notarized by Apple.

---

## What it does

Zoomies lives in your menu bar as [**oneko**](https://github.com/adryd325/oneko.js) — the classic pixel-art cat. Its run speed scales in real time with your CPU (or memory) load — idle Mac, slow trot; compiling a big project, full sprint.

Click the cat to:
- **See the load** — live CPU (or memory) percentage
- **Open Settings** — speed slider, CPU/Memory toggle, percentage readout, launch at login
- **Quit**

### Features

- **Live animation** — speed scales from ~3 fps (idle) to ~18 fps (heavy load)
- **oneko the cat** 🐱 — the classic "Neko" pixel-art sprite (by adryd), running in full color
- **Settings window** — native macOS settings with a speed-sensitivity slider, CPU / Memory / either toggle, optional percentage readout, and launch-at-login
- **Featherweight** — background agent (no Dock icon), uses only public macOS APIs for CPU and memory stats
- **Reduce Motion** — respects the system setting (drops to a single static frame)

---

## Run locally

### Prerequisites

| Tool | Install |
|------|---------|
| Xcode 15+ | [developer.apple.com/xcode](https://developer.apple.com/xcode/) |
| XcodeGen | `brew install xcodegen` |

### Quick start

```sh
git clone https://github.com/KartikLabhshetwar/zoomies.git
cd zoomies
make run
```

`make run` generates the Xcode project, builds the app, and launches it. The cat will appear in the top-right of your menu bar.

To stress-test the animation (watch it sprint):

```sh
yes > /dev/null &   # spin up a core
# when done:
killall yes
```

### All commands

```sh
make            # list all commands
make build      # build (Debug, unsigned) → build/Build/Products/Debug/Zoomies.app
make run        # build + launch
make test       # run the unit test suite
make stop       # quit the running app
make install    # copy to /Applications and launch
make sprites    # regenerate the oneko sprite frames into the asset catalog
make project    # regenerate Zoomies.xcodeproj from project.yml
make clean      # remove build/ and the generated project
```

---

## How it works

```
CPU/Memory load  →  CPUMonitor  →  SpeedMapping  →  SpriteAnimator  →  NSStatusItem
```

- **`CPUMonitor`** — samples aggregate CPU load every ~2 s via the public mach `host_statistics` API and emits a normalized `0.0–1.0` value
- **`SpeedMapping`** — maps load to a target frame rate (3–18 fps), with an adjustable sensitivity curve from Settings
- **`SpriteAnimator`** — advances the cat's PNG frames on the menu bar item, re-pacing only when speed changes
- **`MenuController`** — builds the click menu (load readout, Settings, Quit)

Pure logic lives in a `ZoomiesCore` library target (unit-tested, no AppKit dependency). The AppKit wiring (`NSStatusItem`, `NSMenu`) lives in the app target.

---

## Project structure

```
zoomies/
├── Sources/
│   ├── ZoomiesCore/        # Pure logic: CPUMonitor, SpeedMapping, AnimalLibrary
│   └── Zoomies/            # AppKit app: AppDelegate, SpriteAnimator, MenuController, Settings UI
│       └── Assets.xcassets/
├── Tests/
│   └── ZoomiesCoreTests/   # Unit tests for core logic
├── Tools/
│   └── SpriteGenerator/    # Build-time tool that draws sprite frames with Core Graphics
├── resources/              # Source sprite sheet (oneko.gif)
├── project.yml             # XcodeGen project definition
├── Makefile                # Build / run / test helpers
└── scripts/
    └── release.sh          # Build, sign, notarize, and package DMGs
```

---

## Acknowledgments

Zoomies stands on the shoulders of **RunCat**. The core idea — a menu/task-bar critter that animates faster as your CPU heats up — comes from that project and its lineage:

- **[RunCat for macOS](https://github.com/Kyome22/menubar_runcat)** by [Takuto Nakamura (Kyome)](https://github.com/Kyome22) — the original menu bar running cat that started it all.
- **[RunCat365](https://github.com/runcat-dev/RunCat365)** by [runcat-dev](https://github.com/runcat-dev) — the Windows taskbar edition.

Zoomies is an independent macOS reimplementation inspired by RunCat, with a native settings experience. The menu-bar sprite is [**oneko.js**](https://github.com/adryd325/oneko.js) by [**adryd**](https://github.com/adryd325) (MIT) — the classic "Neko" cat. Huge thanks to the RunCat and oneko authors for the delightful concept. 🐱

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
