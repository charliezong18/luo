# 六爻 Sub-project ③ Implementation Plan (Cast Log 持久化, SwiftData)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Auto-save every I Ching Cast to a local SwiftData Cast Log with a browsable list, a detail view (本卦→变卦 + 释文 + editable 提问/笔记), and delete.

**Architecture:** Add two pure domain reconstructors (`Yao(isYang:isChanging:)`, `Hexagram(presentBits:changingMask:)`); a SwiftData `@Model CastRecord` storing Identifier fields only; extract the ② result rendering into a shared `HexagramPairView`; add `CastLogListView`/`CastLogDetailView` and a 占卜记录 `RootView` entry; auto-save on cast completion. Reads via `@Query`, writes/deletes via `modelContext`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest. XcodeGen (`project.yml` → regenerate not commit).

## Global Constraints

- Swift 5 (`SWIFT_VERSION: "5.0"`), min deploy iOS 17, iPhone-only. SwiftData is iOS 17+ (system framework — just `import SwiftData`, no dependency to add).
- Build/test on **iPhone 17 / iOS 26.5** simulator. Test: `xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`.
- New files under `Luo/`/`LuoTests/` require `xcodegen generate` before they compile.
- Domain (`Yao`, `Hexagram`) imports no SceneKit/SwiftData — pure, unit-tested.
- Store **Identifier fields only** (`presentBits`, `changingMask`, timestamp, question?, note?); text looked up from `ZhouYiCorpus` at view time (ADR-0004). No number stored.
- Bit convention (from ①): bit i (0-based) = Yao at position i (0 = bottom); yang = 1. `changingPositions` are 1-based → bit `pos-1`.
- Visual tokens via `Theme.swift` only — no hardcoded hex.
- Out of scope: Coin "save this Cast", cloud/account/export/share/search, Noto Serif SC.

---

### Task 1: `Yao(isYang:isChanging:)` full factory

**Files:** Modify `Luo/Yao.swift`; Test `LuoTests/YaoTests.swift` (extend).

**Interfaces:** Produces `Yao.init(isYang: Bool, isChanging: Bool)` → `.oldYang`/`.youngYang`/`.oldYin`/`.youngYin`.

- [ ] **Step 1: Failing test** — append to `LuoTests/YaoTests.swift`:

```swift
    func testFullFactoryAllCombos() {
        XCTAssertEqual(Yao(isYang: true,  isChanging: true).kind,  .oldYang)
        XCTAssertEqual(Yao(isYang: true,  isChanging: false).kind, .youngYang)
        XCTAssertEqual(Yao(isYang: false, isChanging: true).kind,  .oldYin)
        XCTAssertEqual(Yao(isYang: false, isChanging: false).kind, .youngYin)
        XCTAssertTrue(Yao(isYang: true, isChanging: true).isChanging)
        XCTAssertFalse(Yao(isYang: false, isChanging: false).isChanging)
    }
```

- [ ] **Step 2: Run — expect FAIL** (`extra argument 'isChanging'`).

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -12`

- [ ] **Step 3: Implement** — add to `struct Yao` in `Luo/Yao.swift`:

```swift
    /// Full factory covering both axes — used to reconstruct a stored Cast's
    /// exact lines (polarity + whether it was a 动爻) from the Cast Log.
    init(isYang: Bool, isChanging: Bool) {
        switch (isYang, isChanging) {
        case (true, true):   kind = .oldYang
        case (true, false):  kind = .youngYang
        case (false, true):  kind = .oldYin
        case (false, false): kind = .youngYin
        }
    }
```

- [ ] **Step 4: Run — expect PASS.**

Run: `cd ~/Developer/Luo && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -12`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Yao.swift LuoTests/YaoTests.swift && git commit -m "feat: add Yao(isYang:isChanging:) full factory for Cast Log reconstruction"
```

---

### Task 2: `Hexagram(presentBits:changingMask:)` reconstruction

**Files:** Modify `Luo/Hexagram.swift`; Test `LuoTests/HexagramTests.swift` (extend).

**Interfaces:** Consumes `Yao(isYang:isChanging:)` (Task 1). Produces `Hexagram.init(presentBits: Int, changingMask: Int)` — reconstructs the 6 lines from the two Ints.

- [ ] **Step 1: Failing test** — append to `LuoTests/HexagramTests.swift`:

```swift
    func testReconstructRoundTrips() {
        // 乾 bottom old-yang + 5 young-yang → 姤 #44 变卦, 动爻 at position 1.
        let original = Hexagram(yao: [yao(heads: 3)] + Array(repeating: yao(heads: 1), count: 5))
        let rebuilt = Hexagram(presentBits: original.presentBits, changingMask: 0b000001)
        XCTAssertEqual(rebuilt.number, original.number)          // 乾 #1
        XCTAssertEqual(rebuilt.name, original.name)
        XCTAssertEqual(rebuilt.changingPositions, [1])
        XCTAssertEqual(rebuilt.resultingHexagram?.number, 44)    // 姤
    }
```

- [ ] **Step 2: Run — expect FAIL** (`extra argument 'presentBits'`).

- [ ] **Step 3: Implement** — add to `struct Hexagram` in `Luo/Hexagram.swift`, after the existing `init(yao:)`:

```swift
    /// Reconstruct a Hexagram from stored Identifier fields (Cast Log). Bit i
    /// (0 = bottom) of `presentBits` is yang; bit i of `changingMask` is a 动爻.
    init(presentBits: Int, changingMask: Int) {
        let lines = (0..<6).map { i in
            Yao(isYang: presentBits & (1 << i) != 0,
                isChanging: changingMask & (1 << i) != 0)
        }
        self.init(yao: lines)
    }
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/Hexagram.swift LuoTests/HexagramTests.swift && git commit -m "feat: add Hexagram(presentBits:changingMask:) reconstruction"
```

---

### Task 3: `CastRecord` SwiftData model + in-memory store test

**Files:** Create `Luo/CastRecord.swift`; Test `LuoTests/CastRecordTests.swift`.

**Interfaces:** Consumes `Hexagram` (`presentBits`, `changingPositions`, `init(presentBits:changingMask:)`). Produces `@Model final class CastRecord` with `timestamp/presentBits/changingMask/question/note`, `init(from: Hexagram, at: Date)`, and computed `var hexagram: Hexagram`.

- [ ] **Step 1: Failing test** — create `LuoTests/CastRecordTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Luo

@MainActor
final class CastRecordTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CastRecord.self, configurations: config)
        return ModelContext(container)
    }

    private func qianAllChanging() -> Hexagram {
        Hexagram(yao: Array(repeating: Yao(faces: [.heads, .heads, .heads]), count: 6))
    }

    func testInsertFetchReconstructs() throws {
        let ctx = try makeContext()
        ctx.insert(CastRecord(from: qianAllChanging(), at: Date(timeIntervalSince1970: 0)))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CastRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.hexagram.number, 1)                     // 乾
        XCTAssertEqual(all.first?.hexagram.changingPositions.count, 6)
    }

    func testDeleteAndDeleteAll() throws {
        let ctx = try makeContext()
        for _ in 0..<3 { ctx.insert(CastRecord(from: qianAllChanging(), at: Date(timeIntervalSince1970: 0))) }
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CastRecord>())
        ctx.delete(all[0]); try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CastRecord>()).count, 2)
        try ctx.fetch(FetchDescriptor<CastRecord>()).forEach(ctx.delete); try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CastRecord>()).count, 0)
    }
}
```

- [ ] **Step 2: Run — expect FAIL** (`cannot find 'CastRecord' in scope`). Run `xcodegen generate` first so the new test file is in the target.

Run: `cd ~/Developer/Luo && xcodegen generate >/dev/null && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -12`

- [ ] **Step 3: Implement** — create `Luo/CastRecord.swift`:

```swift
import Foundation
import SwiftData

/// One saved I Ching Cast (ADR-0003 Cast Log). Stores Identifier fields only —
/// `presentBits` + `changingMask` fully determine 卦号/卦名/动爻/变卦; canonical
/// text is looked up from `ZhouYiCorpus` at view time (ADR-0004), so the corpus
/// can grow without rewriting old records.
@Model
final class CastRecord {
    var timestamp: Date
    var presentBits: Int
    var changingMask: Int
    var question: String?
    var note: String?

    init(timestamp: Date, presentBits: Int, changingMask: Int,
         question: String? = nil, note: String? = nil) {
        self.timestamp = timestamp
        self.presentBits = presentBits
        self.changingMask = changingMask
        self.question = question
        self.note = note
    }

    convenience init(from hexagram: Hexagram, at date: Date) {
        var mask = 0
        for pos in hexagram.changingPositions { mask |= (1 << (pos - 1)) }
        self.init(timestamp: date, presentBits: hexagram.presentBits, changingMask: mask)
    }

    /// Reconstruct the full Hexagram for display.
    var hexagram: Hexagram {
        Hexagram(presentBits: presentBits, changingMask: changingMask)
    }
}
```

- [ ] **Step 4: Run — expect PASS.**

Run: `cd ~/Developer/Luo && xcodegen generate >/dev/null && xcodebuild test -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' 2>&1 | tail -12`

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/CastRecord.swift LuoTests/CastRecordTests.swift && git commit -m "feat: add CastRecord SwiftData model (Identifier-only, reconstructable)"
```

---

### Task 4: Extract `HexagramPairView` (shared result rendering)

Refactor: move the ② 本卦→变卦 + 释文 rendering out of `IChingRitualView` into a reusable `HexagramPairView`, so the ritual result and the Cast Log detail render identically. Appearance must not change (screenshot must match ②).

**Files:** Create `Luo/HexagramPairView.swift`; Modify `Luo/IChingRitualView.swift`.

**Interfaces:** Produces `HexagramPairView(hexagram: Hexagram, showText: Binding<Bool>)`. Consumes `Hexagram`, `Yao`, `ZhouYiCorpus`, `HexagramText`, `Theme`.

- [ ] **Step 1: Create `Luo/HexagramPairView.swift`** (the four helpers are moved verbatim from `IChingRitualView`):

```swift
import SwiftUI

/// Shared rendering of a completed 六爻 result: 第 N 卦 header, 本卦 → 变卦 columns
/// (动爻 marked with cinnabar rings), and the 释文 canonical-text toggle. Used by
/// both the ritual result screen and the Cast Log detail. `showText` is owned by
/// the host so each screen keeps its own expand/collapse state.
struct HexagramPairView: View {
    let hexagram: Hexagram
    @Binding var showText: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("第 \(hexagram.number) 卦")
                .font(Theme.serif(16))
                .foregroundColor(Theme.ink.opacity(0.6))

            HStack(alignment: .center, spacing: 18) {
                hexagramColumn(hexagram)
                if let resulting = hexagram.resultingHexagram {
                    Text("→")
                        .font(Theme.serif(30))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    hexagramColumn(resulting)
                }
            }

            if ZhouYiCorpus.text(forNumber: hexagram.number) != nil {
                Button(action: { showText.toggle() }) {
                    Text(showText ? "释文 ▴" : "释文 ▾")
                        .font(Theme.serif(15))
                        .foregroundColor(Theme.cinnabar)
                }
                if showText { canonicalText(hexagram) }
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

    private func changingLines(_ hex: Hexagram, _ t: HexagramText) -> [String] {
        if hex.changingPositions.count == 6, let yong = t.yong { return [yong] }
        return hex.changingPositions.map { t.yaoCi[$0 - 1] }
    }
}
```

- [ ] **Step 2: Replace the moved helpers in `Luo/IChingRitualView.swift`** — DELETE `hexagramColumn(_:)`, `canonicalText(_:)`, `changingLines(_:_:)`, and `yaoRow(_:)` from `IChingRitualView` (they now live in `HexagramPairView`; confirm `yaoRow` has no other caller — `tallyRow` builds its own glyphs), and replace `hexagramResult(_:)` with the thin wrapper:

```swift
    private func hexagramResult(_ hex: Hexagram) -> some View {
        HexagramPairView(hexagram: hex, showText: $showText)
            .transition(.opacity)
    }
```

- [ ] **Step 3: Regenerate + build**

Run: `cd ~/Developer/Luo && xcodegen generate >/dev/null && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Screenshot-match ② (temporary scaffolding)**

Reuse the ② forced-乾 recipe to confirm the extraction didn't change appearance: temp-root `LuoApp` into `IChingRitualView()`; temp-seed a completed 乾 cast in `IChingRitualViewModel.init` (`castYao = Array(repeating: Yao(faces: [.heads,.heads,.heads]), count: 6); state = .complete(Hexagram(yao: castYao))`); temp-default `@State private var showText = true`. Build for sim, install, launch, `sleep 2`, `xcrun simctl io <UDID> screenshot /tmp/iching3-pair.png`, **Read it** — must match ②: 第 1 卦, 乾 → 坤, 动爻 rings on 乾, 释文 showing 乾卦辞 + 用九 + 变卦坤卦辞.

- [ ] **Step 5: Revert scaffolding + confirm**

Revert the three temp edits. Run: `cd ~/Developer/Luo && grep -n 'IChingRitualView()' Luo/LuoApp.swift; grep -n 'state = .complete' Luo/IChingRitualViewModel.swift; grep -n 'showText = true' Luo/IChingRitualView.swift`
Expected: no output.

- [ ] **Step 6: Final build + commit**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -3`

```bash
cd ~/Developer/Luo && git add Luo/HexagramPairView.swift Luo/IChingRitualView.swift && git commit -m "refactor: extract HexagramPairView shared by ritual result + Cast Log"
```

---

### Task 5: ModelContainer + auto-save + `CastLogDetailView`

**Files:** Modify `Luo/LuoApp.swift`, `Luo/IChingRitualView.swift`; Create `Luo/CastLogDetailView.swift`.

**Interfaces:** Consumes `CastRecord` (Task 3), `HexagramPairView` (Task 4). Produces `CastLogDetailView(record: CastRecord)`.

- [ ] **Step 1: Attach the ModelContainer** — replace `Luo/LuoApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct LuoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: CastRecord.self)
    }
}
```

- [ ] **Step 2: Auto-save on cast complete** — in `Luo/IChingRitualView.swift`, add the model context and an `.onChange`. Add near the top of the struct:

```swift
    @Environment(\.modelContext) private var modelContext
```

And add this modifier to the outer `ZStack` in `body` (next to the existing `.animation(...)`):

```swift
        .onChange(of: vm.state) { _, newState in
            if case .complete(let hex) = newState {
                modelContext.insert(CastRecord(from: hex, at: Date()))
            }
        }
```

- [ ] **Step 3: Create `Luo/CastLogDetailView.swift`**:

```swift
import SwiftUI
import SwiftData

/// One saved Cast: the 本卦→变卦 + 释文 rendering, its timestamp, and an editable
/// 提问 + 笔记 (edits autosave through the SwiftData context).
struct CastLogDetailView: View {
    @Bindable var record: CastRecord
    @State private var showText = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    HexagramPairView(hexagram: record.hexagram, showText: $showText)
                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(Theme.serif(13))
                        .foregroundColor(Theme.ink.opacity(0.5))
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("提问（可选）", text: Binding(
                            get: { record.question ?? "" },
                            set: { record.question = $0.isEmpty ? nil : $0 }))
                        TextField("笔记（可选）", text: Binding(
                            get: { record.note ?? "" },
                            set: { record.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    }
                    .font(Theme.serif(15))
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .navigationTitle("卦记")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 4: Regenerate + build**

Run: `cd ~/Developer/Luo && xcodegen generate >/dev/null && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/Luo && git add Luo/LuoApp.swift Luo/IChingRitualView.swift Luo/CastLogDetailView.swift && git commit -m "feat: SwiftData container + auto-save I Ching casts + CastLogDetailView"
```

---

### Task 6: `CastLogListView` + 占卜记录 entry

**Files:** Create `Luo/CastLogListView.swift`; Modify `Luo/RootView.swift`.

**Interfaces:** Consumes `CastRecord` (Task 3), `CastLogDetailView` (Task 5). Produces `CastLogListView(onBack: () -> Void)`.

- [ ] **Step 1: Create `Luo/CastLogListView.swift`**:

```swift
import SwiftUI
import SwiftData

/// The Cast Log: past I Ching Casts, newest first. Rows push to detail; swipe to
/// delete one; 清空 (confirmed) deletes all.
struct CastLogListView: View {
    var onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CastRecord.timestamp, order: .reverse) private var records: [CastRecord]
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            Theme.deskBackground.ignoresSafeArea()
            if records.isEmpty {
                Text("尚无卦记")
                    .font(Theme.serif(18))
                    .foregroundColor(Theme.ink.opacity(0.5))
            } else {
                List {
                    ForEach(records) { record in
                        NavigationLink(value: record) { row(record) }
                            .listRowBackground(Theme.deskBackground)
                    }
                    .onDelete { offsets in
                        offsets.map { records[$0] }.forEach(modelContext.delete)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("占卜记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CastRecord.self) { CastLogDetailView(record: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .tint(Theme.cinnabar)
            }
            if !records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") { confirmClear = true }.tint(Theme.cinnabar)
                }
            }
        }
        .confirmationDialog("清空全部卦记？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清空", role: .destructive) { records.forEach(modelContext.delete) }
            Button("取消", role: .cancel) {}
        }
    }

    private func row(_ record: CastRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.hexagram.name)
                .font(Theme.serif(20))
                .foregroundColor(Theme.ink)
            Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(Theme.serif(12))
                .foregroundColor(Theme.ink.opacity(0.5))
            if let q = record.question, !q.isEmpty {
                Text(q)
                    .font(Theme.serif(13))
                    .foregroundColor(Theme.ink.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}
```

- [ ] **Step 2: Add the 占卜记录 entry to `Luo/RootView.swift`** — change the enum and the switch and the picker:

Change the enum:

```swift
    private enum Ritual { case coin, iching, castLog }
```

Add a switch case (alongside `.coin`/`.iching`, before `case nil`):

```swift
        case .castLog:
            NavigationStack { CastLogListView(onBack: { ritual = nil }) }
```

Add a picker entry (after the 掷币 entryButton):

```swift
                entryButton("占卜记录") { ritual = .castLog }
```

- [ ] **Step 3: Regenerate + build**

Run: `cd ~/Developer/Luo && xcodegen generate >/dev/null && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Screenshot the list (temporary seeding)**

Temp-root `LuoApp` into the Cast Log with a seeded record so the list isn't empty: temporarily change `LuoApp` body to

```swift
        WindowGroup {
            NavigationStack { CastLogListView(onBack: {}) }
                .modelContainer(seeded)   // TEMP
        }
```

with a temp helper (TEMP) building an in-memory container holding one 乾 record:

```swift
    var seeded: ModelContainer {
        let c = try! ModelContainer(for: CastRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let hex = Hexagram(yao: Array(repeating: Yao(faces: [.heads, .heads, .heads]), count: 6))
        c.mainContext.insert(CastRecord(from: hex, at: Date()))
        return c
    }
```

Build for sim, install, launch, `sleep 2`, `screenshot /tmp/iching3-list.png`, **Read it** — confirm a row showing 乾 + a timestamp, title 占卜记录, a 清空 button. Then **revert** `LuoApp` to the Task-5 version (`RootView()` + `.modelContainer(for: CastRecord.self)`) and confirm: `grep -n 'seeded\|CastLogListView(onBack: {})' Luo/LuoApp.swift` → empty.

- [ ] **Step 5: Final build + commit**

Run: `cd ~/Developer/Luo && xcodebuild -scheme Luo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build 2>&1 | tail -3`

```bash
cd ~/Developer/Luo && git add Luo/CastLogListView.swift Luo/RootView.swift && git commit -m "feat: Cast Log list + 占卜记录 home entry (swipe-delete + 清空)"
```

---

## Deferred (not this plan)

- Coin "save this Cast" escape hatch (second entry type) → later task.
- Corpus backfill (② follow-up), Noto Serif SC, coin face legibility, scene-fade-on-complete.

## Self-Review

**Spec coverage:**
- Domain reconstructors → Tasks 1 (`Yao(isYang:isChanging:)`) + 2 (`Hexagram(presentBits:changingMask:)`). ✓
- SwiftData `CastRecord`, Identifier-only, reconstructable, in-memory tested → Task 3. ✓
- Shared `HexagramPairView` (ritual + detail identical) → Task 4. ✓
- ModelContainer + auto-save on complete + detail (editable 提问/笔记) → Task 5. ✓
- List (@Query newest-first, swipe-delete, 清空 confirmed, empty state) + 占卜记录 entry + NavigationStack → Task 6. ✓
- Store Identifier only, text at view time → Tasks 3 + 4 (HexagramPairView looks up ZhouYiCorpus). ✓

**Placeholder scan:** No TBD/TODO. Temp-scaffolding blocks are explicitly marked TEMP with revert+grep steps. ✓

**Type consistency:** `Yao(isYang:isChanging:)`, `Hexagram(presentBits:changingMask:)`, `CastRecord(from:at:)`/`.hexagram`, `HexagramPairView(hexagram:showText:)`, `CastLogListView(onBack:)`, `CastLogDetailView(record:)` names/signatures match across tasks. `changingMask` bit convention (`pos-1`) consistent between Task 2 reconstruction and Task 3 `init(from:)`. `Ritual` enum gains `.castLog` used in both switch and picker. ✓
