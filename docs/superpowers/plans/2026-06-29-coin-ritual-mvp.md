# Coin Ritual MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Coin Harness as the app's entry surface with a polished single-screen Coin Ritual (tap/shake → coin tumbles → calm 阳/阴 reveal), with the tuning sliders hidden behind a long-press debug sheet.

**Architecture:** A `CoinRitualViewModel` (ADR-0005) owns a `PhysicsScene(config: .v1)`, exposes one `CoinCastState`, and maps the settled `ThrowResult.faceUp` → `Yinyang`. `CoinRitualView` is the new app root: the scene fills the screen with a quiet hint, a single cinnabar cast button, and a fade-in result. The existing `HarnessView` is kept and shown only via a long-press debug sheet.

**Tech Stack:** Swift 5, SwiftUI, SceneKit; XcodeGen project; iOS 17 min, iPhone-only. No third-party deps.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-28-coin-ritual-mvp-design.md`.
- **No test target exists.** Verification = `xcodebuild` BUILD SUCCEEDED + headless `simctl` probe/screenshot (per `feedback-luo-scenekit-debug-workflow`). Do NOT add an XCTest target (YAGNI for this MVP).
- Do NOT modify `PhysicsScene.swift`, `PhysicsConfig.swift`, `ThrowResult.swift`, `HapticsService.swift`, `MotionService.swift`. Reuse their existing APIs:
  - `PhysicsScene(config: PhysicsConfig, onSettle: @escaping (ThrowResult) -> Void, onStateChange: @escaping (SettleState) -> Void)`; `.scene` (SCNScene); `performThrow()`, `applyShake(magnitude:)`, `apply(_:)`; conforms to `SCNSceneRendererDelegate`.
  - `ThrowResult { id; position; orientation; faceUp: CoinFace }`; `CoinFace { heads, tails, edge }`; `SettleState { idle, throwing, settling, settled(CoinFace) }`.
- Stateless: no persistence, no history, no question input, no I Ching (spec non-goals).
- Dusk Desk colors (DESIGN.md): backdrop `#14110D`, ink `#ECE3D2`, cinnabar `#DC6A4B`. One accent per screen.
- Result copy: heads → **阳** / 是, tails → **阴** / 否.
- Build command (reused every task):
  `xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
- New `.swift` files live in `Luo/`; `project.yml` globs that folder, so after creating/deleting files run `xcodegen generate` before building.
- Booted sim UDID used in examples: `B605B095-92B3-4A9E-9322-61E0D70DA1B7` (iPhone 17 Pro). Confirm with `xcrun simctl list devices booted`.
- App bundle id: `com.charliezong.luo`. Built app path: `~/Library/Developer/Xcode/DerivedData/Luo-*/Build/Products/Debug-iphonesimulator/Luo.app`.

---

### Task 1: Theme (Dusk Desk tokens)

**Files:**
- Create: `Luo/Theme.swift`

**Interfaces:**
- Produces: `enum Theme` with `static let deskBackground: Color`, `static let ink: Color`, `static let cinnabar: Color`, and `static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font`.

- [ ] **Step 1: Create `Luo/Theme.swift`**

```swift
import SwiftUI

/// Dusk Desk visual tokens (DESIGN.md). Centralized so views don't hardcode hex.
enum Theme {
    /// neutral #14110D — warm near-black desk.
    static let deskBackground = Color(red: 0.078, green: 0.067, blue: 0.051)
    /// primary #ECE3D2 — aged-paper ink.
    static let ink = Color(red: 0.925, green: 0.890, blue: 0.824)
    /// tertiary #DC6A4B — earthen cinnabar accent (one per screen).
    static let cinnabar = Color(red: 0.863, green: 0.416, blue: 0.294)

    /// Serif face for Hanzi/result glyphs. System serif for MVP (PingFang/Songti
    /// fallback for Chinese); bundling Noto Serif SC is a later polish.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
```

- [ ] **Step 2: Regenerate project and build**

Run: `cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`, no `error:`.

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Theme.swift && git commit -m "Add Dusk Desk Theme tokens for the ritual UI"
```

---

### Task 2: CoinRitualViewModel (state machine + Yinyang)

**Files:**
- Create: `Luo/CoinRitualViewModel.swift`

**Interfaces:**
- Consumes: `PhysicsScene`, `ThrowResult`, `CoinFace`, `SettleState`, `HapticsService`, `MotionService` (existing).
- Produces:
  - `enum Yinyang { case yang, yin; var glyph: String; var reading: String; init(_ face: CoinFace) }`
  - `enum CoinCastState: Equatable { case idle; case casting; case result(Yinyang) }`
  - `final class CoinRitualViewModel: ObservableObject` with `@Published private(set) var state: CoinCastState`, `@Published private(set) var hasCast: Bool`, `var scene: PhysicsScene` (lazy), `func cast()`, `func startMotion()`, `func stopMotion()`.

- [ ] **Step 1: Create `Luo/CoinRitualViewModel.swift`**

```swift
import SwiftUI
import SceneKit

/// Ritual semantics for a single coin. Heads → 阳, tails → 阴 (edge can't happen
/// on a flat tray; folded into 阳). Kept in the VM layer so PhysicsScene /
/// ThrowResult stay free of divination meaning.
enum Yinyang: Equatable {
    case yang, yin

    init(_ face: CoinFace) { self = (face == .tails) ? .yin : .yang }

    var glyph: String { self == .yang ? "阳" : "阴" }
    var reading: String { self == .yang ? "是" : "否" }
}

/// What the Coin Ritual screen is showing.
enum CoinCastState: Equatable {
    case idle                 // ready; hint + 掷
    case casting              // coin in flight; button disabled
    case result(Yinyang)      // settled; 阳/阴 revealed; button → 再掷
}

@MainActor
final class CoinRitualViewModel: ObservableObject {
    @Published private(set) var state: CoinCastState = .idle
    @Published private(set) var hasCast = false

    private let haptics = HapticsService()
    private let motion = MotionService()

    /// Lazy so the escaping callbacks can capture a fully-initialized self.
    lazy var scene: PhysicsScene = PhysicsScene(
        config: .v1,
        onSettle: { [weak self] result in self?.handleSettle(result) },
        onStateChange: { [weak self] s in self?.handleStateChange(s) }
    )

    /// Throw the coin (tap button or shake).
    func cast() {
        scene.performThrow()
        state = .casting
    }

    /// Start/stop device-shake casting (no-op in simulator).
    func startMotion() {
        motion.start { [weak self] mag in self?.scene.applyShake(magnitude: mag) }
    }
    func stopMotion() { motion.stop() }

    // MARK: - PhysicsScene callbacks

    private func handleSettle(_ result: ThrowResult) {
        haptics.playSettleThunk()
        state = .result(Yinyang(result.faceUp))
        hasCast = true
    }

    private func handleStateChange(_ s: SettleState) {
        // The settled face arrives via handleSettle; here we only keep `.casting`
        // alive while the coin is in motion. Ignore .idle/.settled.
        switch s {
        case .throwing, .settling:
            if state != .casting { state = .casting }
        case .idle, .settled:
            break
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`. (VM compiles; behavior is exercised in Task 5 once a View hosts the SceneView.)

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Luo && git add Luo/CoinRitualViewModel.swift && git commit -m "Add CoinRitualViewModel: cast state machine + Yinyang mapping"
```

---

### Task 3: CoinRitualView (the ritual screen)

**Files:**
- Create: `Luo/CoinRitualView.swift`

**Interfaces:**
- Consumes: `CoinRitualViewModel`, `CoinCastState`, `Yinyang`, `Theme`, `HarnessView` (existing).
- Produces: `struct CoinRitualView: View`.

- [ ] **Step 1: Create `Luo/CoinRitualView.swift`**

```swift
import SwiftUI
import SceneKit

/// 落 — Coin Ritual MVP screen. The PhysicsScene fills the screen; a quiet hint,
/// a single cinnabar cast button, and a fade-in 阳/阴 result overlay it. A long
/// press opens the throwaway tuning Harness as a debug sheet.
struct CoinRitualView: View {
    @StateObject private var vm = CoinRitualViewModel()
    @State private var showDebug = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()

            // Fixed-framing scene (no camera control in the ritual).
            SceneView(scene: vm.scene.scene, options: [], delegate: vm.scene)
                .ignoresSafeArea()

            VStack {
                hint
                Spacer()
                resultOverlay
                Spacer()
                castButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.state)
        .onAppear { vm.startMotion() }
        .onDisappear { vm.stopMotion() }
        // Long-press anywhere opens the hidden tuning Harness.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.5).onEnded { _ in showDebug = true }
        )
        .sheet(isPresented: $showDebug) { HarnessView() }
    }

    private var hint: some View {
        Text("心中默念所问")
            .font(Theme.serif(17))
            .foregroundColor(Theme.ink.opacity(vm.hasCast ? 0.25 : 0.6))
    }

    @ViewBuilder private var resultOverlay: some View {
        if case .result(let yy) = vm.state {
            VStack(spacing: 10) {
                Text(yy.glyph)
                    .font(Theme.serif(96, weight: .medium))
                    .foregroundColor(Theme.ink)
                Text(yy.reading)
                    .font(Theme.serif(22))
                    .foregroundColor(Theme.ink.opacity(0.7))
            }
            .transition(.opacity)
        }
    }

    private var castButton: some View {
        Button(action: { vm.cast() }) {
            Text(vm.hasCast ? "再掷" : "掷")
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.deskBackground)
                .frame(width: 120, height: 52)
                .background(Theme.cinnabar)
                .clipShape(Capsule())
                .opacity(vm.state == .casting ? 0.4 : 1)
        }
        .disabled(vm.state == .casting)
    }
}

#Preview {
    CoinRitualView()
}
```

- [ ] **Step 2: Build**

Run: `cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Luo && git add Luo/CoinRitualView.swift && git commit -m "Add CoinRitualView: scene + hint + cast button + result reveal"
```

---

### Task 4: Switch app root + first end-to-end screenshot

**Files:**
- Modify: `Luo/LuoApp.swift`

**Interfaces:**
- Consumes: `CoinRitualView`.

- [ ] **Step 1: Point the app root at the ritual**

Replace the `WindowGroup` body in `Luo/LuoApp.swift` so it shows `CoinRitualView()` instead of `HarnessView()`. Full file:

```swift
import SwiftUI

@main
struct LuoApp: App {
    var body: some Scene {
        WindowGroup {
            CoinRitualView()
        }
    }
}
```

- [ ] **Step 2: Build, install, launch, screenshot idle**

Run:
```bash
cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
DEV=B605B095-92B3-4A9E-9322-61E0D70DA1B7
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Luo-*/Build/Products/Debug-iphonesimulator/Luo.app | head -1)
xcrun simctl terminate "$DEV" com.charliezong.luo 2>/dev/null
xcrun simctl install "$DEV" "$APP" && xcrun simctl launch "$DEV" com.charliezong.luo
sleep 2
xcrun simctl io "$DEV" screenshot /tmp/luo_ritual_idle.png && echo saved
```
Expected: BUILD SUCCEEDED; `saved`. Then Read `/tmp/luo_ritual_idle.png` and confirm: coin seated on the felt, hint "心中默念所问" at top, a cinnabar "掷" button at the bottom, **no slider list**.

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Luo && git add Luo/LuoApp.swift && git commit -m "Make CoinRitualView the app root (Harness now debug-only)"
```

---

### Task 5: Verify cast lifecycle headlessly, then strip probe

**Files:**
- Modify (temporary): `Luo/CoinRitualView.swift`, `Luo/CoinRitualViewModel.swift`

**Interfaces:**
- Consumes: existing VM/View.

- [ ] **Step 1: Add a temporary auto-cast + state log**

In `Luo/CoinRitualViewModel.swift`, log the new state in two places:
- In `handleSettle`, on the line **after** `state = .result(Yinyang(result.faceUp))`:
  ```swift
  NSLog("LUO_PROBE state→%@", "\(state)")   // TEMP PROBE
  ```
- In `handleStateChange`, inside the `.throwing, .settling` branch, after `state = .casting`:
  ```swift
  NSLog("LUO_PROBE state→%@", "\(state)")   // TEMP PROBE
  ```

In `Luo/CoinRitualView.swift`, add a temporary auto-cast in `.onAppear`:
```swift
.onAppear {
    vm.startMotion()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { vm.cast() }   // TEMP PROBE
}
```

- [ ] **Step 2: Build, run, capture the lifecycle**

Run:
```bash
cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"
DEV=B605B095-92B3-4A9E-9322-61E0D70DA1B7
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Luo-*/Build/Products/Debug-iphonesimulator/Luo.app | head -1)
xcrun simctl terminate "$DEV" com.charliezong.luo 2>/dev/null
xcrun simctl install "$DEV" "$APP" && xcrun simctl launch "$DEV" com.charliezong.luo >/dev/null
sleep 6
xcrun simctl spawn "$DEV" log show --last 7s --predicate 'eventMessage CONTAINS "LUO_PROBE"' 2>/dev/null | grep -oE 'LUO_PROBE.*'
xcrun simctl io "$DEV" screenshot /tmp/luo_ritual_result.png && echo saved
```
Expected: log shows `state→casting` … then `state→result(...yang)` or `result(...yin)` exactly once. Read `/tmp/luo_ritual_result.png` and confirm a large 阳 or 阴 with 是/否 beneath, and the button now reads "再掷".

- [ ] **Step 3: Remove the probes**

Delete the two `NSLog("LUO_PROBE…")` lines and the `DispatchQueue…asyncAfter { vm.cast() }` line (restore `.onAppear { vm.startMotion() }`). Verify clean:
Run: `cd ~/Developer/Luo && grep -rn "LUO_PROBE\|asyncAfter\|NSLog" Luo/*.swift || echo clean`
Expected: `clean`.

- [ ] **Step 4: Rebuild to confirm still green**

Run: `cd ~/Developer/Luo && xcodegen generate && xcodebuild build -project Luo.xcodeproj -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add -A Luo/ && git commit -m "Verify Coin Ritual cast lifecycle (idle→casting→result)"
```

---

### Task 6: Verify the hidden debug sheet

**Files:** none (verification only).

- [ ] **Step 1: Confirm the long-press path compiles and is wired**

Confirm `CoinRitualView` has `.sheet(isPresented: $showDebug) { HarnessView() }` and the `LongPressGesture(minimumDuration: 1.5)` sets `showDebug = true`. (Long-press can't be driven headlessly via simctl.)

- [ ] **Step 2: Manual check (Charlie, in the simulator)**

In the running app, press and hold the desk for ~1.5s → the Harness slider sheet should slide up; swipe it down → back to the ritual. The sliders still tune the live coin (they call `scene.apply(params.makeConfig())`).

- [ ] **Step 3: Final idle + result screenshots for the record**

Run:
```bash
DEV=B605B095-92B3-4A9E-9322-61E0D70DA1B7
xcrun simctl io "$DEV" screenshot /tmp/luo_ritual_final.png && echo saved
```
Read it; confirm the ritual screen looks clean (coin seated, hint, cinnabar button, no sliders).

- [ ] **Step 4: Push the branch**

```bash
cd ~/Developer/Luo && git push origin main
```

---

## Notes for the implementer

- The VM's `scene` is `lazy` on purpose: `PhysicsScene`'s callbacks capture `self`, so the scene must be built after the VM is fully initialized. Don't change it to a stored `let` initialized in `init` — it won't compile.
- `onSettle` runs synchronously inside the physics tick; `onStateChange(.settled)` arrives slightly later via a `Task`. That's why `handleStateChange` ignores `.settled` (the result is already set by `handleSettle`). Don't "fix" this by also setting the result in `handleStateChange` — you'd double-fire.
- Keep `SceneView` options `[]` in the ritual (fixed framing). `allowsCameraControl` stays only in the debug `HarnessView`.
- If the long-press fights the (now disabled) camera control or button, prefer `.simultaneousGesture`; the button's own tap still works.
