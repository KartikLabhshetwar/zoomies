<div align="center">

# 🐾 Zoomies

**A tiny macOS menu bar app that turns your system load into a sprinting animal.**

The busier your Mac, the faster it runs.

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://github.com/KartikLabhshetwar/zoomies/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)](https://swift.org)
(https://github.com/KartikLabhshetwar/zoomies/releases/latest)
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
3. Launch it — a pixel-art animal appears in your menu bar instantly

> **Tip:** If macOS says the app can't be opened, go to **System Settings → Privacy & Security** and click **Open Anyway**.

---

## What it does

A pixel-art animal roams your full menu bar and runs faster the harder your Mac is working. It reacts in real time to CPU, GPU, or RAM load — your choice. Click the indicator to see a live readout of all three, open Settings, or quit.

### Animals

| Cat | Dog | Fox | Chocobo |
|-----|-----|-----|---------|
| oneko | dog | fox | chocobo |

### Features

- **Menu bar native** — the animal lives right inside the macOS status item; the system always places it in the notch-safe zone
- **Direction tracking** — the sprite faces the direction your cursor is moving: drag left and it runs left, drag right and it turns around
- **Always running** — no stopping or pausing; only the speed changes with system load
- **Load-reactive speed** — slow trot at idle, steady run at normal load, all-out sprint when your Mac is busy (2–9 fps leg cycle, eased so light load stays calm)
- **Retina-crisp pixel art** — nearest-neighbour scaling at 26 pt × backing scale factor; every pixel stays sharp
- **Three monitors** — CPU (via `host_cpu_load_info`), GPU (via IOAccelerator IOKit), and RAM (via `vm_statistics64`), each accurate and independent
- **Per-source display** — menu bar shows `CPU 42%` / `GPU 6%` / `RAM 55%` / `MAX 55%` depending on which source you selected
- **Live menu** — click to see CPU, GPU, and RAM with color-coded bar graphs
- **4 animals** — Cat, Dog, Fox, Chocobo; pick any from the Settings grid and it switches instantly
- **Speed slider** — scales the whole speed curve (slow Sunday trot at one end, absolute chaos at the other)
- **Featherweight** — background accessory process, no Dock icon, no polling waste
- **Reduce Motion** — respects the system accessibility setting (holds on idle frame)
- **Launch at Login** — one toggle in Settings

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

`make run` generates the Xcode project, builds the app, and launches it.

To stress-test the animation (watch it sprint):

```sh
yes > /dev/null &   # peg a CPU core
# when done:
killall yes
```

### All commands

```sh
make            # list all commands
make build      # build (Debug, unsigned) → build/Build/Products/Debug/Zoomies.app
make run        # build + launch
make test       # run the unit test suite (46 tests)
make stop       # quit the running app
make install    # copy to /Applications and launch
make project    # regenerate Zoomies.xcodeproj from project.yml
make clean      # remove build/ and the generated project
```

---

## How it works

```
CPU/GPU/RAM load  →  Monitors  →  PetController  →  NSStatusItem.button.image
                                       ↑
                   MouseDirectionMonitor (cursor tracking)
```

- **`CPUMonitor`** — samples aggregate CPU load every 1 s via `host_cpu_load_info` (tick-diff, same method as Activity Monitor)
- **`GPUMonitor`** — samples GPU utilization every 500 ms via IOAccelerator IOKit; uses a 5-sample peak window to avoid 0 % flicker during the ~200 ms kernel-update interval
- **`MemorySampler`** — reads active + wired + compressor pages via `vm_statistics64`
- **`SpeedMapping`** — maps 0–1 load to a leg cadence (3–18 fps); also scales by the user's speed multiplier
- **`PetController`** — drives a variable-rate `Timer` that alternates two run frames; restarts only when the fps bucket changes (avoids stutter); owns the `MouseDirectionMonitor` and swaps left/right frame sets on direction change
- **`MouseDirectionMonitor`** — global `NSEvent` monitor for `.mouseMoved`; feeds horizontal deltas into `DirectionTracker` (debounced 1.5 pt threshold) and calls back when facing flips
- **`FrameLoader`** — reads packed sprite sheets from `Sprites/<id>_sheet.png`; crops the two west-run cells, scales to 26 pt × backingScaleFactor with nearest-neighbour interpolation, mirrors for the east-run set, and pads 4 pt trailing space so the pet doesn't crowd the label
- **`MenuController`** — click menu with live CPU / GPU / RAM bar graphs

Pure logic lives in `ZoomiesCore` (unit-tested, no AppKit). AppKit wiring lives in the `Zoomies` target.

---

## Project structure

```
zoomies/
├── Sources/
│   ├── ZoomiesCore/           # Pure logic: monitors, SpeedMapping, Animal, DirectionTracker
│   └── Zoomies/               # AppKit app: AppDelegate, PetController, FrameLoader, settings UI
│       └── Sprites/           # 6 packed RGBA PNG sprite sheets (<id>_sheet.png)
├── Tests/
│   └── ZoomiesCoreTests/      # Unit tests
├── Tools/
│   └── SpriteGenerator/       # Strips gridlines/background from source sheets → Sprites/
├── resources/                 # Source sprite sheets (oneko.gif, dog.png, fox.png, …)
├── project.yml                # XcodeGen project definition
├── Makefile                   # Build / run / test helpers
└── scripts/
    └── release.sh             # Build, sign, notarize, and package DMGs
```

---

## Acknowledgments

Zoomies is inspired by **RunCat**. The core idea — a menu-bar critter that animates faster as your CPU heats up — comes from that project and its lineage:

- **[RunCat for macOS](https://github.com/Kyome22/menubar_runcat)** by [Takuto Nakamura (Kyome)](https://github.com/Kyome22) — the original menu-bar running cat.
- **[RunCat365](https://github.com/runcat-dev/RunCat365)** by [runcat-dev](https://github.com/runcat-dev) — the Windows taskbar edition.

The cat sprite is **[oneko.js](https://github.com/adryd325/oneko.js)** by [**adryd**](https://github.com/adryd325) (MIT). Classic animal sprites (Dog, Fox, Chocobo) are from **[The Neko Archive](https://bomvel.neocities.org/neko/)** — considered public domain by the archive. Huge thanks to everyone who kept pixel-art creatures running across screens. 🐾

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
