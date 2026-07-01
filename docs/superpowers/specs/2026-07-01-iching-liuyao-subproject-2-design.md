# 六爻 Sub-project ② : 周易文本 + 变卦 (seed skeleton)

**Date:** 2026-07-01
**Ritual:** I Ching 六爻 三钱法 — Sub-project ② of Phase 3
**Status:** Design approved, pending spec review
**Builds on:** Sub-project ① (merged; `Yao`, `Hexagram`, `KingWenTable`, `IChingRitualViewModel`, `IChingRitualView`).

## Context

Phase 3 was decomposed into ①②③. ① (掷出正确本卦) is shipped. This is **②**:
render the **Resulting Hexagram (变卦)** alongside the Present Hexagram (本卦), and
add a **Canonical Text layer** (卦辞 / 爻辞) behind a toggle — per ADR-0004.

Per the corpus-sourcing decision (option C): build the whole 变卦 + text-toggle
feature on a **small SEED corpus** (a handful of hexagrams whose 周易 text can be
reproduced accurately), so the *feature* (变卦 computation, layout, data flow,
toggle) is decoupled from the *data* (the full 64 卦辞 + 384 爻辞). Backfilling the
full corpus is a **separate later data task** — "backfill = add entries to a data
file", no code change.

## Milestone / Success Criteria

After a Cast completes, the result screen shows:
- **本卦 → 变卦 side by side** (layout A): 本卦 (卦号 + 卦名 + vertical 6-Yao glyph
  with 动爻 marked), an arrow `→`, and — when there is at least one 动爻 — the 变卦
  (卦号 + 卦名 + its static 6-line glyph). No 动爻 → 本卦 only, no arrow, no 变卦.
- A **`释文 ▾` toggle**, default collapsed (ADR-0004), that appears **only when the
  本卦's 卦辞 is present in the corpus**. Expanded it renders, classical Chinese
  verbatim, no translation/pinyin/gloss: 本卦卦辞 · each 动爻's 爻辞 (labeled by
  position) · 变卦卦辞. When 乾(#1) or 坤(#2) has all 6 Yao changing, show 用九 /
  用六 in place of the six individual 爻辞.

Out of scope for ②: full 64+384 corpus (seed only), any interpretation / "which
line to read" guidance (ADR-0004 forbids), Cast Log (③), Noto Serif SC.

## Key Decisions (from brainstorming)

1. Corpus source = **C** (seed now, backfill later). Data model designed so backfill
   is data-only.
2. Layout = **A** (本卦 → 变卦 side by side, arrow, 动爻 aligned/marked).
3. Text toggle **default OFF** (ADR-0004). Expanded = 本卦卦辞 + 各动爻辞 + 变卦卦辞;
   classical text only, **no gloss/translation/pinyin**, no reading-rule interpretation.
4. **用九 / 用六**: shown when 乾 / 坤 respectively has all 6 Yao changing (replaces the
   six 爻辞). Display only, not "read this".
5. **Degradation**: the `释文` toggle appears only if the 本卦 has 卦辞 in the corpus;
   otherwise Identifier-only (which is ADR-0004's always-on default layer). A 变卦 whose
   text isn't seeded shows "（待补）" in the expanded 变卦卦辞 slot.

## Architecture

Extend ①'s pure domain layer + the existing result view; add one corpus data layer.
Domain stays SceneKit-free and unit-tested. The corpus is a plain lookup so the
backfill task never touches logic.

```
IChingRitualView.hexagramResult (extended)
   ├── Hexagram.resultingHexagram : Hexagram?   (new, domain)
   └── ZhouYiCorpus.text(forNumber:) : HexagramText?  (new, data)
```

## Components

### Domain (new/extended, pure, Foundation-only, unit-tested)

- **`Yao` — add a static-line factory.** Currently `Yao` is only built from 3
  `CoinFace`s. The 变卦's lines are plain young (non-changing) lines of a given
  polarity, not cast from coins. Add `init(isYang: Bool)` (or `static func line(yang:)`)
  producing a non-changing Yao of that polarity: `isChanging == false`, `isYang ==`
  the argument, `kind == .youngYang`/`.youngYin`, correct `glyph`. Keep `init(faces:)`
  unchanged.
- **`Hexagram.resultingHexagram: Hexagram?`** (computed). `nil` when
  `changingPositions.isEmpty`. Otherwise build a `[Yao]` where each position is a
  static line: a changing Yao flips polarity (`Yao(isYang: !yao.isYang)`), a
  non-changing Yao keeps its polarity as a static line (`Yao(isYang: yao.isYang)`).
  The resulting `Hexagram` gets its `number`/`name` from `KingWenTable` via
  `presentBits` as usual. (The 变卦 is itself static — none of its lines are changing.)

### Data (new)

- **`HexagramText`** value type: `guaCi: String` (卦辞), `yaoCi: [String]` (exactly 6,
  index 0 = bottom = 初; index 5 = 上), `yong: String?` (用九 for 乾 / 用六 for 坤, else nil).
- **`ZhouYiCorpus`**: `static func text(forNumber n: Int) -> HexagramText?`, backed by a
  seed dictionary keyed by King Wen number. Returns `nil` for un-seeded hexagrams.
  **Seed set (implementation must verify each character against a public-domain 周易
  经文 source, e.g. Chinese Text Project / Wikisource 易經):**
  - 乾 #1 — 卦辞「元亨利貞」; 6 爻辞 (初九…上九); 用九「見群龍无首，吉」.
  - 坤 #2 — 卦辞「元亨，利牝馬之貞…」; 6 爻辞; 用六「利永貞」.
  - Plus 2–3 more well-known hexagrams (e.g. 泰 #11, 否 #12, 屯 #3) so a 变卦 can land
    on a seeded target and the side-by-side text path is exercised. Exact set finalized
    in the plan; correctness of every seeded passage is verified against the source
    during implementation (structural tests can't catch a wrong character).
  - `yaoCi` must have exactly 6 entries per hexagram (bottom→top).

### View (extend `IChingRitualView.hexagramResult`)

- Header `第 N 卦` (unchanged).
- **本卦 → 变卦 row**: an `HStack` — 本卦 column (卦名 + vertical 6-Yao glyph via the
  existing `yaoRow`, 动爻 rings) ; if `hex.resultingHexagram != nil`: an arrow `→`
  (dim `Theme.ink`) + 变卦 column (卦名 + its static 6-line glyph, no rings). The two
  columns align row-for-row so the changed positions read across. No 变卦 → just 本卦
  centered as today.
- **`释文` toggle**: `@State private var showText = false`. Render a small
  `释文 ▾ / ▴` button ONLY if `ZhouYiCorpus.text(forNumber: hex.number) != nil`.
  Expanded (`showText`), a text block, serif, `Theme.ink`, classical text only:
  - 本卦卦辞 (the 本卦's `guaCi`).
  - For each `changingPositions` entry: that position's 爻辞
    (`text.yaoCi[pos-1]`), each prefixed with its position label (初/二/三/四/五/上
    + 九 for yang / 六 for yin, matching the Yao at that position). **Exception**: if
    `hex.number == 1` and all 6 changing → show `text.yong` (用九) instead of the six
    爻辞; if `hex.number == 2` and all 6 changing → 用六.
  - 变卦卦辞: `ZhouYiCorpus.text(forNumber: resulting.number)?.guaCi ?? "（待补）"`,
    shown only when a 变卦 exists.
- Reuse `yaoRow`; keep Dusk Desk `Theme` tokens; no hardcoded hex.

## Testing Strategy

- **Domain (XCTest, pure):**
  - `Yao(isYang:)`: yang line → isYang true, isChanging false, glyph ⚊; yin line →
    isYang false, isChanging false, glyph ⚋.
  - `Hexagram.resultingHexagram`: no 动爻 → nil; 乾 with all 6 老阳 → 变卦 = 坤 #2;
    a partial case (e.g. only bottom Yao changing on an all-yang cast) → the correct
    flipped number/name; verify the 变卦 has no changing lines.
- **Data (XCTest):**
  - `ZhouYiCorpus.text(forNumber:)`: seeded numbers return non-nil with exactly 6
    `yaoCi`; an un-seeded number returns nil; 乾's `guaCi == "元亨利貞"` and `yong`
    non-nil; spot-check one 爻辞 string.
- **View:** build succeeds; screenshot a completed cast WITH changing yao (shows
  本卦→变卦 + a seeded 释文 expanded) — verify via the temp-root + auto-throw loop
  ([[feedback-luo-scenekit-debug-workflow]]); revert scaffolding before commit.
- Build/test target: iPhone 17 / iOS 26.5 simulator.

## Deferred (explicitly not ②)

- Full 64 卦辞 + 384 爻辞 corpus backfill → separate data task (add entries to
  `ZhouYiCorpus`'s data file; the model + tests already accommodate it).
- Cast Log persistence → ③.
- Any interpretation / reading-rule guidance, translation, gloss → never (ADR-0004).
- Noto Serif SC for classical text → later polish.
- Coin face legibility (heads/tails contrast) → deferred usability item from ①.
