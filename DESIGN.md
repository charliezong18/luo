---
version: alpha
name: Luò — Dusk Desk
description: >-
  The visual identity for 落 (Luò), a physics-grade divination app. A warm,
  near-black desk at dusk; aged-paper ink for type; a single earthen cinnabar
  for the one action that matters. Material, quiet, classical — the opposite of
  a neon coin skin.
colors:
  primary: "#ECE3D2"
  secondary: "#9A8F7C"
  tertiary: "#DC6A4B"
  tertiary-pressed: "#CC6044"
  neutral: "#14110D"
  surface-raised: "#211B14"
  hairline: "#37291A"
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

落 (Luò) is the moment objects come to rest — the Settle that ends every Ritual. The visual identity exists to disappear behind that moment. Nothing on screen should compete with the desk, the throw, or the result the objects produced. The whole surface reads like a lacquered wood desk seen at dusk: warm, near-black, lit by a single low lamp. Type is the color of aged paper under that lamp. There is exactly one chromatic accent — an earthen cinnabar, the red of a 卦师's seal — and it is spent only on the one action a screen is actually for.

This is a material aesthetic, not a decorative one. The product's claim is *tactile authenticity*: that the cast mattered because the user's motion shaped it. A loud, ornamented UI would contradict that claim by drawing attention to itself. So the rule beneath every choice here is restraint — fewer colors, fewer weights, more void. When in doubt, remove.

## Colors

The palette is built from three materials — desk, paper, and seal — plus the hairlines between them.

- **Surface (#14110D):** The desk. A warm near-black with brown in it, never a cold blue-black. This is the SceneKit table the coins fall onto and the background of every screen, so the chrome and the simulation share one continuous surface.
- **Surface-raised (#211B14):** The same desk, lifted a few millimeters — Cast Log rows, sheets, the canonical-text panel. It separates by depth, not by line, so the eye reads layering without clutter.
- **Hairline (#37291A):** The only border color. Used at one pixel for dividers and edges where depth alone is not enough. Never thicker, never lighter.
- **Ink (#ECE3D2):** Aged paper warmed by lamplight — the color of all primary text and the active hexagram. It carries gravitas without the harsh glare of pure white on a dark field.
- **Ink-muted (#9A8F7C):** Warm stone grey for metadata, timestamps, captions, and inactive state. Present but recessive.
- **Cinnabar (#DC6A4B):** The single accent (`tertiary`). A warm earthen vermilion — the seal, not a sign. It marks the one most-important action on a screen (the Cast button, a changing-Yao marker) and nothing else. The instant cinnabar appears twice with equal weight on one screen, it has failed.
- **Cinnabar-pressed (#CC6044):** The pressed/active state of the accent (`tertiary-pressed`). The only place cinnabar is allowed to deepen.

In token terms: aged paper is `primary`, stone grey is `secondary`, cinnabar is `tertiary`, and the dusk desk is `neutral`.

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

Spacing follows a 4-pt base scale (xs 4 → xxl 64). The result screen and the desk both earn their calm from generous `lg`/`xl` margins and a lot of deliberate void; never crowd the cast or the canonical text to fit more on screen.

Corner rounding is restrained. Use `sm` and `md` for buttons, sheets, and inputs — soft enough to feel native to iOS, sharp enough to keep the material, stone-and-paper character. `lg` is reserved for large containers like Cast Log rows. `full` exists only for genuinely circular affordances. Do not mix sharp and rounded corners in the same view.

## Components

- **button-cast** — the primary action (起卦 / Cast). Solid cinnabar on the desk, dark surface-color text, `md` corners. There is at most one per screen.
- **button-quiet** — secondary actions (reset, dismiss, toggle). Raised-surface fill, ink text, no accent color. Everything that is not *the* action lives here.
- **cast-log-row** — a single saved Cast in the local-only log; raised surface, `lg` corners, depth not borders.
- **canonical-text** — the *Zhou Yi* panel revealed by the single result toggle; surface background, serif `reading` type, `xl` padding. This is the most sacred surface in the app; give it the most room.

## Do & Don't

- **Do** spend cinnabar on exactly one action per screen.
- **Don't** introduce a second accent hue (no jade, no gold) — restraint is the brand.
- **Do** keep the chrome surface continuous with the SceneKit desk; the UI and the simulation are one space.
- **Don't** use pure white (#FFFFFF) or cold neutrals anywhere; everything is warmed toward paper and wood.
- **Do** maintain WCAG AA (4.5:1) for body text; the dark palette makes this easy — keep it.
- **Don't** add ornament, gradients on the accent, glows, or "coin skins." If a TTRPG dice app would ship it as flair, 落 doesn't.
- **Don't** use more than two type weights on a single screen.
