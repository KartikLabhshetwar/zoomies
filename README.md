<div align="center">

# 🐾 Zoomies

**A tiny macOS menu bar app that turns your system load into a living pixel pet.**

Calm Mac, the pet rests. Busy Mac, it breaks into a run.

[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://github.com/KartikLabhshetwar/zoomies/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

Inspired by [**RunCat**](https://github.com/runcat-dev/RunCat365) — the running cat that speeds up with your CPU. 🐱

</div>

---

## What it does

A pixel-art pet lives in your menu bar and reacts in real time to how hard your Mac is working — CPU, GPU, or RAM, your choice. When the Mac is idle the pet idles; as load climbs it shifts up through **walk → fast walk → run**. Click the indicator to see a live readout of all three metrics, open Settings, or quit.

### Pets

9 leg-walking creatures. Seven from the [webpets](https://github.com/sankalpaacharya/webpets) sprite set — dog, fox, horse, panda, skeleton, deno, and vampire — most with several color variants (the dog has five; the skeleton ten; the horse eleven), pickable from Settings. Plus the two classic Zoomies 1.0 pixel pets: the **Cat** (oneko) and the **Dalmatian** (Neko Archive).

### Features

- **Menu bar native** — the pet lives right inside the macOS status item; the system always keeps it in the notch-safe zone
- **Load-reactive gait** — idle when calm, then **walk → fast walk → run** as the Mac gets busier, using each creature's real animation cycles; thresholds have hysteresis so the pet doesn't flicker between gaits at a boundary
- **Real frame animation** — every gait is the source GIF's own multi-frame cycle, played at its native cadence and sped up smoothly with load and your Speed setting (no two-frame fakery)
- **Direction tracking** — the sprite faces the way your cursor is moving: move left and it runs left, move right and it turns around
- **Baseline-locked frames** — all of a pet's gaits are registered to one shared scale and baseline, so switching idle → walk → run never makes the pet jump, resize, or wobble
- **9 creatures, dozens of colors** — pick any from the scrollable Settings grid, then choose a coat color; it switches instantly
- **Three monitors** — CPU (via `host_cpu_load_info`), GPU (via IOAccelerator IOKit), and RAM (via `vm_statistics64`), each accurate and independent
- **Per-source display** — menu bar shows `CPU 42%` / `GPU 6%` / `RAM 55%` / `MAX 55%` depending on which source you selected
- **Live menu** — click to see CPU, GPU, and RAM with color-coded bar graphs
- **Speed slider** — scales the whole pace curve (slow Sunday stroll at one end, absolute chaos at the other)
- **Featherweight** — background accessory process, no Dock icon, display-synced animation capped at 30 Hz to stay battery-light
- **Reduce Motion** — respects the system accessibility setting (holds a calm idle frame)
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

To stress-test the animation (watch it run):

```sh
yes > /dev/null &   # peg a CPU core
# when done:
killall yes
```

### All commands

```sh
make             # list all commands
make build       # build (Debug, unsigned) → build/Build/Products/Debug/Zoomies.app
make run         # build + launch
make test        # run the unit test suite
make stop        # quit the running app
make install     # copy to /Applications and launch
make project     # regenerate Zoomies.xcodeproj from project.yml
make import-pets # re-import pet GIFs from the webpets repo into Sources/Zoomies/Pets
make clean       # remove build/ and the generated project
```

---

## How it works

```
CPU/GPU/RAM load → Monitors → PetController.setLoad
                                          │
  Timer (30 Hz, .common mode) → PetAnimator → NSStatusItem.button.image
                                          ↑
                        MouseDirectionMonitor (cursor facing)
```

- **`CPUMonitor`** — samples aggregate CPU load every 2 s via `host_cpu_load_info` (tick-diff, same method as Activity Monitor); a low-frequency, coalesced wake-up keeps it light on older Macs
- **`GPUMonitor`** — samples GPU utilization every 2 s via IOAccelerator IOKit on a background queue; a light exponential moving average smooths the reading
- **`MemorySampler`** — reads active + wired + compressor pages via `vm_statistics64`
- **`SpeedMapping`** — maps 0–1 load through a cubic ease-in curve, so light/medium load stays calm and the speed-up concentrates near full load
- **`PetAnimator`** — pure, AppKit-free engine: maps eased load to one of four gait states (idle/walk/walk_fast/run) with up/down hysteresis, and advances the current cycle's frames by their native GIF durations, sped up by load × the Speed setting. Fully unit-tested.
- **`PetController`** — runs one main-thread `Timer` (~30 Hz, `.common` run-loop mode) that ticks the `PetAnimator`; load and speed only move its inputs, so the cycle never resets (no stutter). A `Timer` is used rather than `CADisplayLink` because a status-item button's window is never key/active, so an `NSView`-vended display link never fires for it. Reassigns the button image only when the visible frame actually changes. Owns the `MouseDirectionMonitor` and flips the left/right frame sets on direction change.
- **`MouseDirectionMonitor`** — global `NSEvent` monitor for `.mouseMoved`; feeds horizontal deltas into `DirectionTracker` (debounced 1.5 pt threshold) and calls back when facing flips
- **`FrameLoader`** — builds each gait's frames from either webpets GIFs (`Pets/<pet>/<color>_<state>.gif`, decoded with `CGImageSource` for per-frame durations) or a packed 32 px Neko sprite sheet (the classic Cat/Dalmatian); scales so the tallest pose fits ~20 pt × backingScaleFactor (nothing clips), crops each state to its shared union box and centers it (no wobble, never low), and mirrors to whichever way the cursor moves (webpets art faces right, the Neko sheets face left)
- **`MenuController`** — click menu with live CPU / GPU / RAM bar graphs

Pure logic lives in `ZoomiesCore` (unit-tested, no AppKit) — including the `PetAnimator` and `SpeedMapping` that shape the motion. AppKit wiring lives in the `Zoomies` target.

---

## Project structure

```
zoomies/
├── Sources/
│   ├── ZoomiesCore/           # Pure logic: monitors, SpeedMapping, PetAnimator, Animal, DirectionTracker
│   └── Zoomies/               # AppKit app: AppDelegate, PetController, FrameLoader, settings UI
│       └── Pets/              # Bundled pet GIFs: <pet>/<color>_<state>.gif + icons (folder reference)
├── Tests/
│   └── ZoomiesCoreTests/      # Unit tests
├── Tools/
│   └── ImportPets/            # Copies pet GIFs from a webpets checkout → Sources/Zoomies/Pets
├── project.yml                # XcodeGen project definition
├── Makefile                   # Build / run / test helpers
└── scripts/
    └── release.sh             # Build, sign, notarize, and package DMGs
```

---

## Acknowledgments

Zoomies is inspired by **RunCat** — a menu-bar critter that animates faster as your CPU heats up:

- **[RunCat for macOS](https://github.com/Kyome22/menubar_runcat)** by [Takuto Nakamura (Kyome)](https://github.com/Kyome22) — the original menu-bar running cat.
- **[RunCat365](https://github.com/runcat-dev/RunCat365)** by [runcat-dev](https://github.com/runcat-dev) — the Windows taskbar edition.

Most pets come from the **[webpets](https://github.com/sankalpaacharya/webpets)** project by Sankalpa Acharya, originating from **[vscode-pets](https://github.com/tonybaloney/vscode-pets)**. The classic Cat is **[oneko.js](https://github.com/adryd325/oneko.js)** by [adryd](https://github.com/adryd325) (MIT), and the Dalmatian is a **[Neko Archive](https://bomvel.neocities.org/neko/)** sprite (public domain). Per-creature attribution lives in [`Sources/Zoomies/Pets/CREDITS.txt`](Sources/Zoomies/Pets/CREDITS.txt). Huge thanks to everyone who kept pixel-art creatures running across screens. 🐾

---

## License

Apache License 2.0 — see [LICENSE](LICENSE).
