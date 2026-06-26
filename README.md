# 落 (Luò)

Native iOS divination app — physics-grade Rituals (Coin, I Ching, later Dice / Tarot / 签筒). Design source of truth lives in the 2nd Brain vault: `Hang/Plans/Divination_App/` (CONTEXT.md + ADRs 0001–0009).

## Visual identity — `DESIGN.md`

The visual system is specified in Google's [design.md](https://github.com/google-labs-code/design.md) format (`@google/design.md` — YAML design tokens + prose rationale). Two variants exist, both deriving the same typography/spacing/shape from the ADRs and differing only in palette:

| File | Variant | Status |
|---|---|---|
| `DESIGN.md` | **Dusk Desk** — warm near-black desk, aged-paper ink, one cinnabar accent | **active default** (matches the dark SceneKit scene) |
| `DESIGN-paper.md` | **Rice Paper** — warm 宣纸 cream, ground-ink type, deep cinnabar seal | parked alternative |

The dark/light choice is **deliberately deferred to Phase 2** (real device, judged in the hand). Both pass `npx @google/design.md lint <file>` clean. Validate any token edit with the lint CLI before committing.

## Current state — Phase 0/1 staging

Per [ADR-0007](../../Library/CloudStorage/GoogleDrive-charliezong18@gmail.com/My%20Drive/2nd%20Brain/Hang/Plans/Divination_App/docs/adr/0007-build-cadence-coin-harness-then-iching.md), the first thing built is a *Coin Harness* — a deliberately ugly SceneKit + CoreMotion + CoreHaptics rig used to tune Settle feel on a single-coin primitive. The Harness is throwaway; only the converged physics constants survive into v1.

The Swift sources for the Harness are pre-staged in `Luo/`:

| File | Role |
|---|---|
| `LuoApp.swift` | `@main` SwiftUI App entry |
| `HarnessView.swift` | Top SceneView, Settle indicator, Throw / Reset / Shake controls, slider list |
| `CoinHarnessScene.swift` | SceneKit scene: single coin + table + Settle detector |
| `PhysicsParams.swift` | Observable model of every tunable knob |
| `MotionService.swift` | CoreMotion wrapper, fires on sustained-acceleration shake |
| `HapticsService.swift` | CoreHaptics wrapper, settle-thunk + tumble-tick |

## Setup — XcodeGen

The Xcode project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) — no hand-built `.xcodeproj` is committed; regenerate any time. Sources live in `Luo/`.

```bash
brew install xcodegen        # once (already installed on the Mac mini)
cd ~/Developer/luo
xcodegen generate            # writes Luo.xcodeproj from project.yml
open Luo.xcodeproj           # then ⌘R
```

Build + verify from CLI (no signing, Simulator):

```bash
xcodebuild -project Luo.xcodeproj -scheme Luo \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

- Min deployment **iOS 17** (iPhone 15+ per ADR-0007 Phase 2); `TARGETED_DEVICE_FAMILY=1` (iPhone only).
- **Simulator** shows the visuals + Throw button, but haptics are silent and CoreMotion shake is weak — real-device tuning is Phase 2.
- **Real device:** set `DEVELOPMENT_TEAM` in `project.yml` (or Xcode → Signing) to your Apple ID team, `xcodegen generate`, run.

## Phase 2 tuning loop

Once running on device, the loop is:
1. Throw → watch + feel.
2. Adjust one slider at a time.
3. Throw again.
4. Repeat until Settle reads "like the desk".
5. Record the converged values; they become `PhysicsScene` constants in v1.
