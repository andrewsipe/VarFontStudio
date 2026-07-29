# Instancer — Prototype Decision Log

Companion doc to `instancer-window-prototype-v2.html`. This captures the reasoning behind the
prototype's decisions, not just the decisions themselves, so intent survives the handoff to
implementation. Where something was explicitly deferred rather than decided, it's called out as
such in **Open Questions** at the end — treat that section as a to-do list, not settled design.

## 1. What this feature is

Instancer lets a user pull static font files out of a variable font's named instances, using
`fonttools.varLib.instancer`. It lives **inside VarFontStudio** as a feature of the app — it is
not a standalone tool.

**Project-only access (v1):** fonts enter Instancer only from an open Studio project. There is
no bring-your-own drag-drop or Open panel inside Instancer; import fonts in the main app first.

Two related usage paths informed the design:
- **Post-export path**: instancing a file that was just exported from Studio, where fvar/STAT
  naming is already correct.
- **Working-file path**: instancing the project's current `source_path` binary (which may predate
  export if the user opens Instancer before exporting).

The prototype's three scenario tabs ("Studio export," "Unprocessed file," "Empty") were design
fixtures — implementation uses one project-scoped window with a tab per project font.

## 2. Scope boundary: what Instancer is allowed to touch

**The app modifies the variable font. Instancer modifies the static.**

This is the governing principle for every "how much editing should we allow here" question:

- A change belongs in **Instancer** if it only ever affects the *one static file being written*
  (a PostScript prefix override, a one-off name override, a custom instance's own coordinates).
  There's no shared state to fork, because nothing else depends on that value.
- A change belongs in **Studio** if it's actually *policy* — naming order, axis registration,
  elision rules, STAT structure — because it needs to be true for every future export of the
  source, not just this one static cut. Instancer deliberately does not re-implement Studio's
  naming policy engine (`PostScriptNaming` / `NamePolicies` in the app). If it tried, the two
  could disagree with each other.

This is why "Fix in Studio" exists as an escape hatch rather than Instancer growing its own
naming-order UI, and why custom-instance edits are scoped to name + coordinates + bold/italic —
never to family-wide naming decisions.

## 3. Naming resolution — fvar first, STAT as silent fallback

Earlier drafts explored a STAT / fvar-hybrid / raw three-way toggle (modeled on the
`Variable_Instancer` CLI, which needs that because it can't trust fvar on an arbitrary file).
That was replaced once the feature was reframed as *living inside Studio*:

- **fvar is authoritative.** If usable, it's the resolved name, full stop — no toggle, because
  by the time a file reaches the post-export path, fvar already *is* the naming Studio/the user
  just finished getting right in Save Review.
- **STAT is a silent, per-row fallback.** If fvar is unusable, STAT fills in — no toggle to
  choose this, no explanation needed unless it's actually in use, at which point the row is
  flagged (amber, "⚠ fallback") with a **Fix in Studio** link, since incomplete fvar naming
  across many instances is a naming-order problem, not a one-file problem.
- **If neither fvar nor STAT can name it, that's not a worse name — it's a failure.** See §5.

## 4. Collision detection — three distinct shapes

A single "is this a duplicate" boolean turned out to hide a real distinction. Coordinate identity
(every registered axis, defaulted consistently) and name identity are checked independently,
producing three severities:

| Kind | Coordinates | Name | What it means | Color |
|---|---|---|---|---|
| **Collision** | different | same | Two different designs would overwrite each other's output file on disk | Magenta |
| **Identical** | same | different | The *same design* shipped under two different names — deceptive, since nothing collides on disk but the fonts are pixel-identical | Red |
| **Exact** | same | same | Plain duplication | Red |

All three **block Generate** when present in the current selection — not just visually flagged
and hoped-to-be-noticed. `selectDefault()` (the initial checkbox state) auto-deselects the second
occurrence of any name *or* coordinate match, keeping the first in sorted order.

Coordinate identity always compares **every** registered axis via its true default (`wdth`→100,
`ital`→0, etc.), never a bare `0` for a missing key — conflating "axis omitted" with "axis pinned
to zero" was a real bug caught mid-prototype (an added instance with a genuinely blank width field
was compared as `wdth 0`, sorting it ahead of even the Condensed instances). Every row — source or
custom — now always carries a fully-specified coordinate set for this reason.

## 5. The "will fail" tier — a pre-flight check, not a naming preference

`fontTools.varLib.instancer`'s `updateFontNames=True` derives static-font naming from the STAT
table's Axis Value entries at the pinned coordinate, and **raises `ValueError` if no Axis Value
exists there** — it doesn't silently degrade to a worse name.

So: fvar incomplete *and* no STAT value either isn't a worse version of the amber fallback case —
it's the literal condition that makes the real write fail. This gets its own tier:

- Same red/"severe" treatment as Identical/Exact (it's a hard blocker, not a style preference).
- Flag text: `✕ will fail`, with a **Fix in Studio** link (same reasoning as §3 — this is a
  naming-order gap, not something to patch per file).
- **Blocks Generate**, same mechanism as collisions.

Goal stated during design: *the target is zero failures at write time*, achieved by catching this
condition before Generate runs, not by handling the exception gracefully after a failed write.
Real per-file write failures that *aren't* pre-flight detectable (disk full, permissions, an
unanticipated fontTools error) are a separate, still-open concern — see Open Questions.

## 6. Overwrite protection

Collision detection (§4) only ever knows about the *current batch* — it has no visibility into
what's already on disk from a previous run. Generate's confirmation step addresses this
separately:

- **Defaults to a fresh, timestamped subfolder per batch** (`static-YYYYMMDD-HHMM`), so
  re-running Generate after a naming tweak can't silently clobber a prior run's output.
- Shows the **actual resolved path**, live, before confirming — not just the parent folder the
  user picked.
- A checkbox opts back into writing straight into a stable, user-chosen path (useful if
  something downstream — a build script, a design-system pipeline — expects a fixed location),
  with an explicit warning that doing so means filename collisions there will overwrite.

## 7. Custom instances (user-added, not in the source font)

A user can add an instance at any coordinate, even one with no corresponding named instance in
fvar (e.g., a 600 SemiBold when the file only defines 500/700). Decisions here:

- **The composer's fields carry real default values, not placeholders.** An earlier version used
  `placeholder="100"` for width; a user reasonably tried to "clear" it, which is impossible for a
  placeholder, and ended up with a literal `0` instead via the number input's own behavior —
  producing a corrupted coordinate that silently sorted wrong. Every axis field now starts with
  its actual default as a real, editable value. `wght` is the one field with no sane default for
  a *new* instance, so it's the one field that's actually required.
- **Bold/Italic are explicit checkboxes**, not guessed by string-matching the typed name (an
  earlier, fragile approach).
- **Adding at a coordinate that already exists is blocked**, not silently allowed. The assumption
  is that this is usually human error — the instance is probably already in the list and wasn't
  noticed — so the first click shows a warning naming the existing match, and only an explicit
  second confirmation ("Add anyway") proceeds.
- **Custom rows stay fully live-editable after creation** — name *and* every coordinate — unlike
  source rows, which only ever get a name override with a "Revert." The reasoning: a custom row
  has no canonical value in the source font to protect or revert *to*. "Override/revert" only
  makes sense for a value that came from somewhere; a custom row's current state simply *is* its
  state.
- Custom rows never contribute to the amber/red "fallback"/"will fail" states (they always carry
  a user-supplied name), but they **do** participate fully in collision detection against source
  rows and each other.

## 8. "Fix in Studio"

Two entry points, same underlying idea — escalate to Studio rather than let Instancer patch
around a policy-level problem:

- **Per-row**, on fallback/will-fail rows specifically (not shown for pure collisions or custom
  rows, since those are either already static-file-scoped fixes or need Studio for a different
  reason).
- **Global**, in the action bar, always available — carries a badge count of source-row problems
  and a tooltip noting how many custom instances would be proposed as new Axis Tree stops if the
  user follows through.
- The intended real mechanism for the per-row jump is the same anchor/focus pattern the app
  already uses elsewhere (`NamingOrderChainFooter.presentPostScriptPrefixEditing()` →
  `editor.focusInspectorProjectScope(...)`) — reuse it rather than inventing a second jump-to-fix
  pattern.

## 9. Visual language

Six states, six distinct hues, one concept each — no color is shared across unrelated meanings
anymore (an earlier version had "custom" and "edited" sharing one cyan, and a pastel purple for
collisions that had too little contrast against the dark/blue chrome to read clearly):

| State | Color | Hex |
|---|---|---|
| Selection / accent | Blue | `#0a84ff` |
| Needs attention (recoverable fallback) | Amber | `#f0a020` |
| Collision (name-only clash) | Magenta | `#e64ec2` |
| Severe (identical design, exact duplicate, will-fail) | Red | `#ff453a` |
| Custom (user-added instance) | Teal | `#2dd4bf` |
| Edited (value overridden from default) | Cyan | `#64d2ff` |

Every flagged row's background is computed as **one explicit layered value** — a gradient tint
(if any) stacked with the selection fill (if selected) — rather than competing whole-background
CSS rules. The earlier version let whichever rule was declared later in the stylesheet win
outright, which meant a selected + flagged row would silently lose its blue selection tint past
the gradient's fade point. A row's sub-note text color must always match its flag's color — this
was a real, separate bug (all four "problem" sub-notes shared one amber class regardless of
actual severity, making a purple-flagged collision row read amber underneath it).

Filter badges (`All | Clean | Custom | Collision | Needs Attention`) double as the legend — a
separate legend row was removed as redundant once the badges themselves carry icon + color +
count. Hovering a badge writes its explanation into a real pinned-bottom status bar (native
macOS convention) rather than a line of text that could wrap and grow the filter row's height.

## 10. Sorting

Rows sort by coordinate, following DesignAxisRecord order: **opsz → wdth → wght → slope/ital**,
with ital/slope as the final tiebreaker so italic instances interleave directly under their
upright counterpart (`wght 400 ital 0`, `wght 400 ital 1`, `wght 500 ital 0`, …) rather than
being grouped separately. This is the only ordering scheme that correctly places **custom**
instances (which have no fvar order to fall back to) — sorting by fvar table order was
considered and rejected specifically because it has nowhere to put a row that was never in fvar
to begin with. Missing axis values use the axis's true default for comparison, not `0` (see §4).

The prototype's leading `#` column was removed — it was the row's internal creation-order id,
not a real identifier, and had no purpose once rows started sorting by coordinate (it stopped
even *looking* sequential) and custom rows were appended with new ids regardless of where they
sort visually. It was never used in search or referenced anywhere else in the UI. If a persistent
identifier column is wanted later, the honest version is the row's real index in the font's fvar
instance array (meaningful and stable, mirroring what Save Review's own leading column shows),
not an arbitrary counter.

## 11. RIBBI

A real fold from bold/italic bits to one of four legal values (Regular / Italic / Bold / Bold
Italic) — an early version copied the STAT/fvar string directly, which produced invalid RIBBI
values like "Condensed" or "Medium Italic." This maps to the legacy nameID 1/2 pairing and
OS/2 `fsSelection`/`head.macStyle` bits a static font actually needs set correctly, not just a
display label.

## 12. Open questions — explicitly deferred, not yet designed

These are gaps in the *design*, not implementation details to sort out later — worth resolving
before or during the build rather than being discovered mid-way:

- **Partial write failures that aren't pre-flight detectable.** §5 covers the one failure mode
  that can be caught ahead of time. Real writes can still fail for other reasons (disk full,
  permissions, an fontTools error nobody anticipated). The CLI already continues past a single
  failure rather than aborting the batch — the Instancer UI needs a place for that to land
  (which rows failed, and why), not just a single success toast.
- **What happens to the Instancer window after "Fix in Studio"?** Does it stay open so the user
  can also Generate the rows that were fine? Close, expecting to be reopened once Studio's done?
  This also determines whether custom instances/overrides need to survive at all.
- **Does a custom instance's typed name survive promotion into Studio?** If "SemiBold" (typed by
  the user for a custom 600) becomes a real Axis Tree stop, Studio's actual naming policy engine
  gets to name it for real — elision, naming order, etc. Undecided whether the typed name travels
  as a seed/suggestion or gets fully recomputed.
- **Naming axes** (a non-fvar, per-file pinned axis — e.g. `ital` pinned for a file that's the
  Italic half of an upright/italic pair — contributing naming value without being a real fvar
  coordinate). Doesn't need special handling in name *resolution* (Studio already bakes the
  correct wording into fvar before export), but RIBBI folding and the coordinate columns
  currently assume italic/bold only ever exist as real fvar coordinates. A naming-axis-only
  italic file would incorrectly fold every instance to "Regular" as built today. Flagged in code
  comments at the relevant spot; not implemented.
- **Persistence.** Custom instances and name overrides are pure in-memory session state in the
  prototype. Whether they need to survive closing the window (or the app) is undecided.
  Currently: closing loses them.
- **The composer's axis fields are hardcoded to this font.** The `wdth`/`wght`/`ital` trio in the
  file was never generated dynamically from the font's actual registered axes — it's a fixed
  wdth/wght/ital trio matching this one sample font. A real build needs those fields generated
  per-font, or it'll silently break on a font with an `opsz` or other custom axis.
- **v1 scope is full-instancing only** (every axis pinned to a static point). Partial instancing
  (pinning some axes, leaving others still variable) was explicitly scoped out, not forgotten.
- **Batch/multi-file scope** — whether Instancer operates on one file at a time or across an
  entire multi-font project's exported set (relevant since Studio's "Export All" produces
  multiple files) was raised early and never resolved.
- **Accessibility.** Row checkboxes are `tabindex="-1"` in the HTML prototype purely to keep
  click-to-toggle simple to build — that was never a real design decision. Real keyboard
  navigation and VoiceOver support are expected in the Swift build and shouldn't be assumed away
  because the mockup skipped them.

## 13. Post-implementation design carryover (do not block v1)

Reminders for after Instancer ships — evaluate whether these visual choices should
spread to Review / other Studio windows for consistency. Not required for Instancer
to land; revisit deliberately once the feature is in place.

- **Row flag linear gradients.** Flagged rows use a left→transparent gradient tint
  layered with selection fill (see prototype `rowBackground()` / stacked
  `background` layers). If they read well in the real SwiftUI window, consider the
  same treatment for Save Review category rows and other dense status lists instead
  of flat fills alone.
- **Magenta for name-only collisions** (`#e64ec2`). Distinct from amber (recoverable)
  and red (severe). If it works here, audit other “same string, different meaning”
  or overwrite-risk affordances in the app for a place that color could clarify
  without colliding with existing purple/reflow chrome.
- **Instancer ↔ Review chrome parity (deferred).** Side-by-side, Instancer and Review
  have drifted on several small design decisions (action-bar stacking is already
  aligned; filter badges, metric cards, density, accents still differ). Walk these
  deliberately after Instancer is integrated and writing statics — not mid-build.

## 14. Prior art this drew on

- **`Variable_Instancer` (CLI)** — the naming-mode enum (`stat` / `fvar-hybrid` / `fvar-raw`) and
  the coordinate-and-name-aware dedup identity (`instance_output_identity`, keyed on the active
  naming mode) both come from here. Its test suite
  (`test_fvar_hybrid_keeps_misaligned_italic_names` vs `test_stat_mode_dedupes_same_stat_output`)
  is worth referencing directly — it proves the same two instances can be a duplicate under one
  naming mode and not another, which is exactly why coordinate identity has to be checked
  independently of name identity (§4).
- **VarFontStudio (main app)** — `PostScriptPrefixInference.infer()` (nameID 25 → nameID 6 stem →
  stripped nameID 6 → nameID 16 → nameID 1) is the fallback chain the PS Prefix field mirrors.
  `PostScriptNaming` / `NamePolicies` is the naming-policy engine Instancer deliberately does not
  duplicate (§2). `NamingOrderChainFooter.presentPostScriptPrefixEditing()` /
  `focusInspectorProjectScope()` is the anchor/jump pattern proposed for "Fix in Studio" (§8).
