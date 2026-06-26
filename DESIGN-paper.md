---
version: alpha
name: Luò — Rice Paper
description: >-
  The light-mode visual identity for 落 (Luò), a physics-grade divination app.
  Warm 宣纸 (rice paper) under daylight; deep warm ink for type; a single deep
  cinnabar seal for the one action that matters. Material, quiet, classical —
  a sheet of paper laid flat on a desk, not a glowing screen.
colors:
  primary: "#1C1814"
  secondary: "#6B6253"
  tertiary: "#B5402A"
  tertiary-pressed: "#9E3623"
  neutral: "#F3ECDC"
  surface-raised: "#ECE3CF"
  hairline: "#D8CDB6"
typography:
  display:
    fontFamily: Noto Serif SC
    fontSize: 64px
    fontWeight: 600
    lineHeight: 1.05
  h1:
    fontFamily: SF Pro Display
    fontSize: 30px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  h2:
    fontFamily: SF Pro Display
    fontSize: 21px
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: SF Pro Text
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.5
  reading:
    fontFamily: Noto Serif SC
    fontSize: 20px
    fontWeight: 400
    lineHeight: 1.9
  caption:
    fontFamily: SF Pro Text
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  label-caps:
    fontFamily: SF Pro Text
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1
    letterSpacing: "0.12em"
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  xxl: 64px
rounded:
  none: 0px
  sm: 4px
  md: 8px
  lg: 16px
  full: 9999px
components:
  button-cast:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.neutral}"
    typography: "{typography.h2}"
    rounded: "{rounded.md}"
    padding: 16px
  button-cast-pressed:
    backgroundColor: "{colors.tertiary-pressed}"
    textColor: "{colors.neutral}"
  button-quiet:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: 12px
  cast-log-row:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.primary}"
    rounded: "{rounded.lg}"
    padding: 16px
  canonical-text:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.primary}"
    typography: "{typography.reading}"
    padding: 24px
  metadata:
    backgroundColor: "{colors.neutral}"
    textColor: "{colors.secondary}"
    typography: "{typography.caption}"
  divider:
    backgroundColor: "{colors.hairline}"
    height: 1px
---

## Overview

落 (Luò) is the moment objects come to rest — the Settle that ends every Ritual. The visual identity exists to disappear behind that moment. This is the light reading of that idea: not a desk at dusk but a sheet of 宣纸 (rice paper) laid flat under daylight. The surface is a warm, fibrous cream; type is the color of ground ink pressed into it; and there is exactly one chromatic accent — a deep cinnabar, the red of a 卦师's seal stamped onto the page — spent only on the one action a screen is actually for.

This is a material aesthetic, not a decorative one. The product's claim is *tactile authenticity*: that the cast mattered because the user's motion shaped it. A loud, ornamented UI would contradict that claim by drawing attention to itself. The rule beneath every choice here is restraint — fewer colors, fewer weights, more void. When in doubt, remove. The paper reading trades the intimacy of the dark desk for the clarity and tradition of ink on a page; the discipline is identical.

## Colors

The palette is built from three materials — paper, ink, and seal — plus the hairlines between them.

- **Paper (#F3ECDC):** The 宣纸. A warm, fibrous cream, never a cold paper-white. This is the background of every screen and the ground the SceneKit objects fall onto, so chrome and simulation share one continuous surface.
- **Paper-raised (#ECE3CF):** The same paper, a shade deeper — Cast Log rows, sheets, the canonical-text panel. It separates by a faint warmth shift, not by line, so layering reads without clutter.
- **Hairline (#D8CDB6):** The only border color. One pixel, for dividers and edges where the warmth shift alone is not enough. Never darker, never heavier.
- **Ink (#1C1814):** Ground ink with brown in it — the color of all primary text and the active hexagram. Warm, not the clinical black of a print driver.
- **Stone (#6B6253):** Warm taupe-grey for metadata, timestamps, captions, and inactive state. Present but recessive.
- **Cinnabar (#B5402A):** The single accent (`tertiary`). A deep earthen vermilion — the seal stamped on the page, not a sign. It marks the one most-important action on a screen (the Cast button, a changing-Yao marker) and nothing else. The instant cinnabar appears twice with equal weight on one screen, it has failed.
- **Cinnabar-pressed (#9E3623):** The pressed/active state of the accent (`tertiary-pressed`). The only place cinnabar is allowed to deepen.

In token terms: rice paper is `neutral`, ground ink is `primary`, stone is `secondary`, and the seal is `tertiary`.

## Typography

Two families do all the work, split by voice. **SF Pro** is the native iOS sans used for everything that is chrome — buttons, navigation, metadata, the hexagram number. It is invisible by design and matches the platform the app lives on. **Noto Serif SC** (Source Han Serif) is the classical Song serif reserved for two reverent surfaces: the large Hanzi name of a hexagram (`display`), and the canonical *Zhou Yi* text — the 卦辞 and 爻辞 (`reading`), rendered in classical Chinese with no translation, no pinyin, no gloss. The serif signals "this is the source, not our words."

- **display** — the hexagram's Hanzi name at the size of a held breath; serif, the focal point of a reading.
- **h1 / h2** — screen and section titles in the sans; quiet, structural.
- **body** — 17px native iOS body for all interface prose and onboarding copy.
- **reading** — the canonical text layer; serif, 1.9 line-height because classical Chinese wants air around it.
- **caption** — timestamps and Cast Log metadata.
- **label-caps** — tracked-out uppercase micro-labels (e.g. PRESENT / RESULTING above the two hexagrams). The only place letters are spaced out.

Hold the line at two weights per screen. If a third weight feels necessary, the hierarchy is wrong somewhere else.

## Spacing & Shape

Spacing follows a 4-pt base scale (xs 4 → xxl 64). The result screen and the page both earn their calm from generous `lg`/`xl` margins and a lot of deliberate void; never crowd the cast or the canonical text to fit more on screen.

Corner rounding is restrained. Use `sm` and `md` for buttons, sheets, and inputs — soft enough to feel native to iOS, sharp enough to keep the material, paper-and-ink character. `lg` is reserved for large containers like Cast Log rows. `full` exists only for genuinely circular affordances. Do not mix sharp and rounded corners in the same view.

## Components

- **button-cast** — the primary action (起卦 / Cast). Solid deep cinnabar on the page, paper-color text, `md` corners. There is at most one per screen.
- **button-quiet** — secondary actions (reset, dismiss, toggle). Raised-paper fill, ink text, no accent color. Everything that is not *the* action lives here.
- **cast-log-row** — a single saved Cast in the local-only log; raised paper, `lg` corners, warmth not borders.
- **canonical-text** — the *Zhou Yi* panel revealed by the single result toggle; paper background, serif `reading` type, `xl` padding. This is the most sacred surface in the app; give it the most room.

## Do & Don't

- **Do** spend cinnabar on exactly one action per screen.
- **Don't** introduce a second accent hue (no jade, no gold) — restraint is the brand.
- **Do** keep the chrome surface continuous with the SceneKit page; the UI and the simulation are one space.
- **Don't** use cold paper-white (#FFFFFF) or clinical black; everything is warmed toward fiber and ground ink.
- **Do** maintain WCAG AA (4.5:1) for body text.
- **Don't** add ornament, gradients on the accent, drop shadows for decoration, or "coin skins." If a TTRPG dice app would ship it as flair, 落 doesn't.
- **Don't** use more than two type weights on a single screen.
