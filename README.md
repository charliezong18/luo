# 落 (Luò)

Native iOS divination app — physics-grade Rituals (Coin, I Ching, later Dice / Tarot / 签筒). Design source of truth lives in the 2nd Brain vault: `Hang/Plans/Divination_App/` (CONTEXT.md + ADRs 0001–0009).

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

## Setup steps (need Xcode installed first)

1. Xcode → File → New → Project → iOS → App.
2. Product Name: `Luo`. Interface: SwiftUI. Language: Swift. Save at `~/Developer/Luo/` (overwrite the auto-created folder; the staged Swift files are already there).
3. In Project Navigator, right-click `Luo` group → Add Files to "Luo"… → select all six `.swift` files in `Luo/` → uncheck "Copy items if needed", check the `Luo` target → Add.
4. Delete the boilerplate `ContentView.swift` Xcode generated.
5. Min Deployment: iOS 17 (matches iPhone 15+ per ADR-0007 Phase 2).
6. Signing & Capabilities: add your Apple ID team.
7. Run on real device (Simulator can't haptic; CoreMotion is also weak on Sim).

## Phase 2 tuning loop

Once running on device, the loop is:
1. Throw → watch + feel.
2. Adjust one slider at a time.
3. Throw again.
4. Repeat until Settle reads "like the desk".
5. Record the converged values; they become `PhysicsScene` constants in v1.
