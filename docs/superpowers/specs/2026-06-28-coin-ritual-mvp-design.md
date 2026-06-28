# 落 — Coin Ritual MVP design

Date: 2026-06-28
Status: approved (brainstorming) → ready for implementation plan

## Context

The app currently boots into the **Coin Harness** (ADR-0007 Phase 1) — a coin
scene plus ~18 physics-tuning sliders. The coin physics is solid now (stable
rest, tumbling throw, velocity-free Settle) and the reusable core was graduated
into `PhysicsScene` (ADR-0005). Charlie wants to hide the tuning sliders and turn
this into a **usable MVP**: a clean, polished single screen you can actually cast
with.

Per ADR-0001/0002 the strategic lead Ritual is I Ching 六爻, but that needs
multi-coin physics, six-throw accumulation, and 64-hexagram lookup — multi-session
work. The **Coin Ritual** is the simpler ritual, is fully supported by what's
already built, and can be a genuinely usable MVP today. So the MVP is the Coin
Ritual; it also stands up the first real `RitualView + ViewModel` per ADR-0005,
which the I Ching ritual (Phase 3) will mirror.

## Goals

- Replace the Harness as the app's entry surface with a polished Coin Ritual.
- One-tap (or shake) cast → coin tumbles → calm 阳/阴 reveal.
- Keep the physics-tuning sliders reachable (hidden), not deleted.
- Establish the `CoinRitualView` + `CoinRitualViewModel` pattern from ADR-0005.

## Non-goals (explicitly out of MVP)

- No history / persistence — a single coin flip is stateless (ADR-0003).
- No question text input, no save-this-cast, no Cast Log (that's I Ching infra).
- No I Ching ritual, no onboarding, no settings screen.
- No bundled custom font yet (Noto Serif SC is a later polish; use system fonts).
- No changes to `PhysicsScene` / `PhysicsConfig` physics behavior.

## Architecture (ADR-0005: concrete View + ViewModel that *use* PhysicsScene)

- **`CoinRitualViewModel`** (`@MainActor`, `ObservableObject`)
  - Owns one `PhysicsScene(config: .v1, onSettle:, onStateChange:)`.
  - Publishes a single `castState` (see state machine) the View renders.
  - Maps the settled `ThrowResult.faceUp` → `Yinyang` (heads → 阳, tails → 阴).
  - `cast()` → `scene.performThrow()`. Re-cast from a result loops back.
  - Plays the existing haptic thunk on settle (`HapticsService`); optionally
    starts `MotionService` so a device shake also calls `cast()`.
- **`CoinRitualView`** — the new app root; renders the scene + overlay + reveal.
- **`Yinyang`** — tiny enum `{ yang, yin }` with display glyph (阳/阴) and the
  framing word (是/否). Derived from `CoinFace`. Defined in
  `CoinRitualViewModel.swift` (ritual semantics belong to the VM layer, so
  `PhysicsScene`/`ThrowResult` stay free of them).
- **`Theme`** — a small struct of Dusk Desk tokens (colors from DESIGN.md:
  `neutral #14110D`, ink `primary #ECE3D2`, cinnabar `tertiary #DC6A4B`,
  `surface-raised #211B14`) + font helpers, so the View doesn't hardcode hex.
- `PhysicsScene`, `PhysicsConfig`, `ThrowResult`, `HapticsService`,
  `MotionService` unchanged. `HarnessView` + `PhysicsParams` kept, repurposed as
  the hidden debug sheet.

## State machine (`castState`)

```
.idle            → ready; quiet hint visible; button "掷" enabled
.casting         → coin thrown; button disabled; hint dims
.result(Yinyang) → settled; 阳/阴 + 是/否 revealed; button "再掷" enabled → cast() → .casting
```

Driven by `PhysicsScene`'s `SettleState` via `onStateChange`/`onSettle`:
- `cast()` → `performThrow()` → `.casting`.
- `onSettle(ThrowResult)` → map face → `.result(yinyang)`.
- (`throwing`/`settling` keep `.casting`; we only flip to `.result` on settle.)

## Screen layout (single full-bleed, Dusk Desk)

```
┌─────────────────────────┐
│                         │
│      心中默念所问         │  quiet hint (top), dims after first cast
│                         │
│      ╭───────────╮      │
│      │  the desk  │      │  PhysicsScene fills the screen:
│      │   ◗ coin   │      │  warm near-black felt, brass coin,
│      │   ·shadow· │      │  soft contact shadow
│      ╰───────────╯      │
│                         │
│           阳            │  result reveal: large 阳/阴 fades in after
│           是            │  Settle, with the one-word read beneath
│                         │
│        (  掷  )         │  single cinnabar button; "掷" → "再掷"
└─────────────────────────┘
```

- The `PhysicsScene` SceneView fills the screen (desk is the backdrop), UI
  overlaid. One accent only (the cinnabar button), per DESIGN.md restraint.
- Result glyph reveals calmly (fade/opacity) on entering `.result`; clears on the
  next `cast()`.

## Hidden tuning access

- A long-press (~1.5s) on the desk area presents the existing `HarnessView`
  (sliders) as a modal `.sheet`. Nothing is deleted — tuning stays reachable,
  just out of the normal flow. (Harness still drives the same `PhysicsScene` path
  via `PhysicsParams.makeConfig()`.)

## Files

- New: `Luo/CoinRitualView.swift`, `Luo/CoinRitualViewModel.swift` (contains
  `Yinyang`), `Luo/Theme.swift`.
- Modify: `Luo/LuoApp.swift` (root `WindowGroup { CoinRitualView() }`).
- Keep: `Luo/HarnessView.swift`, `Luo/PhysicsParams.swift` (debug sheet);
  `PhysicsScene.swift`, `PhysicsConfig.swift`, `ThrowResult.swift`,
  `HapticsService.swift`, `MotionService.swift` unchanged.
- `project.yml` globs `Luo/`, so new files need only `xcodegen generate`.

## Verification

1. `xcodebuild build … -destination 'generic/platform=iOS Simulator' …` → SUCCEEDED.
2. Launch on the booted sim: app opens to `CoinRitualView` (not the slider list);
   coin seated on the felt, hint visible, "掷" button present, `castState == .idle`.
3. Headless cast probe (NSLog + `simctl spawn log show`, per the project's
   debug-workflow memory): drive `cast()` once → state goes `.casting` → settles →
   `.result(阳|阴)` with the face matching the coin's up-vector; reveal copy correct.
4. Long-press the desk → Harness sheet appears with the sliders; dismiss → back to
   the ritual. Sliders still tune the live scene.
5. Re-cast from a result loops correctly (`.result` → `.casting` → `.result`).
6. Strip any temporary probe; `grep -n "LUO_\|NSLog\|probe"` clean before done.

## Open questions / easy tweaks (not blockers)

- Result framing copy (是/否 vs 吉/凶 vs bare 阳/阴) — trivially adjustable.
- Whether to auto-start `MotionService` (shake) on appear, or behind a toggle —
  default: start on appear so device shake works; no-op in simulator.
