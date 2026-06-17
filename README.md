# Zoomies

A tiny macOS **menu bar app** that puts a little animal in your menu bar and turns your CPU usage into a live animation — **the busier your Mac, the faster it runs.** 🐾

Click it to switch animals, open **Settings**, hit **Surprise Me**, or quit. Simple, lightweight, and fun.

```text
 ~=^..^=     <- idle: a lazy trot
 =^o.o^=>>>  <- busy: full zoomies!
```

## Features

- **Live load animation** — animation speed scales with system load (~3 fps idle -> ~18 fps under heavy load).
- **5 animals** — Cat, plus Dog, Rabbit, Horse, and Parrot 🦜. Switch from the menu or the Settings gallery; **Surprise Me** picks one at random. Your choice is remembered.
- **Settings window** — a native macOS settings window: visual animal gallery, a **speed-sensitivity** slider, a **CPU / Memory / either** source toggle, an optional **menu-bar percentage** readout, and launch-at-login.
- **Featherweight & safe** — runs as a background agent (no Dock icon), reads only aggregate CPU/memory stats via public macOS APIs. No private APIs, no kernel extensions.
- **Respectful** — adapts to light/dark menu bars automatically, and honors the system **Reduce Motion** setting.

## Requirements

- macOS 14 or later
- [Xcode](https://developer.apple.com/xcode/) 15+ (uses the bundled Swift toolchain)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Quick start

```sh
make build   # generate the Xcode project + build the app
make run      # build and launch it — look at the top-right of your menu bar
```

Then look at your menu bar (top-right) for the running animal. To see it sprint, give your CPU something to chew on:

```sh
yes > /dev/null &   # repeat a few times to load several cores
# ...watch the animal speed up...
killall yes          # stop the load
```

## Commands

Run `make` (or `make help`) anytime to list these:

| Command | What it does |
| --- | --- |
| `make build` | Build the app (Debug, unsigned) |
| `make run` | Build, then launch Zoomies |
| `make test` | Run the unit test suite (18 tests) |
| `make stop` | Quit the running app |
| `make sprites` | Regenerate the animal sprite frames |
| `make install` | Copy `Zoomies.app` into `/Applications` and launch it |
| `make project` | Regenerate `Zoomies.xcodeproj` from `project.yml` |
| `make clean` | Remove `build/` and the generated project |

The built app lands at `build/Build/Products/Debug/Zoomies.app`.

## How it works

- **`CPUMonitor`** samples aggregate CPU load every ~2s via the public mach `host_statistics` API and publishes a normalized `0.0–1.0` value.
- **`SpeedMapping`** turns that load into a target frame rate (idle 3 fps -> max 18 fps).
- **`SpriteAnimator`** cycles the active animal's template-PNG frames on the menu bar item, re-pacing only when the speed actually changes (so it stays smooth).
- **`MenuController`** builds the click menu (CPU %, animal picker, launch-at-login via `SMAppService`, quit) and persists your choice.

Pure logic lives in a `ZoomiesCore` library and is unit-tested; the AppKit `NSStatusItem` wiring lives in the app target.

## Project structure

```text
Sources/ZoomiesCore/      # pure, tested logic: CPUMonitor, SpeedMapping, AnimalLibrary
Sources/Zoomies/          # AppKit app: AppDelegate, SpriteAnimator, FrameLoader, MenuController
  Assets.xcassets/ 
Tools/SpriteGenerator/    # build-time Core Graphics tool that draws the sprites
Tests/ZoomiesCoreTests/   # unit tests
project.yml               # XcodeGen project definition
Makefile                  # build / run / test helpers
docs/superpowers/         # design spec & implementation plan
```

## Customizing

- **Animal art:** edit `Tools/SpriteGenerator/main.swift` (per-animal proportions, gait, ears, tail), then `make sprites && make run`.
- **Speed feel:** tweak `idleFPS` / `maxFPS` in `Sources/ZoomiesCore/SpeedMapping.swift`.

## Notes

- This is an **unsigned local build**. macOS may show *"requires approval"* for **Launch at Login** (a rule for unsigned apps) — it's handled gracefully and works fully once the app is signed and installed to `/Applications`. On first open you may need to right-click -> **Open** to get past Gatekeeper.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
