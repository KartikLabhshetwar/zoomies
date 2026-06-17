# Zoomies — Design Spec

**Date:** 2026-06-17
**Status:** Approved (design), pending spec review

## Summary

Zoomies is a tiny macOS menu bar agent app. It shows a silhouette animal that
"runs in place" in the menu bar; the busier the CPU, the faster it runs. Clicking
the icon opens a small menu to switch animals, see live CPU usage, toggle
launch-at-login, and quit. There is no other UI.

Inspiration: the classic "running cat" menu bar animation, generalized to multiple
animals, built clean-room (no third-party sprite assets).

### Goals
- Fun, glanceable: CPU load is felt, not read.
- Dead simple: one icon, one short menu. No bloat.
- Rock solid: must never crash or destabilize macOS.
- Multi-animal: Cat, Dog, Rabbit, Horse — switchable from the menu.

### Non-goals (v1, YAGNI)
- No Settings/About window.
- No auto-update (Sparkle).
- No code-signing / notarization pipeline.
- No per-core graphs, no network/GPU/RAM stats.
- No configurable sensitivity (fixed, sensible mapping).

## User Experience

- App launches as a background agent (`LSUIElement`) — **no dock icon**, no main
  window. Only a menu bar item appears.
- The menu bar item is a monochrome silhouette animal (template image, so it is
  white on dark menu bars and black on light ones, matching the system look).
- The animal cycles through a run-cycle animation. Animation speed scales with
  system CPU load: a lazy trot when idle, full "zoomies" under heavy load.
- Left- or right-clicking the item opens the menu:

  ```
  CPU: 23%
  ─────────────
  Animal ▸  ✓ Cat
            Dog
            Rabbit
            Horse
  ─────────────
  ✓ Launch at Login
  Quit Zoomies
  ```

- The selected animal and the launch-at-login preference persist across launches.

## Architecture

AppKit, using `NSStatusItem`. AppKit is chosen over SwiftUI `MenuBarExtra` because
rapidly swapping the menu bar image every animation frame is precisely what
`NSStatusItem.button.image` is designed for and is proven reliable; `MenuBarExtra`
has historically had image-refresh quirks for frame-by-frame animation.

The app is an agent app (`LSUIElement = YES`). Single process, no windows.

### Components

Each component has one clear responsibility and a narrow interface.

#### `CPUMonitor`
- **Does:** Samples aggregate system CPU load and publishes a normalized value in
  `0.0...1.0`.
- **How:** Uses the public mach API `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`
  to read cumulative per-core tick counts (user/system/nice/idle). On each sample,
  it diffs against the previous tick snapshot to compute the fraction of non-idle
  time across all cores. Samples on a `Timer` (~every 2.0s).
- **Interface:** exposes `var load: Double` (latest 0–1 value) and a callback /
  closure `onUpdate: (Double) -> Void` fired after each sample. Also exposes a
  `percentString` ("23%") for the menu label.
- **Depends on:** Darwin/mach (`host_processor_info`, `mach_host_self`,
  `vm_deallocate`). Nothing else.
- **Failure handling:** if the mach call returns non-`KERN_SUCCESS`, it keeps the
  last good value (or 0 on first failure) and logs once; never traps/crashes.

#### `SpriteAnimator`
- **Does:** Drives the menu bar image. Holds the active animal's ordered frame
  array and advances the current frame on a timer, setting
  `statusItem.button.image`.
- **How:** A `Timer` whose interval is derived from the latest CPU load via a
  mapping function (see "Load → speed mapping"). On each tick it advances the frame
  index (wrapping) and assigns the cached `NSImage` to the button.
- **Interface:** `setAnimal(_ animal: Animal)`, `setLoad(_ load: Double)`,
  `start()`, `stop()`.
- **Depends on:** `AnimalLibrary` (for frames), the `NSStatusItem.button`.
- **Failure handling:** if an animal has no frames (should never happen — covered
  by a test), it shows a static fallback symbol and does not animate.

#### `AnimalLibrary` / `Animal`
- **Does:** Enumerates available animals and provides each one's ordered frame
  images.
- **How:** `Animal` is an enum/struct with `id`, display `name`, and the asset
  base name. Frames are loaded from `Assets.xcassets` as template `NSImage`s named
  `<animal>_0 ... <animal>_N`, decoded once and cached.
- **Interface:** `static let all: [Animal]`, `frames(for:) -> [NSImage]`.
- **Data-driven:** adding an animal = add frames to the catalog + one entry here.
  No other code changes.

#### `MenuController`
- **Does:** Builds and owns the `NSMenu`; handles menu actions; persists prefs.
- **How:** Builds the CPU label item (updated live from `CPUMonitor.onUpdate`), the
  Animal submenu (checkmark on the active animal), the Launch-at-Login toggle, and
  Quit. Launch-at-login uses `SMAppService.mainApp` (register/unregister).
  Selected animal id and the toggle persist in `UserDefaults`.
- **Interface:** `buildMenu() -> NSMenu`, action selectors for animal selection,
  toggle, and quit.
- **Depends on:** `AnimalLibrary`, `SpriteAnimator`, `CPUMonitor`,
  `ServiceManagement`.

#### `AppDelegate`
- **Does:** Wires everything together at launch. Creates the `NSStatusItem`,
  instantiates `CPUMonitor`, `SpriteAnimator`, `MenuController`. Restores the saved
  animal. Starts monitoring + animation. Cleans up (invalidate timers) on quit.

#### `SpriteGenerator` (build-time tool — NOT shipped in the app)
- **Does:** Renders the silhouette run-cycle PNG frames for each animal into the
  asset catalog.
- **How:** A small standalone script (Swift + Core Graphics, run from the command
  line) draws each animal as a clean filled black silhouette on a transparent
  background — parametric body, head, legs, and tail whose positions are
  interpolated across 5–6 frames to produce a smooth run cycle. Exports PNGs at
  @1x (18pt) and @2x (36pt) and writes the `Assets.xcassets` imageset folders +
  `Contents.json` with `template-rendering-intent = template`.
- **Output is committed**, so the app builds without re-running the generator. The
  generator lives in the repo (e.g. `Tools/SpriteGenerator/`) for future tweaks.
- **Quality plan:** get the **Cat** looking right first (it matches the reference
  image), then reuse the same pipeline with different proportions for dog, rabbit,
  and horse.

### Data flow

```
            ┌──────────────┐  load 0–1   ┌────────────────┐  NSImage   ┌───────────────┐
 Timer ───▶ │  CPUMonitor  │ ──────────▶ │ SpriteAnimator │ ─────────▶ │ NSStatusItem  │
 (2s)       └──────┬───────┘             └────────────────┘  per frame │   .button     │
                   │ percentString                                     └───────────────┘
                   ▼
            ┌──────────────┐  selected animal / toggle (UserDefaults)
            │MenuController│ ──────────▶ SpriteAnimator.setAnimal(...)
            └──────────────┘
```

### Load → speed mapping

- Animation frame interval is a function of CPU load `L ∈ [0,1]`.
- Target frames-per-second: `fps = idleFPS + (maxFPS - idleFPS) * L`, with
  `idleFPS = 3`, `maxFPS = 18` (tunable constants). Frame interval = `1 / fps`.
- `L` is clamped to `[0,1]`. The mapping is pure and unit-tested at the boundaries.

## Reliability & Safety

The "must not crash macOS / no bloat" requirement is met by construction:

- **Agent app** (`LSUIElement`): no dock icon, minimal memory, no windows.
- **Public APIs only:** reads aggregate CPU stats via `host_processor_info`. No
  private APIs, no kernel extensions, no entitlements that can affect OS stability.
- **Defensive sampling:** every mach call's return code is checked; failures keep
  the last good value and never trap. Allocated processor-info arrays are released
  with `vm_deallocate`.
- **Cheap rendering:** frames are decoded once and cached as `NSImage`s; per-frame
  work is a single image assignment. At max 18 fps this is negligible CPU.
- **Lifecycle hygiene:** timers are invalidated on `applicationWillTerminate`;
  closures use `[weak self]` to avoid retain cycles.
- **Sandbox-friendly:** no file/network access required at runtime beyond
  `UserDefaults` and `SMAppService`.

## Testing

Unit tests (XCTest / Swift Testing):
- `CPUMonitor` tick-delta math: feed two synthetic tick snapshots → assert the
  computed busy fraction (including the all-idle and fully-busy edge cases).
- Load→fps mapping: `0.0 → idleFPS`, `1.0 → maxFPS`, out-of-range inputs clamp.
- `AnimalLibrary`: every `Animal` in `.all` returns a non-empty frame array, and
  all frames are valid (non-nil) images.

Manual verification:
- Launch the app → silhouette animal animates in the menu bar.
- Spike CPU (`yes > /dev/null` on several cores) → animation visibly speeds up;
  stop it → slows back down.
- Open menu → switch animals → icon changes and choice persists after relaunch.
- Toggle Launch at Login → verify `SMAppService` status; relaunch persists.
- Quit → menu bar item disappears, process exits cleanly.

## Build & Tooling

- Project structure created per the **macos-build** skill (produces a runnable
  `Zoomies.app`).
- General menu bar / agent app conventions per the **macos-patterns** skill.
- Deployment target: current toolchain (Xcode 26.5, Swift 6.3.2, macOS 26).

## File / Module Layout (proposed)

```
Zoomies/
  Sources/Zoomies/
    AppDelegate.swift
    CPUMonitor.swift
    SpriteAnimator.swift
    AnimalLibrary.swift
    MenuController.swift
    Assets.xcassets/            # generated template PNG frames (committed)
    Info.plist                  # LSUIElement = YES
  Tools/SpriteGenerator/        # build-time silhouette frame generator (not shipped)
  Tests/ZoomiesTests/
    CPUMonitorTests.swift
    MappingTests.swift
    AnimalLibraryTests.swift
  docs/superpowers/specs/2026-06-17-zoomies-design.md
```

(Exact project format — SwiftPM vs `.xcodeproj` — is decided during planning per
the macos-build skill; the component design above is independent of that choice.)

## Open Questions

None blocking. Sprite art is generated clean-room (approved). If a generated
animal looks off, frames can be swapped without code changes because the system is
data-driven.
