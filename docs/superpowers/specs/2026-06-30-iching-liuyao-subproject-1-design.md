# 六爻 三钱法 — Sub-project ① : 三钱物理 + 六爻累积 (掷出正确本卦)

**Date:** 2026-06-30
**Ritual:** I Ching 六爻 三钱法 (v1 lead Ritual)
**Status:** Design approved, pending spec review

## Context

Phase 3 (the full I Ching Ritual) is decomposed into three independent sub-projects,
each with its own spec → plan → implementation cycle:

- **① 三钱物理 + 六爻累积 (this spec)** — PhysicsScene extended to 3 coins; 6 Throws
  accumulate into the **Present Hexagram (本卦)**; result screen shows 卦号 + 卦名 +
  6-Yao glyph with 动爻 marked. No corpus, no 变卦, no Cast Log.
- **② 周易文本 + 变卦** — 64 卦辞 + 384 爻辞 corpus; Identifier + Canonical Text
  toggle; render 本卦 ↔ 变卦 side by side. (deferred)
- **③ Cast Log 持久化** — storage + list + detail + delete; retrofit Coin's
  "save this Cast". (deferred)

Order ①→②→③: you cannot read a 卦 you cannot cast; text layers on top of a
castable hexagram; persistence last. Matches ADR-0007 (build on a known-good
`PhysicsScene`).

## Milestone / Success Criteria

Cast 6 Throws of 3 coins → a structurally correct **本卦** → result screen shows:
- Hexagram number (King Wen, 1–64)
- Hexagram name (Hanzi, e.g. 乾, 坤)
- 6-Yao glyph, bottom-up (阳 ⚊ / 阴 ⚋), with **动爻 positions marked**

Both the Coin Ritual and the 六爻 Ritual are reachable from a minimal switcher.
Explicitly **out of scope** for ①: 变卦 rendering, 卦辞/爻辞 text, Cast Log, on-device
haptics/motion tuning, coin-collision fine-tuning (single follow-up task, see below).

## Key Decisions (from brainstorming)

1. **Decompose Phase 3 into ①②③**, build ① first. ✅
2. **Physics approach C**: 3 coins released *simultaneously* per Throw (spec-true,
   PR-FAQ "separate rigid bodies"), get it *running + aggregating correctly first*;
   collision/settle **fine-tuning is a separate closing task**, not a blocker on the
   "掷出正确本卦" milestone. Decouples "physics feels perfect" from "logic is correct"
   per ADR-0007.
3. **Result screen fidelity A (①-minimal)**: 本卦 only (number + name + 6-Yao glyph,
   动爻 marked). 变卦 and all text deferred to ②.
4. **Navigation B**: ship a minimal Ritual switcher so both Coin and 六爻 are reachable.
5. King Wen 64-table (binary → number + name) is part of ①. It is **not** the Zhou Yi
   corpus (that is ②).
6. 6 Throws = 6 deliberate user actions (tap 掷 or shake once), accumulating bottom-up.
   No "cast all 6 at once".

## Architecture

Single concrete `PhysicsScene` generalized to N coins (ADR-0005: no protocol, no
second scene class). Coin uses N=1, 六爻 uses N=3. Divination meaning stays in the
ViewModel layer; `PhysicsScene` / `ThrowResult` stay meaning-free.

```
LuoApp → RootView (minimal switcher)
           ├── CoinRitualView      (existing; VM reads [ThrowResult][0])
           └── IChingRitualView    (new)
                   └── IChingRitualViewModel
                           ├── PhysicsScene(config: .iChing, coinCount: 3)
                           └── domain: Yao, Hexagram, KingWenTable
```

## Components

### Physics layer (modify)

- **`PhysicsConfig`**: add `coinCount: Int` and `spawnOffsets: [SIMD3<Float>]` (3
  non-overlapping spawn points for 六爻; single origin for Coin). `static let .v1`
  (Coin, count 1) unchanged in behavior; add `static let .iChing` (count 3).
- **`PhysicsScene`**: hold `[coinNode]` instead of one. `performThrow()` releases all
  coins simultaneously (each gets the existing lift + horizontal-axis `applyTorque`,
  per-coin randomized). Settle = **all** coins quiescent (reuse the velocity-free
  presentation position/orientation-delta detector, gated to fire only after a Throw)
  plus the from-throw safety timeout. Callback signature changes:
  `onSettle: ([ThrowResult]) -> Void` (one entry per coin, `id` 0…count-1).
- **`CoinRitualViewModel`**: update `handleSettle` to take `[ThrowResult]` and read
  `results[0]`. No behavior change; keeps Coin green (regression-tested).

### Domain layer (new, pure, unit-testable — no SceneKit import)

- **`Yao`**: value type. Built from a Throw's 3 `CoinFace`s by heads count
  (heads = 背 = 阳, per CONTEXT):
  - 3 heads → 老阳 (yang, changing)
  - 2 heads → 少阴 (yin, not changing)
  - 1 head  → 少阳 (yang, not changing)
  - 0 heads → 老阴 (yin, changing)

  Exposes `isYang: Bool`, `isChanging: Bool`, and a glyph.
- **`Hexagram`**: value type over `[Yao]` (exactly 6, index 0 = bottom = first Throw).
  Computes `presentBits` (yang = 1, bottom-up), `changingMask`, and looks up
  `kingWenNumber: Int` (1–64) + `name: String` via `KingWenTable`.
- **`KingWenTable`**: static lookup, 64 entries, binary pattern (bottom-up, yang = 1)
  → (King Wen number, 卦名 Hanzi). Standard 通行本 sequence. Data-only; the sole ①
  data artifact.

### Orchestration layer (new)

- **`IChingRitualViewModel`** (`@MainActor`, `ObservableObject`):
  - State: `enum IChingCastState { idle, casting, complete(Hexagram) }`;
    `@Published castYao: [Yao]` (0…6 accumulated).
  - Owns `PhysicsScene(config: .iChing)`. `onSettle` → aggregate the 3 faces into one
    `Yao` → append to `castYao` → if `< 6` return to a ready state, else transition to
    `.complete(Hexagram(castYao))`.
  - `cast()` throws the next Yao (disabled while `.casting` or `.complete`).
  - `reset()` (再占) clears `castYao` back to `.idle`.
  - Same shake/motion wiring as Coin (no-op in simulator).

### View layer (new)

- **`IChingRitualView`** (Dusk Desk tokens, `Theme.swift`): scene view (3 coins) on
  top; a **6-Yao column that grows bottom-up** as each Yao settles; hint line ("心中
  默念所问" → "第 N 爻"); one cinnabar 掷 button. On the 6th Yao: fade-in result
  overlay — 卦号 + 卦名 (system serif; Noto Serif SC deferred) + the 6-Yao glyph with
  动爻 marked (small ring). 再占 resets.
- **`RootView`** (new, minimal switcher): two entries on a Dusk Desk background —
  掷币 (Coin) and 六爻 (I Ching). Simplest form that makes both reachable; restraint
  per DESIGN.md (no skins, one accent). `LuoApp` roots into `RootView` instead of
  `CoinRitualView`. The existing long-press → tuning Harness sheet stays on the Coin
  screen.

## Testing Strategy

- **Unit (domain, no simulator):**
  - `Yao` mapping: all 4 heads-counts → correct (isYang, isChanging).
  - `Hexagram` → King Wen number + name: anchors 全阳(bottom-up)=乾 #1,
    全阴=坤 #2, plus a few known interior hexagrams; verify bottom-up ordering
    (first Throw is the bottom Yao).
  - `changingMask` correctness for mixed old/young casts.
- **Physics (headless, per [[feedback-luo-scenekit-debug-workflow]]):** 3-coin Throw
  settles, emits exactly 3 `ThrowResult`s, `timedOut == 0`; read the trajectory from
  `LUO_DEBUG` logs (no eyes on animation). Strip probes before final build.
- **Regression:** Coin Ritual still `BUILD SUCCEEDED` and settles (its VM now reads
  `results[0]`).
- **Build target:** iPhone 17 / iOS 26.5 simulator (no iPhone 16 installed anymore);
  device-agnostic build `-destination 'generic/platform=iOS Simulator'`.

## Closing task (tracked, not a milestone blocker)

**三钱物理精调** — tune inter-coin collision + 3-body settle so the throw *feels* like
three coins on the desk (spawn spacing, tray size, restitution, settle thresholds for
3 bodies). Runs after the logic milestone is green.

## Deferred (explicitly not ①)

- 变卦 (Resulting Hexagram) computation + side-by-side render → ②
- 卦辞 / 动爻辞 Zhou Yi corpus + Canonical Text toggle → ②
- Cast Log persistence, list/detail/delete, Coin "save this Cast" → ③
- Real ritual home / navigation polish beyond the minimal switcher
- On-device haptics/CoreMotion tuning (needs $99 Apple Developer membership, deferred)
- Noto Serif SC for 卦名/classical text (system serif for now)
