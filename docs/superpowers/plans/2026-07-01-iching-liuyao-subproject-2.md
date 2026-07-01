# 六爻 Sub-project ② Implementation Plan (周易文本 + 变卦, seed)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the Resulting Hexagram (变卦) beside the Present Hexagram (本卦) and add a canonical 卦辞/爻辞 text toggle, driven by a small verified seed corpus (乾 + 坤).

**Architecture:** Extend ①'s pure domain (`Yao`, `Hexagram`) with a static-line factory + `resultingHexagram`; add a plain `ZhouYiCorpus` lookup seeded with 乾/坤; extend `IChingRitualView.hexagramResult` into a 本卦 → 变卦 side-by-side layout with a collapsible 释文 block. Domain/data stay SceneKit-free and unit-tested; the corpus is data-only so backfilling the full 448 passages later needs no code change.

**Tech Stack:** Swift 5, SwiftUI, XCTest. XcodeGen (`project.yml` → `Luo.xcodeproj`, regenerate not commit).

## Global Constraints

- Swift 5 (`SWIFT_VERSION: "5.0"`), min deploy iOS 17, iPhone-only.
- Build/test on **iPhone 17 / iOS 26.5** simulator. Test: `xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`.
- New source files under `Luo/` (and tests under `LuoTests/`) require `xcodegen generate` before they compile into the target — run it after creating files.
- Domain (`Yao`, `Hexagram`) and data (`ZhouYiCorpus`, `HexagramText`) import **no SceneKit** — pure, unit-testable.
- Visual tokens via `Theme.swift` (Dusk Desk) only — no hardcoded hex.
- **ADR-0004: canonical text is displayed verbatim, classical Chinese only — NO translation, pinyin, gloss, or "which line to read" interpretation.**
- Yao bit/order conventions from ①: `changingPositions` are 1-based bottom-up; `presentBits` bit 0 = bottom, yang = 1.
- Seed corpus = 乾 (#1) + 坤 (#2) only for this sub-project (they are each other's 变卦, so the full both-seeded text path is exercised; partial-change casts exercise the "（待补）" degradation). Full 64+384 backfill is a separate later data task.

---

### Task 1: `Yao(isYang:)` static-line factory

**Files:**
- Modify: `Luo/Yao.swift`
- Test: `LuoTests/YaoTests.swift` (extend)

**Interfaces:**
- Produces: `Yao.init(isYang: Bool)` — a non-changing (young) line: `isChanging == false`, `isYang ==` arg, `kind == .youngYang`/`.youngYin`, `glyph` ⚊/⚋.
- Consumes: existing `Yao`, `YaoKind`.

- [ ] **Step 1: Write the failing test** — append to `LuoTests/YaoTests.swift`:

```swift
    func testStaticYangLine() {
        let y = Yao(isYang: true)
        XCTAssertTrue(y.isYang)
        XCTAssertFalse(y.isChanging)
        XCTAssertEqual(y.kind, .youngYang)
        XCTAssertEqual(y.glyph, "⚊")
    }

    func testStaticYinLine() {
        let y = Yao(isYang: false)
        XCTAssertFalse(y.isYang)
        XCTAssertFalse(y.isChanging)
        XCTAssertEqual(y.kind, .youngYin)
        XCTAssertEqual(y.glyph, "⚋")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `extra argument 'isYang' in call` / no matching initializer.

- [ ] **Step 3: Write minimal implementation** — add to `struct Yao` in `Luo/Yao.swift`, after `init(faces:)`:

```swift
    /// A static (non-changing) line of the given polarity — used to build the
    /// Resulting Hexagram (变卦), whose lines are not cast from coins.
    init(isYang: Bool) {
        kind = isYang ? .youngYang : .youngYin
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Yao.swift LuoTests/YaoTests.swift && git commit -m "feat: add Yao(isYang:) static-line factory for 变卦"
```

---

### Task 2: `Hexagram.resultingHexagram` (变卦)

**Files:**
- Modify: `Luo/Hexagram.swift`
- Test: `LuoTests/HexagramTests.swift` (extend)

**Interfaces:**
- Consumes: `Yao(isYang:)` (Task 1), `Yao.isChanging`/`.isYang`, `Hexagram.init(yao:)`, `changingPositions`, `KingWenTable`.
- Produces: `Hexagram.resultingHexagram: Hexagram?` — `nil` if no changing Yao; else the hexagram with each changing Yao flipped to the opposite static line and each non-changing Yao kept as a static line of the same polarity.

- [ ] **Step 1: Write the failing test** — append to `LuoTests/HexagramTests.swift`:

```swift
    func testNoChangingYaoHasNoResulting() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 1), count: 6)) // all young-yang
        XCTAssertNil(h.resultingHexagram)
    }

    func testAllOldYangResultsInKun() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 3), count: 6)) // all old-yang, all changing
        let r = h.resultingHexagram
        XCTAssertEqual(r?.number, 2)
        XCTAssertEqual(r?.name, "坤")
        XCTAssertEqual(r?.changingPositions, []) // 变卦 is static
    }

    func testBottomChangingOnAllYangResultsInGou() {
        // bottom old-yang (changing) + 5 young-yang → 本卦 乾; flip bottom → 姤 #44
        let yaos = [yao(heads: 3)] + Array(repeating: yao(heads: 1), count: 5)
        let r = Hexagram(yao: yaos).resultingHexagram
        XCTAssertEqual(r?.number, 44)
        XCTAssertEqual(r?.name, "姤")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `value of type 'Hexagram' has no member 'resultingHexagram'`.

- [ ] **Step 3: Write minimal implementation** — add to `struct Hexagram` in `Luo/Hexagram.swift`, after `changingPositions`:

```swift
    /// The Resulting Hexagram (变卦): each changing Yao flips to the opposite
    /// static line; each non-changing Yao becomes a static line of the same
    /// polarity. `nil` when there are no changing Yao. The 变卦 is itself static
    /// (none of its lines are changing).
    var resultingHexagram: Hexagram? {
        guard !changingPositions.isEmpty else { return nil }
        let lines = yao.map { Yao(isYang: $0.isChanging ? !$0.isYang : $0.isYang) }
        return Hexagram(yao: lines)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Hexagram.swift LuoTests/HexagramTests.swift && git commit -m "feat: add Hexagram.resultingHexagram (变卦)"
```

---

### Task 3: `ZhouYiCorpus` + `HexagramText` + seed 乾/坤

**Files:**
- Create: `Luo/ZhouYiCorpus.swift`
- Test: `LuoTests/ZhouYiCorpusTests.swift`

**Interfaces:**
- Produces:
  - `struct HexagramText { let guaCi: String; let yaoCi: [String]; let yong: String? }` (`yaoCi` exactly 6, index 0 = bottom = 初, each entry the FULL labeled line e.g. "初九：潛龍勿用。").
  - `enum ZhouYiCorpus { static func text(forNumber n: Int) -> HexagramText? }` — nil for un-seeded numbers.

**Data verification:** the 乾/坤 passages below are the most famous in the 周易 and are given verbatim. During implementation, **diff every character against a public-domain 周易 经文 source** (Chinese Text Project ctext.org 易經, or Wikisource 易經) — a wrong glyph variant passes the structural tests. Keep the traditional forms as written (无, 貞, 後, 玄黃).

- [ ] **Step 1: Write the failing test** — create `LuoTests/ZhouYiCorpusTests.swift`:

```swift
import XCTest
@testable import Luo

final class ZhouYiCorpusTests: XCTestCase {
    func testQianSeeded() {
        let t = ZhouYiCorpus.text(forNumber: 1)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.guaCi, "元亨利貞")
        XCTAssertEqual(t?.yaoCi.count, 6)
        XCTAssertEqual(t?.yaoCi.first, "初九：潛龍勿用。")
        XCTAssertNotNil(t?.yong) // 用九
    }

    func testKunSeeded() {
        let t = ZhouYiCorpus.text(forNumber: 2)
        XCTAssertNotNil(t)
        XCTAssertEqual(t?.yaoCi.count, 6)
        XCTAssertNotNil(t?.yong) // 用六
    }

    func testUnseededReturnsNil() {
        XCTAssertNil(ZhouYiCorpus.text(forNumber: 44)) // 姤 not in seed
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `cannot find 'ZhouYiCorpus' in scope`.

- [ ] **Step 3: Write minimal implementation** — create `Luo/ZhouYiCorpus.swift`:

```swift
import Foundation

/// One hexagram's canonical 周易 text (ADR-0004): 卦辞 + 6 爻辞 (bottom→top, each
/// a full labeled line) + optional 用九/用六 (乾/坤 only). Displayed verbatim,
/// classical Chinese — never translated or glossed.
struct HexagramText {
    let guaCi: String
    let yaoCi: [String]   // exactly 6, index 0 = 初 (bottom)
    let yong: String?     // 用九 (乾) / 用六 (坤), else nil
}

/// Lookup of 周易 canonical text by King Wen number. SEED corpus (乾 + 坤) for
/// Sub-project ②; the full 64 卦辞 + 384 爻辞 backfill is a later data task that
/// only adds entries to `seed` — no logic change.
enum ZhouYiCorpus {
    static func text(forNumber n: Int) -> HexagramText? { seed[n] }

    private static let seed: [Int: HexagramText] = [
        1: HexagramText(
            guaCi: "元亨利貞",
            yaoCi: [
                "初九：潛龍勿用。",
                "九二：見龍在田，利見大人。",
                "九三：君子終日乾乾，夕惕若厲，无咎。",
                "九四：或躍在淵，无咎。",
                "九五：飛龍在天，利見大人。",
                "上九：亢龍有悔。",
            ],
            yong: "用九：見群龍无首，吉。"
        ),
        2: HexagramText(
            guaCi: "元亨，利牝馬之貞。君子有攸往，先迷後得主，利。西南得朋，東北喪朋。安貞吉。",
            yaoCi: [
                "初六：履霜，堅冰至。",
                "六二：直方大，不習无不利。",
                "六三：含章可貞，或從王事，无成有終。",
                "六四：括囊，无咎无譽。",
                "六五：黃裳，元吉。",
                "上六：龍戰于野，其血玄黃。",
            ],
            yong: "用六：利永貞。"
        ),
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/ZhouYiCorpus.swift LuoTests/ZhouYiCorpusTests.swift && git commit -m "feat: add ZhouYiCorpus seed (乾/坤 卦辞+爻辞+用九用六)"
```

---

### Task 4: Result screen — 本卦 → 变卦 side by side + 释文 toggle

**Files:**
- Modify: `Luo/IChingRitualView.swift`

**Interfaces:**
- Consumes: `Hexagram` (`.number`, `.name`, `.yao`, `.changingPositions`, `.resultingHexagram`), `Yao` (`.glyph`, `.isChanging`), `ZhouYiCorpus.text(forNumber:)`, `HexagramText`, `Theme`, existing `yaoRow`.
- Produces: reworked `hexagramResult(_:)`.

- [ ] **Step 1: Add the text-toggle state** — in `struct IChingRitualView`, next to the existing `@StateObject private var vm`, add:

```swift
    @State private var showText = false
```

- [ ] **Step 2: Replace `hexagramResult(_:)` and add helpers** — replace the existing `hexagramResult(_:)` in `Luo/IChingRitualView.swift` with:

```swift
    private func hexagramResult(_ hex: Hexagram) -> some View {
        VStack(spacing: 16) {
            Text("第 \(hex.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))

            // 本卦 → 变卦 side by side (arrow + 变卦 only when there are 动爻).
            HStack(alignment: .center, spacing: 18) {
                hexagramColumn(hex)
                if let resulting = hex.resultingHexagram {
                    Text("→")
                        .font(Theme.serif(30))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    hexagramColumn(resulting)
                }
            }

            // 释文 toggle — only when the 本卦 has seeded canonical text.
            if ZhouYiCorpus.text(forNumber: hex.number) != nil {
                Button(action: { showText.toggle() }) {
                    Text(showText ? "释文 ▴" : "释文 ▾")
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.cinnabar)
                }
                if showText { canonicalText(hex) }
            }
        }
        .transition(.opacity)
    }

    /// One hexagram column: 卦名 over its vertical 6-Yao glyph (top = Yao 6).
    /// 动爻 rings come for free from `yaoRow` (the 变卦's lines are non-changing).
    private func hexagramColumn(_ hex: Hexagram) -> some View {
        VStack(spacing: 8) {
            Text(hex.name)
                .font(Theme.serif(30, weight: .medium))
                .foregroundColor(Theme.ink)
            VStack(spacing: 5) {
                ForEach(Array(hex.yao.enumerated().reversed()), id: \.offset) { _, yao in
                    yaoRow(yao)
                }
            }
        }
    }

    /// Canonical 周易 text (ADR-0004): 本卦卦辞 · 动爻辞 (or 用九/用六 when all 6
    /// change on 乾/坤) · 变卦卦辞. Classical text only, verbatim.
    @ViewBuilder private func canonicalText(_ hex: Hexagram) -> some View {
        if let t = ZhouYiCorpus.text(forNumber: hex.number) {
            VStack(alignment: .leading, spacing: 8) {
                Text(hex.name + "　" + t.guaCi)
                    .font(Theme.serif(16))
                    .foregroundColor(Theme.ink)
                ForEach(changingLines(hex, t), id: \.self) { line in
                    Text(line)
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.ink.opacity(0.85))
                }
                if let resulting = hex.resultingHexagram {
                    let rt = ZhouYiCorpus.text(forNumber: resulting.number)?.guaCi ?? "（待补）"
                    Text("变卦 " + resulting.name + "　" + rt)
                        .font(Theme.serif(16))
                        .foregroundColor(Theme.ink.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    /// The 爻辞 lines to show for the 动爻 — or 用九/用六 when all 6 Yao change on
    /// 乾/坤. `yaoCi` entries are already full labeled lines.
    private func changingLines(_ hex: Hexagram, _ t: HexagramText) -> [String] {
        if hex.changingPositions.count == 6, let yong = t.yong { return [yong] }
        return hex.changingPositions.map { t.yaoCi[$0 - 1] }
    }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Screenshot the 变卦 + 释文 path (temporary scaffolding)**

To reliably show a 变卦 + seeded 释文, temporarily force a 乾 (all old-yang) completed cast:
1. In `Luo/LuoApp.swift`: `RootView()` → `IChingRitualView()`.
2. In `Luo/IChingRitualViewModel.swift`, temporarily seed a completed 乾 cast — change the `@Published private(set) var castYao` and `state` initial values, or add in `init` (TEMP):
   ```swift
   // TEMP for screenshot
   init() {
       let oldYang = Yao(faces: [.heads, .heads, .heads])
       castYao = Array(repeating: oldYang, count: 6)
       state = .complete(Hexagram(yao: castYao))
   }
   ```
3. In `Luo/IChingRitualView.swift`, temporarily default `@State private var showText = true`.
4. Build for sim, install, launch, `sleep 2`, screenshot:
   ```bash
   cd ~/Developer/Luo
   xcodebuild -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
   UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
   [ -z "$UDID" ] && UDID=$(xcrun simctl list devices available | grep 'iPhone 17 ' | grep -oE '[0-9A-F-]{36}' | head -1) && xcrun simctl boot "$UDID"
   APP=$(find ~/Library/Developer/Xcode/DerivedData -name Luo.app -path '*Debug-iphonesimulator*' | head -1)
   xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.charliezong.luo
   sleep 2 && xcrun simctl io "$UDID" screenshot /tmp/iching2-text.png
   ```
   **Read `/tmp/iching2-text.png`** — confirm: 第 1 卦, 本卦 乾 → 变卦 坤 side by side, 动爻 rings on 本卦, and the expanded 释文 showing 乾卦辞 + 用九 (all 6 change) + 变卦 坤卦辞. Keep the file for the controller.

- [ ] **Step 5: Revert the temporary scaffolding**

Revert `LuoApp.swift` (`IChingRitualView()` → `RootView()`), the `IChingRitualViewModel.init` temp seed, and `showText` back to `false`. Confirm clean:
Run: `cd ~/Developer/Luo && grep -n 'IChingRitualView()' Luo/LuoApp.swift; grep -n 'TEMP for screenshot' Luo/IChingRitualViewModel.swift; grep -n 'showText = true' Luo/IChingRitualView.swift`
Expected: no output from any of the three.

- [ ] **Step 6: Final build + commit**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

```bash
cd ~/Developer/Luo && git add Luo/IChingRitualView.swift && git commit -m "feat: result screen 本卦→变卦 side-by-side + 释文 toggle"
```

---

## Deferred (not this plan)

- **Full corpus backfill** — the remaining 62 卦辞 + 372 爻辞 (+ any 用 lines): add entries to `ZhouYiCorpus.seed` from a verified public-domain source. Data-only; model + view already handle it. Separate later task.
- Cast Log persistence → Sub-project ③.
- Noto Serif SC for classical text; coin face legibility → later polish.

## Self-Review

**Spec coverage:**
- 变卦 computation → Task 2 (`resultingHexagram`), needs Task 1 (`Yao(isYang:)`). ✓
- Canonical corpus (seed 乾/坤, 卦辞+爻辞+用九/用六, nil degradation) → Task 3. ✓
- 本卦 → 变卦 side-by-side layout A (动爻 marked) → Task 4 (`hexagramColumn` + arrow). ✓
- 释文 toggle default off, appears only when 本卦 seeded, shows 本卦卦辞 + 动爻辞 + 变卦卦辞, 用九/用六 on all-6-change, 变卦 "（待补）" degradation, no gloss → Task 4 (`canonicalText`, `changingLines`). ✓
- Domain SceneKit-free + unit tests → Tasks 1–3. ✓

**Placeholder scan:** No TBD/TODO. "（待补）" is intentional UI degradation copy, not a plan gap. Seed text is complete verbatim (乾/坤) with a verify-against-source instruction. ✓

**Type consistency:** `Yao(isYang:)`, `Hexagram.resultingHexagram`, `HexagramText(guaCi:yaoCi:yong:)`, `ZhouYiCorpus.text(forNumber:)`, `changingLines(_:_:)`, `hexagramColumn(_:)` names/signatures match across tasks. `changingPositions` is 1-based (Task 2/4 index `yaoCi[$0 - 1]` consistent). `yaoRow` reused unchanged. ✓
