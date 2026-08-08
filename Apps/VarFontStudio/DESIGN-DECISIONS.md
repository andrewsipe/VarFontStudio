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

## 2026-08-08 — Amber = fix locus; duplicates are advisory

Scope: app-wide  
Status: Approved  

Rationale: Almost nothing “breaks” a font — naming/quality issues guide, they don’t hard-block.
Included duplicate composed names no longer abort Review session build or Export All; they
appear as a Review preflight warning instead. Instance list keeps warning badges but drops
full-row `warningFill` washes (doesn’t scale when many labels collide). Inspector shows one
primary amber CTA (axis Resolve preferred over Show duplicates). Composed-name callouts keep
a leading warning stripe without a full amber wash.

Chrome tiers going forward:
- **Act here** — amber banner / Resolve / Review queue
- **Affected** — icon / badge only
- **Focused** — one Inspector CTA

## 2026-08-08 — Conflict indicators point at the cause, not just the symptom

Scope: Axis Tree, Inspector, Save Review  
Status: Approved  

Rationale: The amber banners announced conflicts but never showed *where* to fix them.
Each surface now carries a marker on the conflicting element itself so a user can resolve
without opening the issue resolver:

- **Axis Tree** — stops in an unresolved axis naming conflict (`conflictStopIDs`, derived
  from `axisConflictBundles.involvedStopIDs`) get an amber leading stripe and a clickable
  `StudioWarningBadge`; clicking jumps into that axis's conflict resolver.
- **Inspector** — the coordinate row and naming-chain link for `primaryConflictAxis(for:)`
  are marked (amber chain dot + a resolve badge on the row; amber ring on the chain pill),
  so the single-instance panel points at the originating axis instead of only warning at top.
- **Save Review** — triangles follow the conflict *chain*, matching the studio:
  - **Cause** — the conflicting axis stops (from `AxisConflictBundler`, the same source the
    Axis Tree uses) are flagged in the **STAT** table and in their **name**-table stop records,
    keyed `tag:value` so the exact stops (e.g. both `wght` "Regular") carry the triangle just
    like the Axis Tree rows.
  - **Symptom** — instance rows whose composed name is shared by >1 included instance
    (`duplicatedComposedNames`) are flagged in the **fvar** / **name** Instances sections, with
    the triangle **trailing the composed-name value** (mirroring the Instances list, where
    `statusAccessory` follows the name).
  Both live in `SaveReviewRowPresentation.conflictHint`. The diff-category gutter is left intact
  (not amber-washed) so added/removed/same still reads. The warnings card is now an amber-filled
  banner matching `StudioConflictAlert` / the Axis Tree plan-warnings band (was a stroke-only
  card) so every "needs attention" notice reads the same across the app.

Markers reuse `StudioColors.warningForeground` / `StudioWarningBadge`; no new hue introduced.

## 2026-08-08 — Opacity is for edges, not areas or text

Scope: app-wide (targeted hot spots this round)  
Status: Approved  

Rationale: Stacking `hue.opacity(x)` fills and translucent hierarchy text (`labelColor@alpha`,
system `.secondary`/`.tertiary`) over translucent panel chrome produced washed/muddy results —
especially amber banners, selection+chip stacks, and column headers over tinted rows.

**Rule:** opacity stays on edges (`*Stroke`, dividers, drag tints, focus rings). Area fills and
text that must stay crisp are opaque, pre-composited tokens:

- `StudioOpaqueFill` — bakes an arbitrary hue@alpha over the window background (semantic /
  selection fills, tag/registration/code backgrounds, diff pill fills).
- `StudioOpaquePanelWash` — bakes `labelColor@alpha` over the window background (neutral text
  tokens + `chipSurface` / selection-neutral / hover fills).

Migrated this round: status/instancer/registration/code/tag fills; selection + hover fills;
`sectionHeading` / `mutedForeground` / `textPlaceholder` / `primaryMuted`; Axis Tree stop-table
column headers (`.tertiary` → `sectionHeading`). Neutral panel chrome (`surface*`, field fills)
and general `.secondary`/`.tertiary` prose on plain panels stay as-is.

## 2026-08-08 — Sticky headers opaque; warning amber retuned; small neutrals raised

Scope: targeted (Review sticky pins, Issues banners, tag/subtitle chrome)  
Status: Approved  

Rationale: Follow-up audit after the opaque-token pass showed three remaining gaps:

1. **Sticky bleed** — Save Review / Instancer phase headers used translucent
   `surfaceMuted`, so scrolling rows showed through pinned titles ("AXIS RECORDS").
   New `stickyHeaderFill` (`StudioOpaquePanelWash` at the same wash strength) is the
   phase-header background.
2. **Brown Issues amber** — baking `Color.orange` @ 0.22 over a dark window composites
   to muddy brown (~`#5B4423`). `warningFill` / `warningFillHover` are now authored
   dual-tone solids (`StudioHuedToken`) that stay peach-amber in light and saturated
   amber in dark. Mark hue + strokes unchanged.
3. **Faint small neutrals** — tag pill labels (`ousd`/`insd`) used system `.secondary` on
   a light wash; Review field subtitles (`STAT`/`fvar`) used `.tertiary`. Tags now use a
   stronger opaque `tagForeground` + slightly deeper `tagBackground`; subtitles/secondary
   lines use `mutedForeground`.

## 2026-08-08 — Issues band: summary strip vs detail body

Scope: Axis Tree plan-warnings band  
Status: Approved  

Rationale: Nesting `StudioConflictAlert` (its own `warningFill`) inside an outer
`warningFill` card made the “N issues to review” row indistinguishable from the specific
warnings beneath. One card, two amber tiers:

- `warningFillStrong` — summary header strip
- `warningFill` — detail body / standalone banners
- `warningFillHover` — brightest CTA chips (must clear both fills)

Hairline `warningStroke` between header and details. “Show in list…” link uses `.accent`
so it stays legible on amber. Standalone `StudioConflictAlert` (Inspector / single conflict)
unchanged.

## 2026-08-08 — Warning CTA: shared role + dark label on amber

Scope: app-wide warning Review / Resolve chips  
Status: Approved  

Rationale: Axis-header `Review…` still used soft `warningFill` while the Issues band used
bright `warningFillHover`. White / `.primary` on that bright amber only clears ~3:1 (dark)
/ ~1.9:1 (light). All warning CTAs now share `StudioFlatButton.Role.warningAction`
(`warningFillHover` + `warningButtonForeground` = ink). `.tinted` honors its label color
again so soft fills (registration) keep `.primary` text.
