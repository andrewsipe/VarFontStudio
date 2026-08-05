# VarFont Studio — Color Outline

Living reference for `StudioColors` and semantic-mark usage. **Canonical tokens:** `Views/StudioDesign.swift` → `enum StudioColors` and the **Color system (semantic marks)** comment block above it.

**Rule:** Semantic hue = **mark** (stripe, gutter, fill, icon, badge stroke). Readable hue = **text** (`.primary` / `.secondary` / `.tertiary`).

---

## Custom palette (decided)

System `Color.indigo` and `Color.brown` are retired for file semantics — indigo reads too close to brand blue; brown is muddy on neutral chrome. **Blue stays primary** for interaction; **status hues unchanged** (warning, error, collision, custom teal, etc.).

| Token | Hex (light ≈) | Role | Replaces |
|-------|---------------|------|----------|
| `metricForeground` | `#1565B8` | Scannable **digits** in panel headers, count badges, summary cards | Accent-colored header numbers |
| `registrationForeground` | `#8E4A9F` | Design-record / PS / clarifier **marks** | `Color.indigo` |
| `codeForeground` | `#5C6570` | OpenType classification **chip** hue | `Color.brown` |
| `textPlaceholder` | ~42% label wash | Field and search **placeholder** copy | `.tertiary` in inputs |

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#1565B8"></div>
    </div>
    <div class="swatch-label">metricForeground</div>
    <div class="swatch-meta">steel blue · text</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#8E4A9F"></div>
      <div class="swatch-mini" style="background:rgba(142,74,159,.22)"></div>
    </div>
    <div class="swatch-label">registration</div>
    <div class="swatch-meta">plum violet · mark</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#5C6570"></div>
      <div class="swatch-mini" style="background:rgba(92,101,112,.22)"></div>
    </div>
    <div class="swatch-label">code</div>
    <div class="swatch-meta">graphite · mark</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:rgba(0,0,0,.42)"></div>
    <div class="swatch-label">textPlaceholder</div>
    <div class="swatch-meta">adaptive wash</div>
  </div>
</div>

### Readability tiers

| Tier | Token / API | Use |
|------|-------------|-----|
| Body | `.primary` | Labels, values, enabled buttons (`StudioFlatButton` secondary) |
| Heading | `sectionHeading` | Section titles (`StudioSectionLabel`), phase headers, column headers — verified ~4.8–5.2:1 in both appearances |
| Supporting | `.secondary` | Unit words (“shown”, “files”), meta labels |
| Placeholder | `textPlaceholder` | Search and field prompts only |
| Muted | `.tertiary` / `.quaternary` | **Intentionally** de-emphasized: chevrons, separators, disabled-adjacent chrome — never readable headers or column labels |
| Metric | `metricForeground` | Header counts and numeric badges — not interaction |

### Contrast reference (keep)

- **Primary buttons** — white on `brand` (`StudioFlatButton` `.primary`) ✓
- **Secondary buttons** — `.primary` on gray fill ✓
- **Scope tabs** — selected: `brand` on `brand` @ 16%; unselected: ~78% primary (not `.secondary`)
- **Search** — `textPlaceholder` for icon + prompt (not `.tertiary`)

---

## Swatch legend

- **Hue** — full-strength mark color (`*Foreground` or base `Color.*`)
- **Fill** — typical semantic wash on white (`*Fill` / `*Background` at documented opacity)
- System colors (`Color.blue`, `Color.orange`, …) follow **macOS dynamic system colors**; hex below are **light-mode approximations** for review only.

<style>
  .swatch-grid { display: flex; flex-wrap: wrap; gap: 12px; margin: 12px 0 24px; }
  .swatch { width: 88px; text-align: center; font-size: 10px; line-height: 1.3; color: #333; }
  .swatch-box { width: 72px; height: 48px; margin: 0 auto 6px; border-radius: 6px; border: 1px solid rgba(0,0,0,.12); }
  .swatch-box.on-dark { border-color: rgba(255,255,255,.2); }
  .swatch-label { font-weight: 600; }
  .swatch-meta { color: #666; font-family: ui-monospace, monospace; font-size: 9px; }
  .swatch-row { display: flex; gap: 4px; justify-content: center; margin-bottom: 4px; }
  .swatch-mini { width: 34px; height: 28px; border-radius: 4px; border: 1px solid rgba(0,0,0,.1); }
  .swatch-section { margin-top: 28px; }
  h3 { margin-top: 1.5em; }
</style>

---

## Tier 0 — Text & chrome (no semantic hue)

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-box" style="background:#000000"></div>
    <div class="swatch-label">Text primary</div>
    <div class="swatch-meta">`.primary`</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:#6B6B6B"></div>
    <div class="swatch-label">Text secondary</div>
    <div class="swatch-meta">`.secondary`</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:#AEAEAE"></div>
    <div class="swatch-label">Text tertiary</div>
    <div class="swatch-meta">`.tertiary`</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:rgba(0,0,0,.055)"></div>
    <div class="swatch-label">surfaceSubtle</div>
    <div class="swatch-meta">wash ~5.5%</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:rgba(0,0,0,.08)"></div>
    <div class="swatch-label">hoverFill</div>
    <div class="swatch-meta">wash ~8%</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:rgba(0,0,0,.09)"></div>
    <div class="swatch-label">fieldFill</div>
    <div class="swatch-meta">wash ~9%</div>
  </div>
</div>

**Opacity scale (chrome):** `0.03`–`0.16` — neutral washes only. Should feel nearly invisible.

---

## Tier 1 — Brand (interaction)

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#0858F7" title="Hue (light)"></div>
      <div class="swatch-mini" style="background:rgba(8,88,247,.16)" title="Fill"></div>
    </div>
    <div class="swatch-label">brand</div>
    <div class="swatch-meta">Bespoke `royal-blue` (dual-tone)</div>
    <div class="swatch-meta">light #0858F7 / dark #5686E6</div>
  </div>
</div>

Moved off system `Color.blue` (Phase C) — sat too close to `metricForeground`'s steel blue to read
as its own hue once diluted through `selectionFill`/`selectionStroke`. `royal-blue` verified
≥4.5:1 in both appearances.

| Token | Role | Mark surfaces |
|-------|------|----------------|
| `brand` | Interaction, focus, selection | Link **hover/press**, caret, checkbox on, dirty dot, row `selectionFill` |
| `selectionFill` | Selected row | `brand` @ 16% (was 10% — raised Phase C) |
| `selectionStroke` | Rare focus ring | `brand` @ 30% (was 20% — raised Phase C) |
| `metricForeground` | Scannable digits | Panel header counts, `StudioCountBadge`, summary card values |

**Not for:** file registration, diff categories, axis semantics.

**Links:** idle `.primary` → hover/press `brand` (`StudioLinkForeground` `.accent`).

---

## Tier 2 — Status vocabulary (shared meaning)

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF9500"></div>
      <div class="swatch-mini" style="background:rgba(255,149,0,.22)"></div>
    </div>
    <div class="swatch-label">warning</div>
    <div class="swatch-meta">orange · fill 22%</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF3B30"></div>
      <div class="swatch-mini" style="background:rgba(255,59,48,.24)"></div>
    </div>
    <div class="swatch-label">error</div>
    <div class="swatch-meta">red</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#34C759"></div>
      <div class="swatch-mini" style="background:rgba(52,199,89,.24)"></div>
    </div>
    <div class="swatch-label">success / added</div>
    <div class="swatch-meta">green</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF2D55"></div>
      <div class="swatch-mini" style="background:rgba(255,45,85,.24)"></div>
    </div>
    <div class="swatch-label">collision</div>
    <div class="swatch-meta">pink</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#30B0C7"></div>
      <div class="swatch-mini" style="background:rgba(48,176,199,.24)"></div>
    </div>
    <div class="swatch-label">custom</div>
    <div class="swatch-meta">teal</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#32ADE6"></div>
      <div class="swatch-mini" style="background:rgba(50,173,230,.24)"></div>
    </div>
    <div class="swatch-label">edited / export</div>
    <div class="swatch-meta">cyan</div>
  </div>
</div>

**Opacity scale (semantic fills):** `0.20`–`0.30` — stronger than chrome; must read as “this row means something.”

| Hue | Tokens | Means | Where |
|-----|--------|-------|-------|
| Orange | `warningForeground`, `warningFill`, `axisValue`† | **Caution / attention** | Warning icons, fallback flags, axis-header ⚠, conditional dots |
| Red | `errorForeground`, `diffRemoved` | **Failure / removed / severe** | Error banner icons, exact-duplicate stripes, diff gutters |
| Green | `successForeground`, `successFill`, `diffAdded`, `dropNewProject` | **Success / addition** | Checkbox ✓, diff “added”, new-project drop, status pill fill |
| Blue | `brand`, `dropAddExisting` | **Interaction / add-to-project** | Selection, links, add-font drop |
| Pink | `collisionForeground` | **Soft collision** | Instancer stripe, ◆ symbol |
| Teal | `customForeground` | **User custom instance** | Instancer stripe, ＋ symbol |
| Cyan | `editedForeground` | **Studio-origin** | “Studio export” badge fill |

† `axisValue` = orange hue reserved for **conditional** dots only (e.g. missing axis); not on every value row.

---

## Tier 3 — File semantics

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#8E4A9F"></div>
      <div class="swatch-mini" style="background:rgba(142,74,159,.22)"></div>
    </div>
    <div class="swatch-label">registration</div>
    <div class="swatch-meta">plum violet · 22%</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#5C6570"></div>
      <div class="swatch-mini" style="background:rgba(92,101,112,.22)"></div>
    </div>
    <div class="swatch-label">code</div>
    <div class="swatch-meta">graphite · 22%</div>
  </div>
</div>

| Hue | Tokens | Means | Mark surfaces |
|-----|--------|-------|----------------|
| Plum violet | `registrationForeground`, `registrationBackground`, `clarifier*` | Design-record / PS / clarifier | 3pt leading bar (registration stops), naming-chain chip fills |
| Graphite | `codeForeground`, `codeBackground` | OpenType classification code | Code column pill (axis tree, naming) |

Clarifier aliases share plum (`clarifierForeground` = `registrationForeground`). Custom fixed RGB — not `Color.indigo` / `Color.brown`.

---

## Tier 4 — Save Review diff

`diffRemoved`/`diffAdded`/`diffReflowed` moved off system red/green/purple to the bespoke accent
palette (Phase C) — Save Review's diff gutters are the highest-traffic large-scale color-coding
in the app, distinct from the small system-color indicators that are fine left alone.
`diffProtected` (gray) and `diffRenamed` (yellow) stay system — deliberately neutral slate for
the former, and no yellow family exists in the extracted palette for the latter.

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#D2271E" title="light"></div>
      <div class="swatch-mini" style="background:#E5A8A4" title="dark"></div>
    </div>
    <div class="swatch-label">diffRemoved</div>
    <div class="swatch-meta">bespoke red</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#3A6F20" title="light"></div>
      <div class="swatch-mini" style="background:#4B9D4B" title="dark"></div>
    </div>
    <div class="swatch-label">diffAdded</div>
    <div class="swatch-meta">bespoke green</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#9F2EDC" title="light"></div>
      <div class="swatch-mini" style="background:#CCACDC" title="dark"></div>
    </div>
    <div class="swatch-label">diffReflowed</div>
    <div class="swatch-meta">bespoke purple</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#8E8E93"></div>
      <div class="swatch-mini" style="background:rgba(142,142,147,.20)"></div>
    </div>
    <div class="swatch-label">diffProtected</div>
    <div class="swatch-meta">gray · locked</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FFCC00"></div>
      <div class="swatch-mini" style="background:rgba(255,204,0,.20)"></div>
    </div>
    <div class="swatch-label">diffRenamed</div>
    <div class="swatch-meta">yellow · info</div>
  </div>
</div>

| Token | Hue | Meaning | Deliberate split |
|-------|-----|---------|------------------|
| `diffRemoved` | Red (bespoke) | Row removed | Shares error vocabulary |
| `diffAdded` | Green (bespoke) | Row added | Shares success / `dropNewProject` (hue diverges from Phase C on) |
| `diffReflowed` | Purple (bespoke) | Layout-only change | Diff-only |
| `diffProtected` | Gray | Locked / non-editable | **Not** brand blue |
| `diffRenamed` | Yellow | Name/value changed | **Not** warning orange |

**Row pattern:** colored **gutter** + category **pill** (neutral text) + neutral **value** string.

---

## Tier 5 — STAT format (category)

Moved off three blue-gray/violet tones that sat within ~15-20° of each other and of
`brand`/`metricForeground` (Phase C) — swapped for bespoke `brown`/`violet`/`magenta`, spread
across the wheel.

**Mode-dependent treatment** — the two appearances need opposite text/fill strategies:

- **Light:** hue-colored label on a 20% translucent tint of the same hue (exception to the
  "mark hue on fill/border, label stays `.primary`" rule — with only 3 short glyphs shown
  side-by-side and no icon to anchor on, a neutral label meant the badges were distinguishable
  only by reading text). Light-mode stops are deep/saturated enough that text-vs-fill
  separation holds at 20%.
- **Dark:** the dark-mode stops are intentionally pale (that's what clears 4.5:1 as *text*
  against a near-black panel) — reusing that same pale hue for a 20% fill collapsed text and
  fill into one low-contrast blob. Dark mode instead uses a near-solid (92%) fill of the pale
  hue with near-black label text (`Color.black.opacity(0.82)`) — the pale color's luminance
  guarantees strong contrast against dark text while the fill itself stays a fully legible hue.

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#A05D2C" title="light"></div>
      <div class="swatch-mini" style="background:#B78562" title="dark"></div>
    </div>
    <div class="swatch-label">statFormat1</div>
    <div class="swatch-meta">F1 brown</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#7347EB" title="light"></div>
      <div class="swatch-mini" style="background:#9D85E0" title="dark"></div>
    </div>
    <div class="swatch-label">statFormat2</div>
    <div class="swatch-meta">F2 violet</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#AB2AAC" title="light"></div>
      <div class="swatch-mini" style="background:#BD64BE" title="dark"></div>
    </div>
    <div class="swatch-label">statFormat3</div>
    <div class="swatch-meta">F3 magenta</div>
  </div>
</div>

Dual-tone, verified ≥4.5:1 in both appearances — **not** success green, edited cyan, or brand
blue. Distinguish F1/F2/F3 by hue at a glance, not just by reading the label.

---

## Tier 6 — Canvas (font preview only)

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-box" style="background:#FFFFFF"></div>
    <div class="swatch-label">canvasBackground</div>
    <div class="swatch-meta">#FFFFFF fixed</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:#000000"></div>
    <div class="swatch-label">canvasForeground</div>
    <div class="swatch-meta">#000000 fixed</div>
  </div>
  <div class="swatch">
    <div class="swatch-box" style="background:rgba(0,0,0,.55)"></div>
    <div class="swatch-label">canvasSecondary</div>
  </div>
</div>

Never used in Review, Instancer, or inspector tables. Preview panel forces light appearance for glyph proofing.

---

## Mark types (how hue appears)

| Mark | Width / shape | Examples |
|------|----------------|----------|
| **Leading stripe** | 3pt solid rectangle | Instancer flagged rows (`StudioSemanticLeadingStripe`) |
| **Leading gutter** | 3pt rounded bar | Save Review diff rows |
| **Leading edge bar** | 3pt on axis stop | Registration stops (indigo) |
| **Pill fill + stroke** | Rounded rect / capsule | Tags, diff badges, STAT F1–F3, naming chips |
| **Banner fill** | Rounded rect | `warningFill`; icon colored, body `.primary` |
| **Icon** | SF Symbol | `StudioWarningBadge`, error octagon, fvar ⓓ default |
| **Dot** | 4pt circle | **Conditional only** (e.g. `missingAxis`) |
| **Row selection** | Full-row wash | `selectionFill` (brand 10%) |

---

## By UI area

| Area | Hues in play |
|------|----------------|
| **Axis tree** | Indigo bar, brown code pill, brand selection, orange ⚠ icon |
| **Instancer** | Teal / pink / red / orange **stripes**; neutral row text |
| **Save Review** | Diff gutters + pills; neutral values |
| **Naming footer** | Indigo / brown / clarifier chip **fills**; neutral labels |
| **Font preview** | `canvas*` only |
| **Chrome** | `surface*` + `.bar`; no semantic hue on body |

---

## Consistency checklist

### Shared vocabulary (working)

- **Green** = creation (`diffAdded`, `dropNewProject`, `successForeground`)
- **Red** = harm / removal / severe (`diffRemoved`, `errorForeground`)
- **Indigo** = file identity (registration, clarifier, PS)
- **Brand blue** = interaction + add-to-project drop (`brand`, `dropAddExisting`)
- **Text** = neutral ladder everywhere

### Watch list

| Tension | Notes |
|---------|--------|
| Orange dual role | `warningForeground` vs `axisValue` — OK while axis dots stay conditional |
| Yellow vs orange | `diffRenamed` vs warning — close in warmth; verify dark mode |
| Pink vs red | Collision vs exact duplicate — both “something wrong,” different severity |
| Cyan underused | Only “Studio export” today; don’t reuse for other “edited” without token |
| STAT vs indigo | Both cool; fine unless adjacent on same row |
| `diffProtected` gray | May read “disabled” vs “locked” |

### Audit rule (new tokens)

1. Does this hue already mean something in the table above? → reuse token + mark type.
2. Is it **status** (shared vocabulary) or **category** (arbitrary distinguisher)?
3. Category labels must **not** borrow green, red, orange, blue, or indigo from status/file roles.

---

## Standard SwiftUI palette inventory

What macOS **named** `Color.*` values the app uses, what’s available but unused, and what’s deliberately avoided.  
*Audited from `VarFontStudio` Swift sources; chromatic hues route through `StudioColors` when used semantically.*

### Hierarchical text (all in use)

| API | Role in app |
|-----|-------------|
| `.primary` | Body text, values, links at idle |
| `.secondary` | Metadata, de-emphasized labels, `tagForeground` |
| `.tertiary` | Hints, column headers, placeholders |
| `.quaternary` | Faintest chrome copy (instance list empty states, panel split labels) |

### Chromatic system colors — used

Each hue below appears in `StudioColors` (or canvas/drop tokens). Left swatch = system hue (light-mode ≈); right = typical semantic fill.

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#007AFF"></div>
      <div class="swatch-mini" style="background:rgba(0,122,255,.10)"></div>
    </div>
    <div class="swatch-label">blue</div>
    <div class="swatch-meta">→ `brand`</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#5856D6"></div>
      <div class="swatch-mini" style="background:rgba(88,86,214,.22)"></div>
    </div>
    <div class="swatch-label">indigo</div>
    <div class="swatch-meta">→ registration</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#AF52DE"></div>
      <div class="swatch-mini" style="background:rgba(175,82,222,.20)"></div>
    </div>
    <div class="swatch-label">purple</div>
    <div class="swatch-meta">→ diffReflowed</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF2D55"></div>
      <div class="swatch-mini" style="background:rgba(255,45,85,.24)"></div>
    </div>
    <div class="swatch-label">pink</div>
    <div class="swatch-meta">→ collision</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF3B30"></div>
      <div class="swatch-mini" style="background:rgba(255,59,48,.24)"></div>
    </div>
    <div class="swatch-label">red</div>
    <div class="swatch-meta">→ error, diffRemoved</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FF9500"></div>
      <div class="swatch-mini" style="background:rgba(255,149,0,.22)"></div>
    </div>
    <div class="swatch-label">orange</div>
    <div class="swatch-meta">→ warning, axisValue</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#FFCC00"></div>
      <div class="swatch-mini" style="background:rgba(255,204,0,.20)"></div>
    </div>
    <div class="swatch-label">yellow</div>
    <div class="swatch-meta">→ diffRenamed</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#34C759"></div>
      <div class="swatch-mini" style="background:rgba(52,199,89,.24)"></div>
    </div>
    <div class="swatch-label">green</div>
    <div class="swatch-meta">→ success, diffAdded, drop</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#30B0C7"></div>
      <div class="swatch-mini" style="background:rgba(48,176,199,.24)"></div>
    </div>
    <div class="swatch-label">teal</div>
    <div class="swatch-meta">→ custom</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#32ADE6"></div>
      <div class="swatch-mini" style="background:rgba(50,173,230,.24)"></div>
    </div>
    <div class="swatch-label">cyan</div>
    <div class="swatch-meta">→ edited</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#A2845E"></div>
      <div class="swatch-mini" style="background:rgba(162,132,94,.22)"></div>
    </div>
    <div class="swatch-label">brown</div>
    <div class="swatch-meta">→ code</div>
  </div>
  <div class="swatch">
    <div class="swatch-row">
      <div class="swatch-mini" style="background:#8E8E93"></div>
      <div class="swatch-mini" style="background:rgba(142,142,147,.20)"></div>
    </div>
    <div class="swatch-label">gray</div>
    <div class="swatch-meta">→ diffProtected</div>
  </div>
</div>

### Neutrals & utilities — used

| API | Role |
|-----|------|
| `Color.black` / `Color.white` | Canvas preview only (`canvas*`) |
| `Color.clear` | Layout spacers, invisible hit targets |
| `Color(white:)` | `canvasPhaseHeader` only (fixed 96% gray strip) |
| `Color(red:green:blue:)` | `statFormat1`–`3`, `registrationForeground`, `codeForeground`, `metricForeground` |
| `NSColor.labelColor` | `StudioPrimaryWash` neutral chrome (adaptive) |

### Unused standard chromatic hue

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-box" style="background:#00C7BE; border:2px dashed #999;"></div>
    <div class="swatch-label">mint</div>
    <div class="swatch-meta">not in build</div>
    <div class="swatch-meta">#00C7BE ≈</div>
  </div>
</div>

| Color | Status | Notes |
|-------|--------|-------|
| **`Color.mint`** | **Unused** | Only standard chromatic hue with no `StudioColors` assignment. Free for a new semantic if needed — visually between teal (custom) and green (success); avoid overlapping either. |

### Deliberately excluded

<div class="swatch-grid">
  <div class="swatch">
    <div class="swatch-box" style="background:linear-gradient(135deg,#007AFF 50%,#ddd 50%); opacity:.7; border:2px solid #c00;"></div>
    <div class="swatch-label">accentColor</div>
    <div class="swatch-meta">do not use</div>
  </div>
</div>

| API | Status | Notes |
|-----|--------|-------|
| **`Color.accentColor`** | **Excluded** | App uses fixed `brand` (bespoke `royal-blue`, Phase C) instead of system accent. `verify-ui-tokens.sh` fails if `Color.accentColor` appears outside `StudioDesign.swift`. Caret/selection use `brandNSColor`. |

### Raw `Color.*` outside `StudioColors`

These appear at call sites without a token wrapper — allowed patterns only:

| Occurrence | Files | Notes |
|------------|-------|-------|
| `Color.black` | `CommitDiffSheet`, `MainEditorView` | Shadows/overlays — not semantic |
| `Color.primary` / `.secondary` | Various | Text hierarchy (preferred over fixed hues) |

### `StudioColors` tokens defined but not referenced

Reserved or pending wiring — safe palette slots, not dead code to delete without audit:

| Token | Hue source | Likely intent |
|-------|------------|---------------|
| `collisionFill`, `collisionStroke` | pink | Row/badge fill — stripes use `collisionForeground` directly today |
| `customFill` | teal | Same pattern as collision |
| `codeForeground`, `clarifierForeground` | graphite / plum | Mark hue; call sites use `*Background` + neutral text |
| `dropZoneAddFill` | brand @ 5% | Drag overlay (pair with `dropAddExisting` border) |
| `surfaceStrokeEmphasized` | primary wash | Disabled-selected chip stroke |

---

## Opacity scales (summary)

| Scale | Range | Use |
|-------|-------|-----|
| Chrome wash | 0.03–0.16 | `surface*`, `hoverFill`, `fieldFill` |
| Semantic fill | 0.20–0.30 | `warningFill`, `*Fill`, `*Background`, diff pill fills |
| Drop drag | 0.05 | `dropZone*` overlays only |
| Selection | 0.16–0.30 | `selectionFill`, `selectionStroke` (brand) |

---

## Migration status

| Phase | Scope | Status |
|-------|--------|--------|
| 1 | Guidance in `StudioDesign.swift` | Done |
| 2 | Review values, axis column, Instancer flags; neutral text | Done |
| 3 | Pills, naming footer, sheets; lint checks | Done |
| 4 | No unconditional value dots; semantic fill scale; link idle; Instancer stripes; token splits | Done |
| 5 | Custom palette (registration, code, metric); readability contrast pass | Done |
| — | Axis value column affordance (post-dot) | **Open** |

---

## Related files

- `Views/StudioDesign.swift` — `StudioColors`, mark components (`StudioSemanticDot`, `StudioSemanticLeadingStripe`, `StudioAxisValueLabel`, `StudioFlagLabel`)
- `Scripts/verify-ui-tokens.sh` — regression greps for token misuse

*Last updated for custom palette + readability pass. Re-sync swatch hex if `StudioColors` changes.*
