# 六爻 三钱法 Sub-project ① Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cast 6 Throws of 3 coins into a structurally correct Present Hexagram (本卦), shown as 卦号 + 卦名 + 6-Yao glyph with 动爻 marked, with both the Coin and 六爻 Rituals reachable from a minimal switcher.

**Architecture:** Generalize the single concrete `PhysicsScene` (ADR-0005, no protocol) from 1 coin to N coins; Coin uses N=1, 六爻 uses N=3. Divination meaning (faces → Yao → Hexagram) lives in a new pure domain layer + `IChingRitualViewModel`; `PhysicsScene`/`ThrowResult` stay meaning-free. A minimal `RootView` switches between the two Rituals.

**Tech Stack:** Swift 5, SwiftUI, SceneKit, XCTest. XcodeGen project (`project.yml` → `Luo.xcodeproj`, regenerate not commit).

## Global Constraints

- Language mode Swift 5 (`SWIFT_VERSION: "5.0"`), min deploy iOS 17, iPhone-only.
- Build/verify on **iPhone 17 / iOS 26.5** simulator (no iPhone 16 installed). Device-agnostic: `-destination 'generic/platform=iOS Simulator'`.
- Project is XcodeGen: after editing `project.yml`, run `xcodegen generate`; never commit `Luo.xcodeproj`.
- Visual tokens come from `Theme.swift` (Dusk Desk / DESIGN.md) — no hardcoded hex in views.
- Domain layer (`Yao`, `Hexagram`, `Trigram`, `KingWenTable`) imports **no SceneKit** — pure, unit-testable.
- Scope guard — ① does NOT implement: 变卦 (Resulting Hexagram), 卦辞/爻辞 text, Cast Log, on-device haptics tuning, Noto Serif SC. Those are ②/③.
- Yao mapping (CONTEXT.md, heads = 背 = 阳): 3 heads → 老阳 (yang, changing); 2 heads → 少阴 (yin); 1 head → 少阳 (yang); 0 heads → 老阴 (yin, changing).
- Hexagram bit order: 6 Yao bottom→top, index 0 = bottom = first Throw; yang = 1. 6-bit key = Σ (isYang ? 1<<i : 0).

---

### Task 1: Add XCTest unit-test target

**Files:**
- Modify: `project.yml` (add `LuoTests` target + a scheme wiring its test action)
- Create: `LuoTests/SmokeTests.swift`

**Interfaces:**
- Produces: a `LuoTests` target with `@testable import Luo`, runnable via `xcodebuild test -scheme Luo`.

- [ ] **Step 1: Write the failing test**

Create `LuoTests/SmokeTests.swift`:

```swift
import XCTest
@testable import Luo

final class SmokeTests: XCTestCase {
    func testHarnessRuns() {
        XCTAssertEqual(2 + 2, 4)
    }
}
```

- [ ] **Step 2: Add the test target to `project.yml`**

Append under `targets:` (sibling of the `Luo:` target), then add a top-level `schemes:` block:

```yaml
  LuoTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: LuoTests
    dependencies:
      - target: Luo
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.charliezong.luoTests
        GENERATE_INFOPLIST_FILE: YES

schemes:
  Luo:
    build:
      targets:
        Luo: all
    test:
      targets:
        - LuoTests
```

- [ ] **Step 3: Regenerate the project**

Run: `cd ~/Developer/Luo && xcodegen generate`
Expected: `Created project at .../Luo.xcodeproj`

- [ ] **Step 4: Run tests to verify the harness works**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, `testHarnessRuns` passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add project.yml LuoTests/SmokeTests.swift && git commit -m "test: add LuoTests XCTest target"
```

---

### Task 2: Yao domain type

**Files:**
- Create: `Luo/Yao.swift`
- Test: `LuoTests/YaoTests.swift`

**Interfaces:**
- Consumes: `CoinFace` (from `Luo/ThrowResult.swift` — `.heads` / `.tails`).
- Produces:
  - `enum YaoKind { case oldYin, youngYang, youngYin, oldYang }`
  - `struct Yao: Equatable { init(faces: [CoinFace]); var kind: YaoKind; var isYang: Bool; var isChanging: Bool; var glyph: String }`

- [ ] **Step 1: Write the failing test**

Create `LuoTests/YaoTests.swift`:

```swift
import XCTest
@testable import Luo

final class YaoTests: XCTestCase {
    private func yao(heads: Int) -> Yao {
        let faces = Array(repeating: CoinFace.heads, count: heads)
            + Array(repeating: CoinFace.tails, count: 3 - heads)
        return Yao(faces: faces)
    }

    func testThreeHeadsIsOldYang() {
        let y = yao(heads: 3)
        XCTAssertEqual(y.kind, .oldYang)
        XCTAssertTrue(y.isYang)
        XCTAssertTrue(y.isChanging)
    }

    func testTwoHeadsIsYoungYin() {
        let y = yao(heads: 2)
        XCTAssertEqual(y.kind, .youngYin)
        XCTAssertFalse(y.isYang)
        XCTAssertFalse(y.isChanging)
    }

    func testOneHeadIsYoungYang() {
        let y = yao(heads: 1)
        XCTAssertEqual(y.kind, .youngYang)
        XCTAssertTrue(y.isYang)
        XCTAssertFalse(y.isChanging)
    }

    func testZeroHeadsIsOldYin() {
        let y = yao(heads: 0)
        XCTAssertEqual(y.kind, .oldYin)
        XCTAssertFalse(y.isYang)
        XCTAssertTrue(y.isChanging)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `cannot find 'Yao' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Luo/Yao.swift`:

```swift
import Foundation

/// One of the 6 lines in a Hexagram, produced by one Throw of 3 coins.
/// Heads = 背 = 阳 (per CONTEXT.md 三钱法). Old (changing) Yao come from a
/// unanimous Throw (3 heads or 3 tails); young Yao from a 2:1 split.
enum YaoKind: Equatable {
    case oldYin      // 0 heads — yin, changing
    case youngYang   // 1 head  — yang
    case youngYin    // 2 heads — yin
    case oldYang     // 3 heads — yang, changing
}

struct Yao: Equatable {
    let kind: YaoKind

    init(faces: [CoinFace]) {
        let heads = faces.filter { $0 == .heads }.count
        switch heads {
        case 3:  kind = .oldYang
        case 2:  kind = .youngYin
        case 1:  kind = .youngYang
        default: kind = .oldYin   // 0 heads
        }
    }

    var isYang: Bool { kind == .oldYang || kind == .youngYang }
    var isChanging: Bool { kind == .oldYang || kind == .oldYin }

    /// Solid ⚊ (yang) or broken ⚋ (yin).
    var glyph: String { isYang ? "⚊" : "⚋" }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, all 4 `YaoTests` pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Yao.swift LuoTests/YaoTests.swift && git commit -m "feat: add Yao domain type (3-coin face count -> yao)"
```

---

### Task 3: Trigram + King Wen 64-table

**Files:**
- Create: `Luo/KingWenTable.swift`
- Test: `LuoTests/KingWenTableTests.swift`

**Interfaces:**
- Produces:
  - `enum Trigram { case qian, dui, li, zhen, xun, kan, gen, kun; var bits: Int }`
  - `struct HexagramInfo: Equatable { let number: Int; let name: String }`
  - `enum KingWenTable { static func info(forBits bits: Int) -> HexagramInfo }`  (bits 0…63, bottom-up yang=1)

**Implementation note:** the 64 `(number, name, lower, upper)` entries below are laid out in King Wen order (1 乾 … 64 未济). The permutation + anchor tests guard direction and completeness, but **verify each 卦名 against a canonical reference (通行本 / Wilhelm) during implementation** — a wrong name will pass the structural tests.

- [ ] **Step 1: Write the failing test**

Create `LuoTests/KingWenTableTests.swift`:

```swift
import XCTest
@testable import Luo

final class KingWenTableTests: XCTestCase {
    // bits helper: lines bottom→top, true = yang.
    private func bits(_ lines: [Bool]) -> Int {
        var v = 0
        for (i, yang) in lines.enumerated() where yang { v |= (1 << i) }
        return v
    }

    func testAllYangIsQian() {
        let info = KingWenTable.info(forBits: bits([true, true, true, true, true, true]))
        XCTAssertEqual(info.number, 1)
        XCTAssertEqual(info.name, "乾")
    }

    func testAllYinIsKun() {
        let info = KingWenTable.info(forBits: bits([false, false, false, false, false, false]))
        XCTAssertEqual(info.number, 2)
        XCTAssertEqual(info.name, "坤")
    }

    func testTaiIsLowerHeavenUpperEarth() {
        // 地天泰: bottom trigram all yang, top all yin.
        let info = KingWenTable.info(forBits: bits([true, true, true, false, false, false]))
        XCTAssertEqual(info.number, 11)
        XCTAssertEqual(info.name, "泰")
    }

    func testPiIsLowerEarthUpperHeaven() {
        let info = KingWenTable.info(forBits: bits([false, false, false, true, true, true]))
        XCTAssertEqual(info.number, 12)
        XCTAssertEqual(info.name, "否")
    }

    func testJiJiAlternatesFromYang() {
        // 既济 63: yang,yin,yang,yin,yang,yin (bottom→top).
        let info = KingWenTable.info(forBits: bits([true, false, true, false, true, false]))
        XCTAssertEqual(info.number, 63)
        XCTAssertEqual(info.name, "既济")
    }

    func testTableIsPermutationOf1to64() {
        let numbers = (0...63).map { KingWenTable.info(forBits: $0).number }.sorted()
        XCTAssertEqual(numbers, Array(1...64))
    }

    func testNamesAreDistinct() {
        let names = Set((0...63).map { KingWenTable.info(forBits: $0).name })
        XCTAssertEqual(names.count, 64)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `cannot find 'KingWenTable' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Luo/KingWenTable.swift`:

```swift
import Foundation

/// One of the 8 trigrams (bagua). `bits` encodes its 3 lines bottom→top,
/// yang = 1 (bit 0 = bottom line).
enum Trigram {
    case qian, dui, li, zhen, xun, kan, gen, kun

    var bits: Int {
        switch self {
        case .qian: return 0b111  // 乾 ☰
        case .dui:  return 0b011  // 兑 ☱  (yang, yang, yin)
        case .li:   return 0b101  // 离 ☲  (yang, yin, yang)
        case .zhen: return 0b001  // 震 ☳  (yang, yin, yin)
        case .xun:  return 0b110  // 巽 ☴  (yin, yang, yang)
        case .kan:  return 0b010  // 坎 ☵  (yin, yang, yin)
        case .gen:  return 0b100  // 艮 ☶  (yin, yin, yang)
        case .kun:  return 0b000  // 坤 ☷
        }
    }
}

struct HexagramInfo: Equatable {
    let number: Int
    let name: String
}

/// Maps a 6-bit hexagram key (bottom→top, yang = 1) to its King Wen number +
/// 卦名. Built once from the King Wen-ordered entry list; the 6-bit key of each
/// entry is (lower.bits | upper.bits << 3).
enum KingWenTable {

    /// (King Wen number, 卦名, lower trigram, upper trigram), in King Wen order.
    private static let entries: [(Int, String, Trigram, Trigram)] = [
        (1,  "乾",   .qian, .qian),
        (2,  "坤",   .kun,  .kun),
        (3,  "屯",   .zhen, .kan),
        (4,  "蒙",   .kan,  .gen),
        (5,  "需",   .qian, .kan),
        (6,  "讼",   .kan,  .qian),
        (7,  "师",   .kan,  .kun),
        (8,  "比",   .kun,  .kan),
        (9,  "小畜", .qian, .xun),
        (10, "履",   .dui,  .qian),
        (11, "泰",   .qian, .kun),
        (12, "否",   .kun,  .qian),
        (13, "同人", .li,   .qian),
        (14, "大有", .qian, .li),
        (15, "谦",   .gen,  .kun),
        (16, "豫",   .kun,  .zhen),
        (17, "随",   .zhen, .dui),
        (18, "蛊",   .xun,  .gen),
        (19, "临",   .dui,  .kun),
        (20, "观",   .kun,  .xun),
        (21, "噬嗑", .zhen, .li),
        (22, "贲",   .li,   .gen),
        (23, "剥",   .kun,  .gen),
        (24, "复",   .zhen, .kun),
        (25, "无妄", .zhen, .qian),
        (26, "大畜", .qian, .gen),
        (27, "颐",   .zhen, .gen),
        (28, "大过", .xun,  .dui),
        (29, "坎",   .kan,  .kan),
        (30, "离",   .li,   .li),
        (31, "咸",   .gen,  .dui),
        (32, "恒",   .xun,  .zhen),
        (33, "遁",   .gen,  .qian),
        (34, "大壮", .qian, .zhen),
        (35, "晋",   .kun,  .li),
        (36, "明夷", .li,   .kun),
        (37, "家人", .li,   .xun),
        (38, "睽",   .dui,  .li),
        (39, "蹇",   .gen,  .kan),
        (40, "解",   .kan,  .zhen),
        (41, "损",   .dui,  .gen),
        (42, "益",   .zhen, .xun),
        (43, "夬",   .qian, .dui),
        (44, "姤",   .xun,  .qian),
        (45, "萃",   .kun,  .dui),
        (46, "升",   .xun,  .kun),
        (47, "困",   .kan,  .dui),
        (48, "井",   .xun,  .kan),
        (49, "革",   .li,   .dui),
        (50, "鼎",   .xun,  .li),
        (51, "震",   .zhen, .zhen),
        (52, "艮",   .gen,  .gen),
        (53, "渐",   .gen,  .xun),
        (54, "归妹", .dui,  .zhen),
        (55, "丰",   .li,   .zhen),
        (56, "旅",   .gen,  .li),
        (57, "巽",   .xun,  .xun),
        (58, "兑",   .dui,  .dui),
        (59, "涣",   .kan,  .xun),
        (60, "节",   .dui,  .kan),
        (61, "中孚", .dui,  .xun),
        (62, "小过", .gen,  .zhen),
        (63, "既济", .li,   .kan),
        (64, "未济", .kan,  .li),
    ]

    private static let byBits: [Int: HexagramInfo] = {
        var map: [Int: HexagramInfo] = [:]
        for (number, name, lower, upper) in entries {
            let key = lower.bits | (upper.bits << 3)
            map[key] = HexagramInfo(number: number, name: name)
        }
        return map
    }()

    /// Look up the hexagram for a 6-bit key (0…63). The map is total over 0…63.
    static func info(forBits bits: Int) -> HexagramInfo {
        byBits[bits]!
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`. If `testTableIsPermutationOf1to64` fails, an entry's trigram pair is wrong (duplicate key); fix against the reference.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/KingWenTable.swift LuoTests/KingWenTableTests.swift && git commit -m "feat: add Trigram + King Wen 64-hexagram lookup table"
```

---

### Task 4: Hexagram domain type

**Files:**
- Create: `Luo/Hexagram.swift`
- Test: `LuoTests/HexagramTests.swift`

**Interfaces:**
- Consumes: `Yao` (Task 2), `KingWenTable` / `HexagramInfo` (Task 3).
- Produces:
  - `struct Hexagram: Equatable { init(yao: [Yao]); let yao: [Yao]; var presentBits: Int; var changingPositions: [Int]; var number: Int; var name: String }`
  - `changingPositions` is 1-based Yao indices (1 = bottom).

- [ ] **Step 1: Write the failing test**

Create `LuoTests/HexagramTests.swift`:

```swift
import XCTest
@testable import Luo

final class HexagramTests: XCTestCase {
    private func yao(heads: Int) -> Yao {
        Yao(faces: Array(repeating: CoinFace.heads, count: heads)
            + Array(repeating: CoinFace.tails, count: 3 - heads))
    }

    func testSixYoungYangIsQian() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 1), count: 6)) // all yang, none changing
        XCTAssertEqual(h.number, 1)
        XCTAssertEqual(h.name, "乾")
        XCTAssertEqual(h.presentBits, 0b111111)
        XCTAssertTrue(h.changingPositions.isEmpty)
    }

    func testSixYoungYinIsKun() {
        let h = Hexagram(yao: Array(repeating: yao(heads: 2), count: 6)) // all yin, none changing
        XCTAssertEqual(h.number, 2)
        XCTAssertEqual(h.name, "坤")
        XCTAssertEqual(h.presentBits, 0)
    }

    func testBottomUpOrderingIsTai() {
        // bottom 3 yang, top 3 yin -> 泰 (11).
        let yaos = [yao(heads: 1), yao(heads: 1), yao(heads: 1),
                    yao(heads: 2), yao(heads: 2), yao(heads: 2)]
        let h = Hexagram(yao: yaos)
        XCTAssertEqual(h.number, 11)
        XCTAssertEqual(h.name, "泰")
    }

    func testChangingPositionsAreOneBasedBottomUp() {
        // bottom Yao old-yang (changing), rest young; present is still all-... check positions.
        let yaos = [yao(heads: 3), yao(heads: 1), yao(heads: 1),
                    yao(heads: 1), yao(heads: 1), yao(heads: 0)]
        let h = Hexagram(yao: yaos)
        XCTAssertEqual(h.changingPositions, [1, 6]) // bottom old-yang, top old-yin
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `cannot find 'Hexagram' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Luo/Hexagram.swift`:

```swift
import Foundation

/// The Present Hexagram (本卦) read directly from 6 Throws. Yao are stored
/// bottom→top (index 0 = bottom = first Throw). ① renders 本卦 only; 变卦 and
/// canonical text are Sub-project ②.
struct Hexagram: Equatable {
    let yao: [Yao]

    /// Requires exactly 6 Yao.
    init(yao: [Yao]) {
        precondition(yao.count == 6, "A Hexagram needs exactly 6 Yao")
        self.yao = yao
    }

    /// 6-bit key, bottom→top, yang = 1 (bit 0 = bottom Yao).
    var presentBits: Int {
        var v = 0
        for (i, y) in yao.enumerated() where y.isYang { v |= (1 << i) }
        return v
    }

    /// 1-based positions (1 = bottom) of the Changing Yao.
    var changingPositions: [Int] {
        yao.enumerated().filter { $0.element.isChanging }.map { $0.offset + 1 }
    }

    private var info: HexagramInfo { KingWenTable.info(forBits: presentBits) }
    var number: Int { info.number }
    var name: String { info.name }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, all `HexagramTests` pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Hexagram.swift LuoTests/HexagramTests.swift && git commit -m "feat: add Hexagram domain type (6 Yao -> 本卦 + changing positions)"
```

---

### Task 5: Extend PhysicsScene to N coins (physics core + call-site updates)

This is the risky physics task. It changes the `onSettle` callback shape, so **both** existing call sites (`CoinRitualViewModel`, `HarnessView`) are updated in the same task to keep the app compiling and the Coin Ritual green. Physics *feel* tuning is deferred to Task 9.

**Files:**
- Modify: `Luo/PhysicsConfig.swift` (add `coinCount`, `spawnOffsets`, `.iChing`)
- Modify: `Luo/PhysicsScene.swift` (single coin → `[coinNode]`; `onSettle: ([ThrowResult]) -> Void`; all-coins settle)
- Modify: `Luo/CoinRitualViewModel.swift:handleSettle` (take `[ThrowResult]`, read `[0]`)
- Modify: `Luo/HarnessView.swift:ensureScene` (`onSettle: { _ in ... }` stays; signature now `[ThrowResult]`)

**Interfaces:**
- Produces: `PhysicsScene(config:onSettle:onStateChange:)` with `onSettle: ([ThrowResult]) -> Void`, emitting one `ThrowResult` per coin (`id` 0…count-1). `PhysicsConfig.iChing` (coinCount 3).
- Consumes: `ThrowResult`, `CoinFace`, `SettleState` (unchanged types).

- [ ] **Step 1: Add multi-coin fields to `PhysicsConfig`**

In `Luo/PhysicsConfig.swift`, add these fields (after `throwHorizontalJitter`, before `static let v1`):

```swift
    // Multi-coin (三钱法). Coin ritual = 1; I Ching = 3. `spawnOffsets` are the
    // per-coin rest positions in real-world units (x,z on the felt); an empty
    // array means "single coin at origin". Count must be >= coinCount when >1.
    var coinCount: Int = 1
    var spawnOffsets: [SIMD3<Double>] = []
```

Add `import simd` at the top of the file (for `SIMD3`). Then add the `.iChing` preset after `static let v1 = PhysicsConfig()`:

```swift
    /// Three-coin 三钱法 preset. Coins spawn spread across the felt so they don't
    /// interpenetrate at rest; collision *feel* is tuned later (Task 9).
    static let iChing: PhysicsConfig = {
        var c = PhysicsConfig()
        c.coinCount = 3
        c.spawnOffsets = [
            SIMD3(-0.05, 0, 0),
            SIMD3( 0.00, 0, 0.02),
            SIMD3( 0.05, 0, 0),
        ]
        return c
    }()
```

- [ ] **Step 2: Rewrite `PhysicsScene` for N coins**

In `Luo/PhysicsScene.swift`, make these changes:

Replace the stored coin property and settle-tracker fields:

```swift
    let scene = SCNScene()
    private var coinNodes: [SCNNode] = []
    private let tableNode: SCNNode

    private var config: PhysicsConfig
    private let onSettle: ([ThrowResult]) -> Void
    private let onStateChange: (SettleState) -> Void

    // Settle tracker (all coins must be still).
    private var belowThresholdSince: TimeInterval?
    private var throwStartTime: TimeInterval?
    private var currentState: SettleState = .idle
    // Per-coin previous-frame presentation state, for velocity-free stillness.
    private var lastPos: [simd_float3?] = []
    private var lastQuat: [simd_quatf?] = []
    private var lastTickTime: TimeInterval?
```

Change `init` signature + coin construction:

```swift
    init(config: PhysicsConfig,
         onSettle: @escaping ([ThrowResult]) -> Void,
         onStateChange: @escaping (SettleState) -> Void) {
        self.config = config
        self.onSettle = onSettle
        self.onStateChange = onStateChange
        self.tableNode = Self.makeTableNode()
        super.init()
        let count = max(1, config.coinCount)
        for i in 0..<count {
            let node = Self.makeCoinNode(config: config)
            node.name = "coin\(i)"
            node.position = Self.spawnPosition(config, index: i)
            coinNodes.append(node)
        }
        lastPos = Array(repeating: nil, count: count)
        lastQuat = Array(repeating: nil, count: count)
        buildScene()
        apply(config)
    }
```

Add a spawn-position helper (near `restY`):

```swift
    /// Rest position for coin `index`, in scaled scene units. Uses the config's
    /// spawn offset (x,z, real units) if present, else the origin.
    private static func spawnPosition(_ c: PhysicsConfig, index: Int) -> SCNVector3 {
        let off = index < c.spawnOffsets.count ? c.spawnOffsets[index] : SIMD3<Double>(0, 0, 0)
        return SCNVector3(CGFloat(off.x * scale),
                          CGFloat(restY(c)),
                          CGFloat(off.z * scale))
    }
```

In `buildScene()`, replace `scene.rootNode.addChildNode(coinNode)` with:

```swift
        for node in coinNodes { scene.rootNode.addChildNode(node) }
```

In `apply(_:)`, replace the single-coin body/visual updates with a loop over `coinNodes`:

```swift
        for coinNode in coinNodes {
            if let body = coinNode.physicsBody {
                body.mass = CGFloat(config.coinMass)
                body.restitution = CGFloat(config.restitution)
                body.friction = CGFloat(config.friction)
                body.rollingFriction = CGFloat(config.rollingFriction)
                body.damping = CGFloat(config.linearDamping)
                body.angularDamping = CGFloat(config.angularDamping)
            }
            if let cyl = coinNode.childNode(withName: "coinVisual", recursively: false)?
                .geometry as? SCNCylinder {
                cyl.radius = CGFloat(config.coinRadius * Self.scale)
                cyl.height = CGFloat(config.coinThickness * Self.scale)
            }
        }
```

Rewrite `reset()`, `performThrow()`, `applyShake()` to loop over coins:

```swift
    func reset() {
        for (i, coinNode) in coinNodes.enumerated() {
            guard let body = coinNode.physicsBody else { continue }
            body.clearAllForces()
            body.velocity = SCNVector3Zero
            body.angularVelocity = SCNVector4Zero
            coinNode.position = Self.spawnPosition(config, index: i)
            coinNode.eulerAngles = SCNVector3Zero
            body.resetTransform()
        }
        belowThresholdSince = nil
        throwStartTime = nil
        lastPos = Array(repeating: nil, count: coinNodes.count)
        lastQuat = Array(repeating: nil, count: coinNodes.count)
        publishState(.idle)
    }

    func performThrow() {
        reset()
        for coinNode in coinNodes {
            guard let body = coinNode.physicsBody else { continue }
            let jitter = Double.random(in: -config.throwHorizontalJitter...config.throwHorizontalJitter)
            let jitter2 = Double.random(in: -config.throwHorizontalJitter...config.throwHorizontalJitter)
            body.applyForce(SCNVector3(CGFloat(jitter),
                                       CGFloat(config.throwLinearImpulse),
                                       CGFloat(jitter2)), asImpulse: true)
            let theta = Double.random(in: 0 ..< 2 * Double.pi)
            body.applyTorque(SCNVector4(CGFloat(cos(theta)), 0, CGFloat(sin(theta)),
                                        CGFloat(config.throwAngularImpulse)), asImpulse: true)
        }
        publishState(.throwing)
    }

    func applyShake(magnitude: Double) {
        let scaled = min(magnitude, 5.0) * config.throwLinearImpulse
        for coinNode in coinNodes {
            coinNode.physicsBody?.applyForce(SCNVector3(0, CGFloat(scaled), 0), asImpulse: true)
        }
        publishState(.throwing)
    }
```

Rewrite `tickSettle(time:)` to require **all** coins still, and emit one result per coin:

```swift
    private func tickSettle(time: TimeInterval) {
        guard !coinNodes.isEmpty else { return }
        var allStill = true
        var haveHistory = lastTickTime != nil
        let dt = Float(time - (lastTickTime ?? time))

        for (i, coinNode) in coinNodes.enumerated() {
            let pres = coinNode.presentation
            let p = pres.simdWorldTransform.columns.3
            let posV = simd_float3(p.x, p.y, p.z)
            let quat = pres.simdOrientation
            if haveHistory, dt > 0, let lp = lastPos[i], let lq = lastQuat[i] {
                let linSpeed = Double(simd_length(posV - lp) / dt) / Self.scale
                let dotq = min(1, abs(simd_dot(quat.vector, lq.vector)))
                let angSpeed = Double(2 * acos(dotq) / dt)
                if !(linSpeed < config.settleLinearThreshold && angSpeed < config.settleAngularThreshold) {
                    allStill = false
                }
            } else {
                allStill = false
            }
            lastPos[i] = posV
            lastQuat[i] = quat
        }
        lastTickTime = time
        if !haveHistory { return }

        let inFlight = currentState == .throwing || currentState == .settling
        guard inFlight else {
            if !allStill, isSettledState(currentState) { publishState(.throwing) }
            return
        }

        if throwStartTime == nil { throwStartTime = time }
        let timedOut = time - (throwStartTime ?? time) >= config.settleTimeout

        if allStill {
            if currentState == .throwing { publishState(.settling) }
            if belowThresholdSince == nil { belowThresholdSince = time }
        } else {
            belowThresholdSince = nil
        }
        let heldStill = belowThresholdSince.map { time - $0 >= config.settleHoldSeconds } ?? false

        if heldStill || timedOut {
            let results = makeResults()
            belowThresholdSince = nil
            throwStartTime = nil
            publishState(.settled(results.first?.faceUp ?? .heads))
            onSettle(results)
        }
    }
```

Replace `settledFace()` / `makeResult(face:)` with per-coin versions:

```swift
    private func face(of coinNode: SCNNode) -> CoinFace {
        coinNode.presentation.simdWorldTransform.columns.1.y >= 0 ? .heads : .tails
    }

    private func makeResults() -> [ThrowResult] {
        coinNodes.enumerated().map { (i, coinNode) in
            let m = coinNode.presentation.simdWorldTransform
            let p = m.columns.3
            let realPos = simd_float3(p.x, p.y, p.z) / Float(Self.scale)
            return ThrowResult(id: i,
                               position: realPos,
                               orientation: coinNode.presentation.simdOrientation,
                               faceUp: face(of: coinNode))
        }
    }
```

- [ ] **Step 3: Update the two call sites**

In `Luo/CoinRitualViewModel.swift`, change `handleSettle` to take an array:

```swift
    private func handleSettle(_ results: [ThrowResult]) {
        guard let first = results.first else { return }
        haptics.playSettleThunk()
        state = .result(Yinyang(first.faceUp))
        hasCast = true
    }
```

And its lazy scene initializer callback (the closure arg is now an array):

```swift
    lazy var scene: PhysicsScene = PhysicsScene(
        config: .v1,
        onSettle: { [weak self] results in self?.handleSettle(results) },
        onStateChange: { [weak self] s in self?.handleStateChange(s) }
    )
```

In `Luo/HarnessView.swift:ensureScene`, the `onSettle` closure already ignores its argument — just keep it; it now receives `[ThrowResult]`:

```swift
        scene = PhysicsScene(
            config: params.makeConfig(),
            onSettle: { _ in haptics.playSettleThunk() },
            onStateChange: { newState in
                Task { @MainActor in settleState = newState }
            }
        )
```

- [ ] **Step 4: Build to verify everything compiles + Coin regression**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Headless 3-coin settle check (no eyes on animation)**

Add a temporary probe at the top of `tickSettle`'s settle branch — inside `if heldStill || timedOut {` before `onSettle(results)`:

```swift
            NSLog("LUO_DEBUG settle coins=\(results.count) faces=\(results.map { $0.faceUp.label }.joined()) timedOut=\(timedOut)")
```

Temporarily root the app into a 3-coin scene by pointing the Coin VM at `.iChing` (revert after): in `CoinRitualViewModel`, change `config: .v1` → `config: .iChing`. Then:

```bash
cd ~/Developer/Luo
xcodebuild -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
[ -z "$UDID" ] && UDID=$(xcrun simctl list devices available | grep 'iPhone 17 ' | grep -oE '[0-9A-F-]{36}' | head -1) && xcrun simctl boot "$UDID"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name Luo.app -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.charliezong.luo
sleep 2
# tap the 掷 button region a couple times, then read the probe:
xcrun simctl spawn "$UDID" log show --last 20s --predicate 'eventMessage CONTAINS "LUO_DEBUG"' | grep -oE 'LUO_DEBUG.*'
```

Expected: at least one `LUO_DEBUG settle coins=3 faces=... timedOut=0` line (3 coins, settled without hitting the timeout). If `timedOut=1` every time, coins aren't stilling — note it for Task 9 but do not block (the aggregation is still correct).

- [ ] **Step 6: Remove the probe + revert the temporary `.iChing` root**

Delete the `NSLog("LUO_DEBUG …")` line and revert `CoinRitualViewModel` back to `config: .v1`. Confirm clean:

Run: `cd ~/Developer/Luo && grep -rn 'LUO_DEBUG' Luo/ ; grep -n 'config: .iChing' Luo/CoinRitualViewModel.swift`
Expected: no output from either grep.

- [ ] **Step 7: Commit**

```bash
cd ~/Developer/Luo && git add Luo/PhysicsConfig.swift Luo/PhysicsScene.swift Luo/CoinRitualViewModel.swift Luo/HarnessView.swift && git commit -m "feat: extend PhysicsScene to N coins; onSettle emits [ThrowResult]"
```

---

### Task 6: IChingRitualViewModel (6-Throw accumulation)

**Files:**
- Create: `Luo/IChingRitualViewModel.swift`
- Test: `LuoTests/IChingRitualViewModelTests.swift`

**Interfaces:**
- Consumes: `Yao`, `Hexagram` (domain); `PhysicsScene(config: .iChing)`, `ThrowResult`, `CoinFace`, `SettleState`.
- Produces:
  - `enum IChingCastState: Equatable { case idle, casting, complete(Hexagram) }`
  - `IChingRitualViewModel: ObservableObject` with `@Published state`, `@Published castYao: [Yao]`, `func cast()`, `func reset()`, `func appendThrow(_ faces: [CoinFace])` (pure accumulation seam), `func startMotion()`, `func stopMotion()`, `var scene`.

- [ ] **Step 1: Write the failing test**

Create `LuoTests/IChingRitualViewModelTests.swift`:

```swift
import XCTest
@testable import Luo

@MainActor
final class IChingRitualViewModelTests: XCTestCase {
    private let youngYang = [CoinFace.heads, .tails, .tails]  // 1 head -> yang
    private let youngYin  = [CoinFace.heads, .heads, .tails]  // 2 heads -> yin

    func testSixYoungYangThrowsCompleteAsQian() {
        let vm = IChingRitualViewModel()
        for _ in 0..<6 { vm.appendThrow(youngYang) }
        guard case .complete(let hex) = vm.state else {
            return XCTFail("expected .complete, got \(vm.state)")
        }
        XCTAssertEqual(hex.number, 1)
        XCTAssertEqual(hex.name, "乾")
        XCTAssertEqual(vm.castYao.count, 6)
    }

    func testStaysIdleBetweenThrows() {
        let vm = IChingRitualViewModel()
        vm.appendThrow(youngYang)
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.castYao.count, 1)
    }

    func testResetClearsAccumulation() {
        let vm = IChingRitualViewModel()
        for _ in 0..<3 { vm.appendThrow(youngYin) }
        vm.reset()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertTrue(vm.castYao.isEmpty)
    }

    func testSeventhThrowIsIgnored() {
        let vm = IChingRitualViewModel()
        for _ in 0..<6 { vm.appendThrow(youngYang) }
        vm.appendThrow(youngYin) // ignored once complete
        XCTAssertEqual(vm.castYao.count, 6)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: FAIL — `cannot find 'IChingRitualViewModel' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Luo/IChingRitualViewModel.swift`:

```swift
import SwiftUI
import SceneKit

/// What the 六爻 screen is showing.
enum IChingCastState: Equatable {
    case idle                 // ready for the next Throw (0…5 Yao cast)
    case casting              // coins in flight
    case complete(Hexagram)   // 6 Yao cast; 本卦 revealed
}

/// Drives the I Ching 六爻 三钱法 Ritual: 6 Throws of 3 coins, each aggregated
/// into one Yao bottom-up, into the Present Hexagram (本卦). Divination meaning
/// lives here; `PhysicsScene`/`ThrowResult` stay meaning-free.
@MainActor
final class IChingRitualViewModel: ObservableObject {
    @Published private(set) var state: IChingCastState = .idle
    @Published private(set) var castYao: [Yao] = []

    private let haptics = HapticsService()
    private let motion = MotionService()

    lazy var scene: PhysicsScene = PhysicsScene(
        config: .iChing,
        onSettle: { [weak self] results in self?.handleSettle(results) },
        onStateChange: { [weak self] s in self?.handleStateChange(s) }
    )

    var isComplete: Bool { if case .complete = state { return true }; return false }

    /// Throw the next Yao (tap or shake). No-op while casting or complete.
    func cast() {
        guard state != .casting, !isComplete else { return }
        scene.performThrow()
        state = .casting
    }

    func reset() {
        castYao = []
        state = .idle
        scene.reset()
    }

    /// Pure accumulation seam — aggregate one Throw's 3 faces into a Yao and
    /// advance. Unit-tested without the scene.
    func appendThrow(_ faces: [CoinFace]) {
        guard castYao.count < 6 else { return }
        castYao.append(Yao(faces: faces))
        state = castYao.count == 6 ? .complete(Hexagram(yao: castYao)) : .idle
    }

    func startMotion() {
        motion.start { [weak self] mag in self?.scene.applyShake(magnitude: mag) }
    }
    func stopMotion() { motion.stop() }

    // MARK: - PhysicsScene callbacks

    private func handleSettle(_ results: [ThrowResult]) {
        haptics.playSettleThunk()
        appendThrow(results.map { $0.faceUp })
    }

    private func handleStateChange(_ s: SettleState) {
        switch s {
        case .throwing, .settling:
            if state != .casting { state = .casting }
        case .idle, .settled:
            break
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, all `IChingRitualViewModelTests` pass.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/IChingRitualViewModel.swift LuoTests/IChingRitualViewModelTests.swift && git commit -m "feat: add IChingRitualViewModel (6-throw accumulation -> 本卦)"
```

---

### Task 7: IChingRitualView (screen)

**Files:**
- Create: `Luo/IChingRitualView.swift`

**Interfaces:**
- Consumes: `IChingRitualViewModel`, `Hexagram`, `Yao`, `Theme`.
- Produces: `IChingRitualView` (SwiftUI `View`).

- [ ] **Step 1: Write the view**

Create `Luo/IChingRitualView.swift`:

```swift
import SwiftUI
import SceneKit

/// 六爻 三钱法 Ritual screen. Scene (3 coins) fills the top; the cast Yao stack
/// grows bottom-up as each Throw settles; one cinnabar 掷 button advances. On the
/// 6th Yao the 本卦 (卦号 + 卦名 + 6-Yao glyph, 动爻 marked) fades in. 再占 resets.
struct IChingRitualView: View {
    @StateObject private var vm = IChingRitualViewModel()

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            SceneView(scene: vm.scene.scene, options: [], delegate: vm.scene)
                .ignoresSafeArea()

            VStack {
                hint
                Spacer()
                if case .complete(let hex) = vm.state {
                    hexagramResult(hex)
                } else {
                    yaoStack
                }
                Spacer()
                castButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .animation(.easeInOut(duration: 0.35), value: vm.state)
        .animation(.easeInOut(duration: 0.35), value: vm.castYao.count)
        .onAppear { vm.startMotion() }
        .onDisappear { vm.stopMotion() }
    }

    private var hint: some View {
        Text(hintText)
            .font(Theme.serif(17))
            .foregroundColor(Theme.ink.opacity(vm.castYao.isEmpty ? 0.6 : 0.3))
    }

    private var hintText: String {
        switch vm.state {
        case .complete: return " "
        default:        return vm.castYao.isEmpty ? "心中默念所问" : "第 \(vm.castYao.count + 1) 爻"
        }
    }

    /// Cast Yao so far, bottom-up (newest on top of the stack visually = top row
    /// is the highest Yao index; we render top→bottom = Yao 6→1).
    private var yaoStack: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.castYao.enumerated().reversed()), id: \.offset) { _, yao in
                yaoRow(yao)
            }
        }
    }

    private func yaoRow(_ yao: Yao) -> some View {
        HStack(spacing: 10) {
            Text(yao.glyph)
                .font(Theme.serif(30))
                .foregroundColor(Theme.ink)
            if yao.isChanging {
                Circle().stroke(Theme.cinnabar, lineWidth: 1.5).frame(width: 8, height: 8)
            }
        }
    }

    private func hexagramResult(_ hex: Hexagram) -> some View {
        VStack(spacing: 14) {
            Text("第 \(hex.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))
            Text(hex.name)
                .font(Theme.serif(72, weight: .medium))
                .foregroundColor(Theme.ink)
            VStack(spacing: 6) {
                ForEach(Array(hex.yao.enumerated().reversed()), id: \.offset) { _, yao in
                    yaoRow(yao)
                }
            }
            .padding(.top, 6)
        }
        .transition(.opacity)
    }

    private var castButton: some View {
        Button(action: buttonAction) {
            Text(buttonLabel)
                .font(Theme.serif(20, weight: .medium))
                .foregroundColor(Theme.deskBackground)
                .frame(width: 120, height: 52)
                .background(Theme.cinnabar)
                .clipShape(Capsule())
                .opacity(vm.state == .casting ? 0.4 : 1)
        }
        .disabled(vm.state == .casting)
    }

    private var buttonLabel: String {
        if vm.isComplete { return "再占" }
        return "掷"
    }

    private func buttonAction() {
        if vm.isComplete { vm.reset() } else { vm.cast() }
    }
}

#Preview {
    IChingRitualView()
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/Luo && git add Luo/IChingRitualView.swift && git commit -m "feat: add IChingRitualView (yao stack + 本卦 result)"
```

---

### Task 8: RootView switcher + app entry

**Files:**
- Create: `Luo/RootView.swift`
- Modify: `Luo/LuoApp.swift` (root into `RootView`)

**Interfaces:**
- Consumes: `CoinRitualView`, `IChingRitualView`, `Theme`.
- Produces: `RootView`.

- [ ] **Step 1: Write the switcher**

Create `Luo/RootView.swift`:

```swift
import SwiftUI

/// Minimal Ritual switcher — the two v1 Rituals reachable from one screen.
/// A real home is a later concern; this just makes both entries exist.
struct RootView: View {
    private enum Ritual { case coin, iching }
    @State private var ritual: Ritual?

    var body: some View {
        switch ritual {
        case .coin:
            ritualContainer { CoinRitualView() }
        case .iching:
            ritualContainer { IChingRitualView() }
        case nil:
            picker
        }
    }

    private var picker: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                Text("落")
                    .font(Theme.serif(64, weight: .medium))
                    .foregroundColor(Theme.ink)
                    .padding(.bottom, 12)
                entryButton("六爻") { ritual = .iching }
                entryButton("掷币") { ritual = .coin }
            }
        }
    }

    private func entryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.serif(24))
                .foregroundColor(Theme.ink)
                .frame(width: 200, height: 64)
                .overlay(Capsule().stroke(Theme.ink.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func ritualContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack(alignment: .topLeading) {
            content()
            Button(action: { ritual = nil }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.ink.opacity(0.7))
                    .padding(12)
            }
            .padding(.top, 8)
            .padding(.leading, 8)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 2: Root the app into `RootView`**

Replace the body of `Luo/LuoApp.swift`:

```swift
import SwiftUI

@main
struct LuoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 3: Build + screenshot the picker and the 六爻 screen**

Run:

```bash
cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
[ -z "$UDID" ] && UDID=$(xcrun simctl list devices available | grep 'iPhone 17 ' | grep -oE '[0-9A-F-]{36}' | head -1) && xcrun simctl boot "$UDID"
APP=$(find ~/Library/Developer/Xcode/DerivedData -name Luo.app -path '*Debug-iphonesimulator*' | head -1)
xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.charliezong.luo
sleep 2 && xcrun simctl io "$UDID" screenshot /tmp/luo-picker.png
```

Then Read `/tmp/luo-picker.png` — expect the 落 picker with 六爻 / 掷币 entries. (Tapping 六爻 → the ritual screen; the chevron returns.)

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/Luo && git add Luo/RootView.swift Luo/LuoApp.swift && git commit -m "feat: add RootView ritual switcher; app roots into it"
```

---

### Task 9: (Closing, tracked) 三钱物理精调

Not a milestone blocker — the "掷出正确本卦" milestone is already green after Task 8. This task tunes the *feel* of three coins landing together.

**Files:**
- Modify: `Luo/PhysicsConfig.swift` (`.iChing` spawn spacing / settle constants)
- Possibly modify: `Luo/PhysicsScene.swift` (tray size for 3 coins)

- [ ] **Step 1:** Root the app temporarily into the 六爻 screen (or navigate there), throw repeatedly on the simulator, and use the `LUO_DEBUG` probe loop from Task 5 / [[feedback-luo-scenekit-debug-workflow]] to watch: do coins overlap at spawn? does any coin roll off / jitter forever? does `timedOut=1` ever fire?
- [ ] **Step 2:** Adjust `.iChing.spawnOffsets` spacing, tray span in `makeTableNode` (currently 0.3 m — may need widening for 3 coins), and the settle thresholds if 3-body noise trips them. Re-run the probe loop until settles are clean and `timedOut=0`.
- [ ] **Step 3:** Strip probes (`grep -rn 'LUO_DEBUG' Luo/` → empty), rebuild, commit.

```bash
cd ~/Developer/Luo && git add Luo/PhysicsConfig.swift Luo/PhysicsScene.swift && git commit -m "tune: 三钱 3-coin spawn spacing + settle feel"
```

---

## Self-Review

**Spec coverage:**
- 3-coin PhysicsScene (approach C) → Task 5 (+ Task 9 tuning). ✓
- 6-Throw accumulation → Task 6. ✓
- Yao mapping (heads=背=阳, 4 cases) → Task 2. ✓
- Hexagram + King Wen number/name, bottom-up, 动爻 → Tasks 3, 4. ✓
- Result screen 本卦 only (号+名+爻图+动爻 marked), no 变卦/text → Task 7. ✓
- Minimal switcher, both reachable → Task 8. ✓
- Coin regression (VM reads `[0]`) → Task 5 step 3–4. ✓
- Tests: Yao/Hexagram/table units + headless 3-coin + Coin regression → Tasks 2–6. ✓
- Deferred (变卦/corpus/Cast Log) → not implemented, per scope guard. ✓

**Placeholder scan:** No TBD/TODO; every code step has full code. King Wen table is fully populated (64 entries) with a verify-against-reference note. ✓

**Type consistency:** `onSettle: ([ThrowResult]) -> Void` used identically in Task 5 (definition) and Tasks 5/6 (call sites). `Yao(faces:)`, `Hexagram(yao:)`, `KingWenTable.info(forBits:)`, `IChingCastState`, `appendThrow(_:)` names match across tasks. `changingPositions` (Hexagram) vs `isChanging` (Yao) are distinct and used consistently. ✓
