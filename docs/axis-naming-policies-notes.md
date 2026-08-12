# Axis naming policies — design notes

*Captured from Import Review / Axis Tree discussions, August 2026. For rumination — not a commitment to build.*

---

## Context

VarFontStudio separates data cleanly: STAT stops, fvar instances, name table, compound styles, and plan each have their own surface. Import Review is **file-first** — names come from the font (STAT + instance peeling), with small fallbacks only when the font gives nothing useful.

These notes explore **optional, user-initiated cleanup** in the Axis Tree (and related surfaces), modeled on the Names panel’s policy-driven **Fill** actions — not automatic import behavior.

---

## What exists today

### Import / seeding (file-first)

Priority order when inferring stop names:

1. **Font data** — STAT stops (`value` + `name`), fvar instances (composed names + coords), observed fvar values
2. **`attributedName()`** — peels instance composed names against known stop tokens on other axes; residue becomes proposed stop name
3. **`AxisStopNamingDefaults`** — small per-axis **neutral** names for elidable defaults only:

   | Tag   | Default   |
   |-------|-----------|
   | wght  | Regular   |
   | wdth  | Normal    |
   | ital  | Roman     |
   | slnt  | Upright   |
   | opsz  | Standard  |

4. **Coordinate string** — e.g. `400`, `70` when nothing else applies

Custom axes (`insd`, `ousd`, …) have **no** dictionary entries — only instance peeling and coordinates.

VarFontStudio does **not** currently use Python `FontCore/core_font_style_dictionaries.py` at runtime (that layer serves Filename Tools, NameID scripts, etc.).

### Names panel pattern (template to mirror)

- **Restore** — file record wins when available
- **Fill** — policy suggestion, secondary; help text shows `Fill from font · {source} → {value}`
- Never silently overwrites without user action

### Plan / cleanup already in VarFontCore

- `AxisStopNamingDefaults` — apply axis neutrals, apply axis defaults, rename from coordinate value
- Plan issue resolver surfaces some of these as batch fixes

---

## Ideas under consideration

### 1. Magic wand on Axis Tree

Similar to Names panel **Fill**: per-stop (or per-axis / whole-font) action to apply a **named policy** when the suggestion differs from the current stop name.

Requirements:

- Opt-in only — no auto-apply on import
- Show **source** of every suggestion (“Weight compound policy”, “Registered wght hint”, …)
- Preview or tooltip before apply where batch actions are involved

### 2. Policy bundles (scoped, not one global “fix names”)

Personal style preferences in FontCore are **category-specific**. Example from `COMPOUND_NORMALIZATIONS`:

- **Weights:** lowercase the weight half of compounds — `ExtraBold` → `Extrabold`, `UltraLight` → `Ultralight`
- **Widths:** `UltraCondensed` stays `UltraCondensed` — no equivalent normalization in the compound map
- **Optical sizes:** separate vocabulary (`OPTICAL_BASES`), not subject to weight compound rules

Rationale (author preference): weights are the common element across all fonts; consistent compound casing aids scan-reading. Widths and optical sizes stay title-case / literal.

Proposed **separate policy bundles** (each toggleable):

| Bundle | Scope | Example |
|--------|-------|---------|
| Weight compound casing | `wght` stops | `ExtraBold` → `Extrabold` |
| Registered value hints | registered tags (`wght`, `wdth`, `opsz`, `ital`, `slnt`) | empty / numeric → `Bold`, `Standard`, … |
| Abbreviation expansion | configurable token map | `Bd` → `Bold`, `Cn` → `Condensed` |
| Axis neutrals | elidable defaults | already in `AxisStopNamingDefaults` |
| Rename from coordinate | any stop | mechanical `400` — not stylistic |
| Width / optical casing | explicit preserve or no-op | do not apply weight rules here |

**Do not** merge these into one undifferentiated “Fix names” — users need to know *why* a name changed.

### 3. Registered axis value hints (fallback layer)

Distinct from **axis neutrals** (default-at-default only):

- **Neutrals:** “what’s the boring name at this axis’s default coordinate?”
- **Value hints:** “this stop is 700 with no name — suggest `Bold`”

Scope recommendation: registered OpenType axes only for value hints; custom axes stay instance-peeling + coordinates only.

Use hints when data is weak:

- Empty or whitespace STAT name
- Numeric-only name matching the coordinate
- Plan-issue / cleanup flows
- Import Review conflict labels (alongside coordinate fallback — already partially done)

Never overwrite a non-empty, meaningful font-derived name automatically.

### 4. Settings: shipped preset + user overrides

- **Shipped preset** — author’s FontCore-aligned defaults (weight compounds, registered hints, neutrals including `opsz` → Standard)
- **User overrides** — editable compound map, per-axis value hints, abbreviation table, enable/disable each bundle
- Long-term option: generate or validate shipped preset from FontCore so Python CLI tools and Studio stay aligned on shared vocabulary — but Studio should own runtime Swift; Python dicts remain for batch/CLI

---

## Proposed architecture (when/if built)

### Core module: `AxisNamingPolicies` (parallel to `NamePolicies`)

```swift
struct AxisStopSuggestion {
    var value: String
    var source: String    // human-readable, for UI help
    var policyID: String  // for settings toggles
}
```

API sketch:

- `suggestion(stop:axisTag:axis:context:) -> AxisStopSuggestion?`
- `wouldChange(font:policyIDs:) -> [AxisStopChange]` for batch preview
- `apply(changes:to:)` with undo snapshot (EditorViewModel pattern)

Context carries: font, analysis snapshot, user policy settings, enabled bundle IDs.

### UI surfaces

1. **Stop row** — wand icon when suggestion ≠ current name; help shows source → value
2. **Axis header** — “Apply naming policies…” for all stops on one axis
3. **Batch sheet** — checkboxes per policy bundle + diff preview (similar to plan issue resolver)
4. **Settings** — policy preset editor (future)

Import Review: unchanged file-first behavior; policies are post-import cleanup only.

---

## Relationship to FontCore

| FontCore asset | Role in Studio (potential) |
|----------------|----------------------------|
| `COMPOUND_NORMALIZATIONS` (weight subset) | Default weight compound casing preset |
| `STYLE_WORDS` / weight terms | Registered `wght` value hints |
| `WIDTH_BASES` / `ALL_WIDTH_TERMS` | Hints + abbreviation expansion; **no** compound lowercasing |
| `OPTICAL_BASES` / `ALL_OPTICAL_TERMS` | Hints; preserve casing |
| `core_name_policies.py` | Name **table** IDs — separate concern; don’t conflate with STAT stop names |

Other FontCore policies (ID1/4/16/17, PostScript, filename slots) stay in the Names panel domain.

---

## Suggested rollout (phased, all optional)

| Phase | Scope | Notes |
|-------|-------|-------|
| **0** | Done | `opsz` neutral → `Standard`; empty STAT conflict names → coordinate; prefer fvar when STAT blank |
| **1** | Weight compound wand on `wght` stops only | Smallest slice; ports known FontCore preference |
| **2** | `AxisNamingPolicies.swift` + source strings | Registered value hints + neutrals wired as separate bundles |
| **3** | Axis header / batch sheet with preview | Checkbox per bundle |
| **4** | Settings preset + user overrides | JSON or table UI for compound map and hints |

---

## Principles to keep

1. **File first** — import and review trust the font; policies are cleanup tools
2. **Attributed suggestions** — every Fill shows where the value came from
3. **Scoped policies** — weight ≠ width ≠ optical; no one-size-fits-all normalization
4. **Opt-in** — wand / batch apply only; settings off by default for aggressive bundles if needed
5. **Separated data** — stop names, name table, abbreviations, and value hints remain distinct operations

---

## Open questions (for later)

- Should abbreviation expansion live on Axis Tree, Names panel, or both?
- Batch apply: per-font, per-project, or per-axis only?
- How much of the preset is editable vs. “reset to factory”?
- Generate Swift preset from FontCore at build time, or hand-maintained parity?
- Compound styles (Format 4): same weight compound rules on compound **names**, or stops only?
- Registered value hints: discrete steps only (100…900) or bands (opsz ranges)?
- Show policy suggestions inline in Import Review as optional chips, or keep review file-pure?

---

## Related files (reference)

- `VarFontStudio/Sources/VarFontCore/Plan/AxisStopNamingDefaults.swift`
- `VarFontStudio/Sources/VarFontCore/Import/FvarStopSeeder.swift` — `attributedName`, conflict handling
- `VarFontStudio/Apps/VarFontStudio/Views/NameTablePanel.swift` — Fill / Restore pattern
- `VarFontStudio/Sources/VarFontCore/.../NamePolicies.swift` (if present)
- `FontCore/core_font_style_dictionaries.py` — compounds, STYLE_WORDS, WIDTH_BASES, OPTICAL_BASES
- `FontCore/core_name_policies.py` — name **table** display policies (separate domain)

---

*Last updated: 2026-08-12*
