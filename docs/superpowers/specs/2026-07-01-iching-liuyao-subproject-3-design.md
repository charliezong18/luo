# 六爻 Sub-project ③ : Cast Log 持久化 (SwiftData)

**Date:** 2026-07-01
**Ritual:** I Ching 六爻 — Sub-project ③ of Phase 3
**Status:** Design approved, pending spec review
**Builds on:** ① (掷本卦) + ② (变卦 + 释文), both merged. Reuses `Hexagram`, `Yao`,
`KingWenTable`, `ZhouYiCorpus`, `IChingRitualView` result rendering.

## Context

Phase 3 = ①②③. ① and ② are shipped. This is **③**: persist every I Ching Cast to a
local **Cast Log** (卦记 / 占验录) and let the user browse, read, annotate, and delete
past Casts — per ADR-0003 (Stateful by Ritual). Coin stays stateless; the Coin
"save this Cast" escape hatch is **deferred** (a later small task), so ③'s model is
single-type (hexagram Casts only).

## Milestone / Success Criteria

- Completing an I Ching Cast **auto-saves** one record locally (no prompt, ritual flow
  uninterrupted).
- A **占卜记录** entry on the home screen opens a **list** of past Casts, newest first:
  each row shows 卦名 + timestamp (+ a question snippet when present).
- Tapping a row opens a **detail** view: 本卦 → 变卦 (动爻 marked) + 释文 (same rendering
  as the ritual result), the timestamp, and an **editable 提问 + 笔记** (persisted).
- **Delete**: swipe-to-delete a single record; a **清空** action (with confirmation)
  deletes all.
- Records store **Identifier fields only** (`presentBits`, `changingMask`, timestamp,
  optional question/note); rendered text (卦辞/爻辞) is looked up from `ZhouYiCorpus` at
  view time (ADR-0004 — corpus can change without rewriting old records).

Out of scope (ADR-0003): iCloud sync, account, export, share-sheet, search. Also out:
Coin "save this Cast" (deferred), Noto Serif SC.

## Key Decisions (from brainstorming)

1. Storage = **SwiftData** (`@Model`, `ModelContainer`, `@Query`) — iOS-17-native,
   idiomatic, portfolio-relevant; list reads via `@Query`, writes/deletes via
   `modelContext`.
2. **Auto-save** every I Ching Cast on `state → .complete`; question/note NOT forced at
   cast time — editable later in detail.
3. ③ is **I Ching only** (single-type model); Coin-save deferred.
4. Store **only** `presentBits` + `changingMask` (+ timestamp, question?, note?); derive
   卦号/卦名/动爻/变卦/text from those — no denormalized number (avoids drift).
5. Reach the log via a **third `RootView` entry「占卜记录」** → `NavigationStack` →
   list → detail.
6. Extract a shared **`HexagramPairView`** (本卦→变卦 + 释文) from `IChingRitualView` so
   the ritual result and the log detail render identically — no duplication.

## Architecture

```
LuoApp (.modelContainer(for: CastRecord.self))
  └── RootView  ── 六爻 / 掷币 / 占卜记录
        ├── IChingRitualView ── .onChange(state==.complete) → modelContext.insert(CastRecord)
        │        └── HexagramPairView (extracted; shared)
        └── NavigationStack → CastLogListView (@Query) → CastLogDetailView
                                                              └── HexagramPairView

Domain (pure): Yao(isYang:isChanging:) · Hexagram(presentBits:changingMask:)
```

## Components

### Domain (new, pure, Foundation-only, unit-tested)

- **`Yao(isYang:isChanging:)`** — full factory covering all 4 combinations →
  `.oldYang`(yang,changing) / `.youngYang`(yang,¬) / `.oldYin`(yin,changing) /
  `.youngYin`(yin,¬). (① added `init(faces:)` and ② added `init(isYang:)`; this
  generalizes to reconstruct a stored Cast's exact lines.)
- **`Hexagram(presentBits:changingMask:)`** — reconstruct a `Hexagram` from the two
  stored Ints: for position i (0=bottom), `isYang = presentBits & (1<<i) != 0`,
  `isChanging = changingMask & (1<<i) != 0` → `Yao(isYang:isChanging:)`; then the
  existing `Hexagram(yao:)`. Round-trips with the existing `presentBits` /
  `changingPositions`.

### Storage (SwiftData)

- **`@Model final class CastRecord`**: `timestamp: Date`, `presentBits: Int`,
  `changingMask: Int`, `question: String?`, `note: String?`. A convenience
  `init(from hexagram: Hexagram, at date: Date)` computing `presentBits` +
  `changingMask` from the hexagram, and a computed `hexagram: Hexagram`
  (`Hexagram(presentBits:changingMask:)`) for the views. `changingMask` is built from
  `hexagram.changingPositions` (1-based → bit `pos-1`).
- **`ModelContainer`** for `CastRecord.self` attached at `LuoApp` via
  `.modelContainer(for: CastRecord.self)`; views get `@Environment(\.modelContext)` and
  `@Query`.

### Views

- **`HexagramPairView(_ hex: Hexagram, showText: Binding<Bool>)`** (extracted from the
  current `IChingRitualView.hexagramResult` internals): renders 第 N 卦 header, 本卦 →
  变卦 columns (动爻 rings), and the 释文 toggle/text (② logic: 本卦卦辞 · 动爻辞/用九用六 ·
  变卦卦辞, "（待补）" fallback). `IChingRitualView.hexagramResult` becomes a thin wrapper
  that hosts this view; behavior/appearance unchanged (a screenshot must match ②).
- **`CastLogListView`**: `@Query(sort: \CastRecord.timestamp, order: .reverse) records`.
  Rows (NavigationLink → detail): 卦名 (`record.hexagram.name`) + formatted timestamp +
  optional 1-line question. `.swipeActions` delete (`modelContext.delete(record)`).
  Toolbar **清空** button → confirmation dialog → delete all. Empty state: "尚无卦记".
  Dusk Desk `Theme`.
- **`CastLogDetailView(record: CastRecord)`**: `HexagramPairView(record.hexagram, …)`;
  timestamp; a 提问 `TextField` and 笔记 `TextField`/editor bound to `record.question` /
  `record.note` (SwiftData autosaves model edits on the context). Dusk Desk.
- **`RootView`**: add a third entry「占卜记录」. Its branch wraps a `NavigationStack`
  around `CastLogListView` (list→detail push); 六爻/掷币 branches unchanged.
- **Auto-save**: in `IChingRitualView`, `.onChange(of: vm.state)` — when it becomes
  `.complete(hex)`, `modelContext.insert(CastRecord(from: hex, at: .now))`. Fires once
  per cast (state transition); 再占 → new cast → new record.

## Testing Strategy

- **Domain (XCTest, pure):**
  - `Yao(isYang:isChanging:)`: all 4 combos → correct kind/isYang/isChanging.
  - `Hexagram(presentBits:changingMask:)` round-trip: build a known Hexagram (e.g. 乾
    bottom old-yang + 5 young-yang), take its `presentBits`/`changingMask`, reconstruct,
    assert equal `number`/`name`/`changingPositions` and that `resultingHexagram` matches.
- **Storage (XCTest, in-memory SwiftData):** a `ModelContainer` with
  `ModelConfiguration(isStoredInMemoryOnly: true)`; insert a `CastRecord(from:)`, fetch
  via `FetchDescriptor`, assert its `hexagram.number` matches; delete it → empty; insert
  several → deleteAll → empty.
- **Views:** build succeeds; screenshot the list (with a seeded record) and the detail
  (temp-root into the Cast Log with an in-memory seeded record); revert scaffolding.
- Build/test target: iPhone 17 / iOS 26.5 simulator.

## Deferred (not ③)

- Coin "save this Cast" escape hatch (adds a second entry type) → later task.
- Full corpus backfill (② follow-up), Noto Serif SC, coin face legibility.
- Any cloud/account/export/share/search (ADR-0003 — never in v1).
