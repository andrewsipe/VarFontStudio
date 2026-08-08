# VarFont Studio — Design Decisions Log

Append-only running log for color, typography, spacing/density, and stroke decisions.
Check this file **and** the token enums (`StudioColors`, `StudioPalette`, `StudioTypography`,
`StudioSpacing` / `StudioDensity`, `StudioStroke`) before adding new styling.

**Live source of truth for tokens:** `Views/StudioPalette.swift`, `Views/StudioDesign.swift`
(`StudioColors`, typography, spacing, stroke). `COLOR_OUTLINE.md` is historical notes only —
do not treat it as authoritative when it disagrees with code.

## Protocol

1. Search existing tokens / this log for a covering decision.
2. If nothing fits, classify:
   - **Targeted** — one screen/component; implement and log here.
   - **App-wide** — new token, hue, stroke usage, or reusable spacing; prototype narrowly,
     then confirm before rolling out.
3. Append an entry below when a decision lands.

---

## 2026-08-08 — StudioDesign refactor (structure)

Scope: app-wide  
Status: Approved  

Rationale: Feature composites left `StudioDesign.swift` for `InspectorComponents.swift`,
`SaveReviewComponents.swift`, and `StudioSharedLayouts.swift`. Dead `StudioDiffRow` /
`StudioKeyValueRow` removed. Design-system core keeps tokens + shared primitives
(including `StudioMenuPicker`).

## 2026-08-08 — Typography: caption wins; SaveReviewTypography deleted

Scope: app-wide  
Status: Approved  

Rationale: `meta` and `caption` were identical (`Font.system(size: 10)`); keep the more
common name (`caption`). Save Review row fonts remap onto `StudioTypography`
(`bodyMedium`, `rowNameMono.weight(.medium)`, `caption`, `monoValue`).

## 2026-08-08 — contentInset replaces panel/sheet/card aliases

Scope: app-wide  
Status: Approved  

Rationale: One 12pt horizontal rail for panels, sheets, cards, and chrome. Name
`contentInset` states the role; redundant aliases (`sheetOuterPadding`, `cardPadding`,
etc.) deleted so agents do not invent parallel inset tokens.

## 2026-08-08 — StudioDensity standard / compact; sectionGap is section rhythm

Scope: app-wide  
Status: Approved  

Rationale: Two row tiers only — `standard` (shared headers) and `compact` (Instances +
Axis Tree stop detail). Axis Tree “openness” comes from `sectionGap`, not a third row
density. No `relaxed` tier.

## 2026-08-08 — Stroke: hairline at rest; dashed only for drag

Scope: app-wide (Naming Order + Axis Tree + Combination suggestions)  
Status: Approved  

Rationale: Solid `hairline` separates low-contrast Naming Order chips at rest.
`StudioStroke.dragDash` is reserved for transient drag/hover. Optional Combination
suggestions use neutral chrome; amber stays for real issues only.

## 2026-08-08 — StudioPalette + primary / secondary / tertiary steps

Scope: app-wide  
Status: Approved  

Rationale: Shared family × step API from the accent palette review. Marks use WCAG 3:1;
text uses 4.5:1. Within a family: primary = richest legible mark step, secondary = mid,
tertiary = lightest legible. Exemplar: `statFormat1/2/3` = purple primary/secondary/tertiary.
Do not use `forestGreen` until Figma re-check (dark export quirk).

Apple system colors remain for true semantic chrome (`.primary` / `.secondary` /
`.tertiary`, warning orange, success/error where they mean platform status). HIG is a
reference for finicky calls — not a redesign mandate.

## 2026-08-08 — Pending export = emerald-green; edited stays cyan

Scope: app-wide  
Status: Approved  

Rationale: Pending export previously borrowed `editedForeground` (cyan), colliding with
“name edited from default” on the same rows. Emerald is unclaimed and far from cyan.
Token: `StudioColors.pendingForeground` / `pendingFill`.

## 2026-08-08 — Registration / code / STAT / diff accents rebound to palette

Scope: app-wide  
Status: Approved  

| Role | Family | Light / dark steps |
|------|--------|--------------------|
| `registrationForeground` | magenta | 500 / 300 |
| `codeForeground` | jade-green | 500 / 300 |
| `statFormat1/2/3` | purple | 300·500·700 / 300·200·100 |
| `diffAdded` | green | 600 / 200 |
| `diffRemoved` | red | 400 / 200 |
| `diffReflowed` | violet | 400 / 200 |
| `collisionForeground` | pink | 600 / 300 |
| `customForeground` | indigo | 300 / 200 |
| `editedForeground` | cyan | 500 / 200 |

## 2026-08-08 — Inspector planned writes align with Save Review

Scope: targeted (Inspector), shared pill language with Save Review / pending  
Status: Approved  

Rationale: Planned OpenType preview uses Field / ID / Content grammar, mono values, and
source pills colored like Save Review category chrome (STAT→registration, fvar→brand,
name→code, planned→pending). Disclosure carries a `planned` emerald pill so the concept
matches Instances pending export without inventing a second hue.
