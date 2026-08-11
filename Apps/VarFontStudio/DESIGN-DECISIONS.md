# VarFont Studio — Design Decisions Log

Append-only running log for color, typography, spacing/density, and stroke decisions.
Check this file **and** the token enums (`StudioColors`, `StudioPalette`, `StudioTypography`,
`StudioSpacing` / `StudioDensity`, `StudioStroke`, `StudioRadius`) before adding new styling.

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

## 2026-08-09 — Concentric radius ladder + continuous corners

Scope: app-wide  
Status: Approved  

Rationale: `StudioRadius` values were unrelated (control parked at 5; `.row` at 6 reused for
hit-boxes, materials, and padded warning cards). Nested corners read tight because
SwiftUI’s default `.circular` curve is more mechanical than system chrome, and padded
cards used the same 6pt as buttons.

**Ladder (concentric — outer ≈ inner + padding at that boundary):**

| Token | pt | Role |
|-------|----|------|
| `hairline` | 2 | Gutter stripes / checkbox ticks |
| `small` | 3 | Micro / compact segment corners |
| `chip` | 4 | Pills, badges, naming chips |
| `control` | **6** | Buttons, fields, drag rings — **nest anchor** |
| `surface` | 10 | Padded inset cards / warning banners / material trays |
| `panel` | 16 | Large panel chrome (available; sparse today) |

**Curve:** `RoundedRectangle.studio(_:)` always uses `.continuous`. Prefer it at every
fill / stroke / contentShape call site. `StudioDragOutline.cornerRadius` → `control`.
Removed the old `.row` token (call sites mapped to `control` or `surface`).

## 2026-08-09 — Live color map (comment/doc sync)

Scope: docs + comments only (no token rebinds)  
Status: Approved  

User-tuned palette is locked; comments/DESIGN entries that still said purple STAT,
cyan edited, graphite code, amber CTA fills, etc. are outdated. **Live families:**

| Role | Family |
|------|--------|
| brand / selection / metric | blue |
| warning containers + CTA fill (`warningFill*`) | yellow |
| warning marks (`warningForeground`) | amber |
| edited + code | teal (code uses a darker step) |
| pending | emerald |
| registration / clarifier | fuchsia |
| STAT format badges | rose |
| custom | indigo |
| `diffRenamed` | orange |

`COLOR_OUTLINE.md` remains historical — trust `StudioColors` over that file.

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
tertiary = lightest legible. Exemplar: `statFormat1/2/3` = rose primary/secondary/tertiary.
Do not use `forestGreen` until Figma re-check (dark export quirk).

Apple system colors remain for true semantic chrome (`.primary` / `.secondary` /
`.tertiary`, warning marks, success/error where they mean platform status). HIG is a
reference for finicky calls — not a redesign mandate.

## 2026-08-08 — Pending export = emerald-green; edited stays teal

Scope: app-wide  
Status: Approved  

Rationale: Pending export previously borrowed `editedForeground` (teal), colliding with
“name edited from default” on the same rows. Emerald is unclaimed and far from teal.
Token: `StudioColors.pendingForeground` / `pendingFill`.

## 2026-08-08 — Registration / code / STAT / diff accents rebound to palette

Scope: app-wide  
Status: Approved  

> **Superseded steps/families:** see **2026-08-09 — Live color map**. Table below is the
> original bind; live code now uses fuchsia / teal / rose / orange for several rows.

| Role | Family (original bind) | Light / dark steps |
|------|--------|--------------------|
| `registrationForeground` | magenta → **fuchsia** | 500 / 300 |
| `codeForeground` | jade-green → **teal** | 500 / 300 |
| `statFormat1/2/3` | purple → **rose** | 300·500·700 / 300·200·100 |
| `diffAdded` | green | 600 / 200 |
| `diffRemoved` | red | 400 / 200 |
| `diffReflowed` | violet | 400 / 200 |
| `collisionForeground` | pink | 600 / 300 |
| `customForeground` | indigo | 300 / 200 |
| `editedForeground` | cyan → **teal** | 500 / 200 |

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

## 2026-08-08 — StudioPalette = Tailwind v4 chromatic (sRGB)

Scope: app-wide  
Status: Approved  

Rationale: Bespoke Figma-export hex + hand-tuned warning browns were muddy and hard to
extend. `StudioPalette` now stores Tailwind CSS v4 chromatic families (official OKLCH →
sRGB hex), steps 50–950, one scale per family with light/dark step selection at bind time.
`StudioColors` remains the only call-site API. Neutrals stay Apple system + washes (no
slate/zinc). `brand` / `metricForeground` stay bespoke this round.

## 2026-08-08 — Brand blue → Tailwind solid steps

Scope: app-wide brand / selection / metric  
Status: Approved  

Rationale: Bespoke royal-blue + `brand@0.16` baked over charcoal composited to
~`#1B303F` — reads indigo/teal next to the strong Export CTA. Metric was a separate
steel-blue hex, so the app showed three different “blues.”

One Tailwind **blue** family, solid area fills:

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `brand` | 600 | 600 | Mark + primary CTA (white label ~5:1) |
| `metricForeground` | 700 | 400 | Scannable counts (same family, off-CTA) |
| `selectionFill` / `brandBackground` | 100 | 900 | Selected rows, segments, brand chips |
| `selectionFillSoft` / `canvasHoverFill` | 50 | 950 | Quieter wash (composed-name callout) |
| `brandFillDisabled` | 200 | 800 | Disabled primary button |

Call-site cleanups: segment selected → `selectionFill`; composed-name callout →
`selectionFillSoft` (was `selectionFill.opacity(0.35)`); disabled primary →
`brandFillDisabled`. Drop-zone / 1pt tick overlays keep `.opacity()` (transient or edge).

## 2026-08-08 — Selection wash + segment label contrast

Scope: `selectionFill` / composed-name header / `StudioSegmentButton`  
Status: Approved  

Rationale: Selected segments used `brand` (600) on `selectionFill` (100/900) —
~2:1 in dark (blue-on-blue), and light `100` was nearly invisible on white chrome.
Inspector composed-name header (deep navy + bright stripe) was the clearer pattern.

Retune:

- `selectionFill` → light `200` / dark `950` (perceptible wash; matches header navy)
- `selectionFillSoft` → light `100` / dark `950`
- Composed-name callout → `selectionFill` (same fill as selected segments/rows)
- Selected segment label → `metricForeground` (700/400), not `brand` — clears ~4.8:1
  light / ~5.6:1 dark on the wash; dark 400 reads as the bright accent beside the stripe

`brand` stays 600 for CTAs / leading stripes only.

## 2026-08-08 — Preview alignment: neutral raised segments

Scope: `FontPreviewHeaderControls` alignment picker  
Status: Approved  

Rationale: Alignment is a mutually exclusive tray choice (like Names|Coords), not a
brand/selection locus. Brand fill + `brand.opacity(0.12)` made Preview look like a
different control system and reintroduced muted blue.

Restyled onto `StudioCompactControlChrome`: shared `idleFill` tray, selected =
`activeFill` (neutral raised), idle segment clear, `foreground(isActive:)`. No brand.

## 2026-08-08 — Preview status pill + compact size slider

Scope: `FontPreviewPanel` status bar / size control  
Status: Approved  

Rationale: Peek pill used `canvasHoverFill` → `selectionFillSoft`, which is navy in
dark mode on the always-paper status strip — ink-on-navy ~illegible. Mini `Slider`
drew macOS tick marks and fought compact chrome.

- `canvasHoverFill` → fixed light `blue-100` (paper world); add `canvasPeekForeground`
  (`blue-800`) for Peek label contrast
- Source · live = stroke-only quiet; Peek · hover = soft blue fill + blue-800 label
- Size → `StudioCompactSlider` (thin neutral track, capsule thumb, no system ticks)
- Removed stray duplicate “Select an instance…” label before the pill

## 2026-08-09 — Drag outline: uniform 4pt / 6pt radius

Scope: Axis Tree reorder + Naming Order chip drag  
Status: Approved  

Rationale: Dashed hover/ghost/target rings used horizontal-only outset (`outlineHorizontalOutset`),
so Naming Order looked wide on the sides and tight top/bottom; Axis Tree overlays were flush
or uneven against header padding.

`StudioDragOutline` — outset `4`, corner radius `6`, shared `expandedRing` helper.
`studioDragAffordances` always uses that ring (dropped per-call horizontal outset).
Axis Tree later overrides to **8pt horizontal / 4pt vertical** via `axisTreeOutset*`.
Source placeholder, floating ghost, and empty drop target all share the same content size
(header frame) and the same outset ring — the drop slot is no longer a smaller inset dashed box.

Axis Tree targeting freezes header frames at pickup so inserting the drop gap cannot
oscillate midY hit-testing. Expand controls on the header use taps (not Buttons) so
click-and-hold reorder can start from the name/chevron.

Warning chrome remapped to Tailwind **amber** (not orange): fills 100/200/300 × dark
900/800/600; mark 600/400. CTA ink still clears ≥5:1 on `warningFillHover`.

Role family map after adoption: registration → fuchsia; code → teal; pending → emerald;
success/error marks → green/red; `diffRenamed` → orange; STAT **rose** ramp.

## 2026-08-08 — Warning: yellow containers, amber marks/CTAs

Scope: app-wide warning chrome  
Status: Approved  

Rationale: All-amber Issues bands made triangles and Review buttons fight the fill.
Split Tailwind families:

- **yellow** — `warningFill` / `warningFillStrong` (conflict containers, summary strip,
  warning row wash) **and** `warningFillHover` (Review CTA chip fill — live)
- **amber** — `warningForeground` / `warningStroke` (triangles / marks only)

`diffRenamed` moves to **orange** so yellow stays reserved for warning containers.
Neutrals and system text hierarchy (`.primary` / `.secondary` / `.tertiary`) unchanged;
chromatic accents continue to bind through `StudioPalette` → `StudioColors`.

## 2026-08-08 — Warning yellow/amber steps + ink on fill

Scope: app-wide warning chrome  
Status: Approved  

Rationale: Dark yellow **700–900** read muddy mustard on charcoal; light washes were a
shade too pale. Retune:

- **yellow** fills — light `200`/`300`; dark mid gold (skip 700–900)
- **yellow** CTA (`warningFillHover`) — steps above the container wash
- **amber** marks — so triangles clear the yellow wash
- Body copy on yellow containers uses `warningOnFillForeground` (ink) — white `.primary`
  fails AA on mid yellows in dark mode

CTA labels stay `warningButtonForeground` = ink on `warningFillHover`.

## 2026-08-08 — Muted chips: opacity-on-fill audit

Scope: app-wide badge/chip fills  
Status: Approved  

Rationale: Palette hex was already exact-match to Tailwind v4, but several chip fills
still applied `.opacity()` directly to a chromatic color as an area fill (STAT `fvar`
source pill, `statFormat1` "F4" capsule, Instance List "Conflicts" filter unselected
state, Instancer filter badges). Per the existing opaque-fill principle, that lets
whatever's behind the chip (often a translucent/vibrant panel) bleed through and wash
out the hue — reads muted even though the underlying color is correct.

Added baked (`StudioOpaqueFill`-composited) tokens instead of ad hoc `.opacity()`:

- `brandBackground` — brand badge fill (was `brand.opacity(0.16)`)
- `statFormat1Background` — compound-name F4 capsule (was `statFormat1.opacity(0.16)`)
- `warningFillSoft` — Conflicts filter unselected state (was `warningFill.opacity(0.45)`,
  which re-added translucency on top of an already-solid Tailwind step)
- `StudioColors.opaqueFill(_:light:dark:)` — general escape hatch for call sites that
  pick their tint dynamically (Instancer per-row filter badges) and can't predeclare a
  named token

Left alone: hairline strokes and 1–1.5pt tick/divider rectangles — `.opacity()` is still
correct there per the "opacity for edges only" rule.

## 2026-08-10 — Combinations builder: neutral selection

Scope: Combinations drawer add/edit chips  
Status: Approved  

Rationale: Brand `selectionFill` / `selectionStroke` on axis pills, stop shortcuts, and
chain chips made the Format 4 add flow hard to read (blue wash + white/ink competition).
Builder and edit pickers now use neutral surfaces only:

- Idle: `surfaceMuted` + `surfaceStroke`
- Selected/active: `surfaceInset` / `surfaceSubtle` + `surfaceStrokeStrong`
- Primary **Add** CTA stays `StudioFlatButton.Role.primary` (same as Add Stop sheets)

Interaction: sequential axis+value legs with **+** / lock-then-name, still in the drawer
(macOS sheets block Axis Tree scrolling).

## 2026-08-10 — Import Review sheet (seeder gate)

Scope: fvar → STAT import review  
Status: Approved  

Rationale: Blanket Format 1 seeding from fvar densifies sparse catalogs (Ease) beyond
designer intent. Gate:

- Quiet when orthogonal + well-named
- Import Review sheet when combo-only coords, grid expansion, Format 4 suggestions,
  conflicts, or sparse/shared instance names

Chrome: neutral surfaces for callouts; Format 4 section stays non-issue styling; naming
sparsity is informational (coords still seed with value-as-name). True STAT/fvar name
conflicts can keep warning chips inside the sheet.

Hierarchy (2026-08-10 polish): summary orients with instance-count metrics
(original → with recommendations → if everything promotes) and plain-language bullets.
Primary path: **Accept recommendations** (combo-only held stops; Format 4 left for the
Combinations drawer) or **Review choices** to expand decision sections — same idea as
conflict walkthrough vs batch accept.

Expansion is **not** a peer decision section. It nests under “Stops to decide” as a live
consequence of Promote / Combo only / Ignore. Samples show **projected STAT-composed
names** (via `NamingComposer`) as primary, coords secondary — e.g. SemiRounded SemiDisplay
from Outside 20 × Inside 50 — clarifying these are orthogonal naming products absent from
fvar.

Stop choices teach on select: Promote = Format 1 (optional name field, default value-as-name);
Combo only = Format 4 reservation only; Ignore = neither.

**Shipped:** “Keep only styles from the font” / **Trim Non-Originals** via plan prune —
`includedInstanceKeys` whitelist (plan keys matching fvar through `InstanceInclusion`).
Import Review defaults the checkbox on when invented combinations exist; Instance panel
**Include** menu carries Include All / Exclude All / Trim Non-Originals. Prefer prune
over demoting orthogonal Format 1 into Format 4. Checkboxes edit the whitelist when
active; Include All clears the whitelist (Cmd+Z restores). Re-trim after stop edits via
the Include menu — not auto on every plan change.

