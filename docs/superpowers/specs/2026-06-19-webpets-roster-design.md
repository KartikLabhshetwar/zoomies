# Replace all pets with the webpets roster

- **Date:** 2026-06-19
- **Status:** Approved (design)
- **Source art:** https://github.com/sankalpaacharya/webpets (`public/media/<pet>/`)

## Context

Zoomies is a macOS **menu-bar pet**: a status-item icon (~26 pt tall) that reacts to
system load — calm Mac → idle, busy Mac → running — and faces the direction the mouse
last moved. Today it ships 4 pets (oneko cat, dog, fox, chocobo) as 32 px-grid PNG
sprite sheets in the Neko Archive / oneko.js layouts. `FrameLoader` hand-authors an
idle script (sit/alert/scratch/tired/sleep) and a 2-frame run cycle, and `GaitAnimator`
adds a procedural vertical "bob" to make two frames read as a gait.

We are replacing all of that with the webpets roster.

webpets is a Next.js project whose art lives as **animated GIFs** (pixel art, 8 fps) under
`public/media/<pet>/<color>_<state>_8fps.gif`, with per-pet `icon_<color>.png` thumbnails
and `license.txt` attribution. States include idle / walk / walk_fast / run / swipe /
with_ball / lie. All GIFs have an alpha channel (verified), so they drop straight into a
menu-bar icon.

This is a fundamental format change (GIF cycles, not 32 px Neko sheets) and a much larger
roster, so the loader, animation engine, data model, settings UI, and assets all change.

## Goals

- Remove the 4 existing pets and all their assets/code paths.
- Bring in **all 22 webpets creatures**, each with a **color picker** for its variants
  (~57 color variants total).
- Map system load to **idle → walk → walk_fast → run** using the real GIF cycles.
- Motion stays smooth and polished: no jumps when switching states, no flicker at load
  boundaries, responsive to the Speed slider, reduce-motion friendly.
- Preserve webpets attribution (license files + credits).

## Non-goals

- The `swipe`, `with_ball`, and `lie` states (no natural mapping to system load — YAGNI).
- Per-pet remembered colors (one selected color, validated against the current pet).
- Changing the app's nature: it remains a menu-bar pet driven by CPU/GPU/memory load.
- Cursor-chasing / on-screen roaming (existing `ChaseModel` is unaffected by this work).

## Confirmed decisions

1. **Scope:** all 22 creatures, each selectable with a per-pet color sub-picker.
2. **Motion:** load maps to idle → walk → walk_fast → run (use all real cycles).
3. **Strategy:** GIF-native — bundle the GIFs, decode frames + per-frame durations at
   runtime (`CGImageSource`). Rejected alternatives: pre-baked sprite sheets (lossy, the
   32 px-grid loader doesn't fit variable-size frames) and pre-extracted PNG sequences
   (thousands of files for no gain; decode happens once per pet-switch, not per frame).

## Roster

22 creatures (color counts in parens): chicken (2), clippy (4), cockatiel (2), crab (1),
deno (1), dog (5), fox (2), horse (11), mod (1), monkey (1), morph (1), panda (2), rat (3),
rocky (1), rubber-duck (1), skeleton (10), snail (1), snake (1), totoro (1), turtle (2),
vampire (3), zappy (1) — **57 variants**.

`monkey`, `skeleton`, and `totoro` have no `walk_fast`; their "fast" bucket falls back to
`run`. (`walkers_wide` in the source is a composite demo, not a pet — excluded.)

## Design

### Data model (`Sources/ZoomiesCore/Animal.swift`)

```swift
public struct PetColor: Equatable, Identifiable {
    public let id: String          // "akita", "paint_beige"
    public let displayName: String // "Akita", "Paint Beige"  (humanized)
}

public struct Animal: Equatable, Identifiable {
    public let id: String          // "dog"
    public let name: String        // "Dog"
    public let colors: [PetColor]  // ≥1, ordered
    public let defaultColorID: String
    public let hasWalkFast: Bool
    public func color(withID:) -> PetColor   // falls back to default
}
```

- `AnimalLibrary.all` lists the 22 creatures, kept in sync with bundled assets.
- A small humanizer turns color ids into display names (`socks_black` → "Socks Black").

### Settings (`Sources/Zoomies/AppSettings.swift`)

- Add persisted `colorID`. On launch and on pet-switch, validate against the current
  animal's palette; fall back to `defaultColorID` when absent.
- `AppDelegate` observes `$colorID` (alongside `$animalID`) and re-applies the pet.

### Asset pipeline

- Bundle, per variant, four GIFs (idle / walk / walk_fast / run) + `icon_<color>.png`,
  under a folder reference so directory structure is preserved in the app bundle:
  `Sources/Zoomies/Pets/<pet>/<color>_<state>.gif`, `Sources/Zoomies/Pets/<pet>/icon_<color>.png`,
  `Sources/Zoomies/Pets/<pet>/license.txt`. (~220 GIFs + ~57 icons; pixel-art GIFs are
  a few KB each.) `project.yml` adds `Pets` as a `type: folder` reference, mirroring how
  `Sprites` is bundled today.
- A small repeatable importer (`Tools/ImportPets`, replacing `Tools/SpriteGenerator`)
  copies the needed files from a local webpets checkout so the asset set is reproducible.

### Frame loader (`Sources/Zoomies/FrameLoader.swift`, rewritten)

- `loadStates(_ animal:, color:) -> [PetState: [Frame]]` where
  `Frame = (image: NSImage, duration: Double)`. For each state, decode the GIF with
  `CGImageSource`, reading `kCGImagePropertyGIFDelayTime` (fallback 1/8 s).
- **Shared registration:** compute one tight alpha bounding box and one scale across the
  frames of **all** states of the variant, so switching idle↔walk↔run never jumps or
  resizes. Render every frame to a common `iconHeight` canvas at Retina; pick downscale
  interpolation suited to the larger pixel art (up to ~140 px → ~26 pt).
- Pre-mirror frames for the opposite facing. Determine the source's native facing from a
  frame; mirror for the other side (add a per-pet flip flag only if some art faces the
  other way).
- `loadThumbnail(_ animal:, color:)` returns the `icon_<color>.png` for the picker.

### Animation engine (`Sources/ZoomiesCore/PetAnimator.swift`, replaces `GaitAnimator`)

Pure, AppKit-free, unit-testable (caller owns the clock, passes `dt`).

- Maps the eased load signal to a `PetState` (idle / walk / walk_fast / run) using
  **bucket thresholds with hysteresis** (separate up/down thresholds) so it doesn't
  flicker at boundaries.
- Advances a within-state frame cursor by accumulated time vs. the frame's native
  duration; playback rate scales subtly with load × Speed so the pet visibly winds up.
- No procedural bob (GIFs already carry vertical motion).
- `SpeedMapping` gains the state thresholds; its load→fps curve now drives within-state
  playback rate instead of a 2-frame flip. (Update the stale "two frames" comments.)

### PetController (`Sources/Zoomies/PetController.swift`)

- Drives `PetAnimator` from the existing `CADisplayLink`; selects the current state's
  frame for the current facing and assigns the button image only when it changes.
- Keep mouse-direction facing and reduce-motion (hold idle frame 0).
- `setAnimal` becomes `setPet(_ animal:, color:)`, loading that variant's states.

### Settings UI (`Sources/Zoomies/BehaviorPane.swift`)

- The animal grid becomes **scrollable** (22 pets), thumbnails from `icon_<color>.png`.
- Add a **color picker** (swatch row using `icon_<color>.png`) for the selected pet,
  shown only when it has more than one color.

### Removals

- `resources/{dog,fox,oneko,chocobo}/`, `Sources/Zoomies/Sprites/*.png`.
- Neko/oneko scripts + sprite-sheet code paths in `FrameLoader`.
- `Tools/SpriteGenerator` (replaced by `Tools/ImportPets`).
- `GaitAnimator` (replaced by `PetAnimator`).

### Tests & docs

- Replace `GaitAnimatorTests` with `PetAnimatorTests` (state selection, hysteresis,
  frame timing). Update `AnimalLibraryTests` (roster/colors/fallback) and
  `SpeedMappingTests` (thresholds). Keep CPU/GPU/Memory/Chase tests as-is.
- Update README (new roster + webpets credit) and the About pane credits.

## Risks / things to verify during implementation

- **Source facing direction** of the GIFs (mirror correctly).
- **Downscale quality** for the larger pixel art at menu-bar size (interpolation choice).
- **Bundle wiring**: confirm the folder-reference bundles `Pets/**` and that
  `Bundle.main.url(forResource:withExtension:subdirectory:)` resolves nested paths.
- **Status-item width** varies with each pet's aspect ratio (acceptable; verify layout
  vs. the percentage label).

## Acceptance criteria

- All 22 creatures appear in Settings; selecting one (and a color, where applicable)
  swaps the menu-bar pet live.
- The pet idles when the Mac is calm and escalates idle → walk → walk_fast → run as load
  rises, with no visible jump on state change and no flicker at boundaries.
- Facing flips with mouse direction; reduce-motion holds a calm frame.
- No references to the old 4 pets remain; build and `ZoomiesCoreTests` pass.
- webpets attribution is preserved in-repo and credited in README + About.
