import AppKit
import SwiftUI
import VarFontCore

// MARK: - Tokens (Axis Tree is the reference)

enum StudioTypography {
    static let sectionLabel = Font.system(size: 10, weight: .semibold)
    static let columnLabel = Font.system(size: 10, weight: .medium)
    static let body = Font.system(size: 13)
    static let bodyMedium = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 10)
    static let meta = Font.system(size: 10)
    static let gridSummaryValue = Font.system(size: 9, weight: .medium)
    static let gridSummaryValueMono = Font.system(size: 9, weight: .medium, design: .monospaced)
    static let tag = Font.system(size: 9, weight: .medium, design: .monospaced)
    static let monoValue = Font.system(size: 10, design: .monospaced)
    static let monoMeta = Font.system(size: 10, design: .monospaced)
    static let emphasis = Font.system(size: 13, weight: .semibold)
    /// Project scope title (project inspector header) — one step above `emphasis`.
    static let projectTitle = Font.system(size: 15, weight: .semibold)
    /// Canonical primary identity in list / tab rows (file basename, etc.).
    /// Weight is applied at the call site (semibold when selected, regular otherwise).
    static let rowName = Font.system(size: 12)
    /// Monospaced sibling of `rowName` for identifier cells in rows (e.g. name-table nameID).
    static let rowNameMono = Font.system(size: 12, design: .monospaced)
    /// Save Review summary metric value.
    static let statValue = Font.system(size: 16, weight: .medium)
    /// Diff section pill labels.
    static let pillLabel = Font.system(size: 9, weight: .semibold)
    /// Disclosure / expand chevrons in axis headers and diff sections.
    static let disclosureChevron = Font.system(size: 10, weight: .semibold)
    /// Compact tab / menu chevrons (8pt).
    static let iconGlyph = Font.system(size: 8, weight: .semibold)
    /// Format-3 link chain — lighter/smaller than adjacent caption text.
    static let linkGlyph = Font.system(size: 10, weight: .regular)
    /// Instancer / Save Review filter count badges (8.5pt bold).
    static let filterBadgeLabel = Font.system(size: 8.5, weight: .bold)
    /// Naming-chain micro chevron (optical; lighter than `iconGlyph`).
    static let linkChevronMicro = Font.system(size: 7, weight: .light)
    /// Empty-workspace drop hero glyph.
    static let dropHeroIcon = Font.system(size: 36)
}

/// 4pt spacing scale. Prefer `StudioSpacing` semantic aliases at call sites;
/// reach for `StudioSpace` steps only when no semantic token fits.
///
/// Half-steps (`x0_5`, `x1_5`, …) are first-class — they keep existing densities
/// value-preserving while staying on the 4pt lattice. Micro nudges (1pt / 3pt)
/// are intentional exceptions and stay as named literals on `StudioSpacing`.
enum StudioSpace {
    static let unit: CGFloat = 4

    static let x0_5: CGFloat = unit * 0.5  // 2
    static let x1: CGFloat = unit          // 4
    static let x1_5: CGFloat = unit * 1.5  // 6
    static let x2: CGFloat = unit * 2      // 8
    static let x2_5: CGFloat = unit * 2.5  // 10
    static let x3: CGFloat = unit * 3      // 12
    static let x3_5: CGFloat = unit * 3.5  // 14
    static let x4: CGFloat = unit * 4      // 16
    static let x5: CGFloat = unit * 5      // 20
    static let x6: CGFloat = unit * 6      // 24
    static let x7: CGFloat = unit * 7      // 28
    static let x8: CGFloat = unit * 8      // 32
    static let x9: CGFloat = unit * 9      // 36
    /// Large chrome context band (filter / project title / grid summary).
    static let x17: CGFloat = unit * 17    // 68
}

/// Semantic spacing aliases — always preferred over raw numbers or bare `StudioSpace`
/// steps at call sites. Values are expressed in `StudioSpace` so the 4pt lattice
/// stays the single source of truth.
enum StudioSpacing {
    /// Universal horizontal inset for panels, sheets, windows, and chrome bands.
    /// Symmetric left/right — trailing space includes macOS overlay scrollbar clearance.
    static let panelHorizontal: CGFloat = StudioSpace.x3
    static let panelVertical: CGFloat = StudioSpace.x1_5
    static let rowHorizontal: CGFloat = StudioSpace.x1_5
    static let rowVertical: CGFloat = StudioSpace.x0_5
    static let rowGap: CGFloat = StudioSpace.x1_5
    /// Tight inter-element gap inside chips / compact tool clusters.
    static let tightGap: CGFloat = StudioSpace.x1
    static let controlGap: CGFloat = StudioSpace.x2
    static let sectionGap: CGFloat = StudioSpace.x2_5
    /// Sheet / modal outer inset — same horizontal rail as panels.
    static let sheetOuterPadding: CGFloat = panelHorizontal
    /// Card / inner-box inset inside sheets and panels.
    static let cardPadding: CGFloat = panelHorizontal
    /// Root spacing in stacked editor sheets — slightly looser than `sectionGap` for dense multi-section layouts.
    static let sheetSectionSpacing: CGFloat = StudioSpace.x3_5
    /// Scroll list edge inset for section-header bleed (matches `panelHorizontal`).
    static let listInset: CGFloat = panelHorizontal
    /// Alias — scroll bodies use the same horizontal rail as headers and chrome.
    static let scrollContentHorizontal: CGFloat = panelHorizontal
    /// Alias — toolbar / file-bar chrome.
    static let editorChromeInset: CGFloat = panelHorizontal
    /// Alias — font preview / naming footer chrome.
    static let previewInset: CGFloat = panelHorizontal
    /// Alias — trailing inset inside padded cards (no extra scroll gutter).
    static let cardScrollTrailing: CGFloat = panelHorizontal
    /// Top inset when scroll content sits directly under `StudioPanelHeader` (no filter/toolbar row).
    static let panelContentTop: CGFloat = toolbarVertical
    /// Off-lattice micro (3pt) — optical gap under group headers; do not "snap" to 4.
    static let groupHeaderBelow: CGFloat = 3
    /// Off-lattice micro (3pt) — dense instance-row vertical padding.
    static let instanceRowVertical: CGFloat = 3
    /// Off-lattice micro (1pt) — hairline gap between instance rows.
    static let instanceRowGap: CGFloat = 1
    /// Off-lattice micro (1pt) — optical top nudge for warning glyphs beside multi-line text.
    static let warningGlyphTopNudge: CGFloat = 1
    /// Off-lattice (7pt) — Instancer / Save Review filter pill horizontal inset.
    static let pillHorizontalInset: CGFloat = 7
    /// Off-lattice (5pt) — compact tag / badge horizontal inset.
    static let tagHorizontalInset: CGFloat = 5
    static let toolbarVertical: CGFloat = StudioSpace.x1_5
}

enum StudioStroke {
    static let hairline: CGFloat = 0.5
    static let regular: CGFloat = 1
    /// Dashed focus / drop-gap affordance.
    static let emphasis: CGFloat = 1.2
    /// Highlight ring / drag-ghost outline.
    static let strong: CGFloat = 1.5
    /// Shared dash pattern for drag hover rings and drop gaps.
    static let dragDash: [CGFloat] = [4, 3]
}

enum StudioRadius {
    static let row: CGFloat = StudioSpace.x1_5
    static let chip: CGFloat = StudioSpace.x1
    /// Off-lattice (5pt) — control corner; leave alone.
    static let control: CGFloat = 5
    /// Off-lattice (3pt) — compact corner; leave alone.
    static let small: CGFloat = 3
}

/// Fixed control metrics so display ↔ edit transitions do not shift layout.
///
/// ## Stable Chrome style guide
/// - Pair every `StudioTextField` with a `StudioFieldLabel` at the **same** `rowHeight` when toggling display ↔ edit.
/// - Use `StudioFieldMetrics.*RowHeight` — never ad-hoc `.padding(.vertical)` on `TextField` alone.
/// - Return accepts and resigns focus (`.commit`). Use `.advance` only where Return should move to the next field (e.g. Add Stop sheet).
/// - Escape runs optional `onCancel`, then resigns focus.
/// - Forbidden outside this file: `.textFieldStyle(.roundedBorder)`, raw `TextField`
///   with hand-rolled borders, `.padding(.top, 1)` toolbar hacks.
/// - Field chrome: flat fill only (`StudioColors.fieldFill` → `fieldFillFocused`).
///   Never stroke an editable field. Display ↔ edit must share the same padding,
///   row height, and idle fill so text does not shift.
/// - Selection: default `StudioRowSelectionStyle.fillOnly` — no stroke on list rows.
/// - Chips: use `StudioTabChip` for project/file/save-review tabs (fixed padding, stable height).
/// - Typography: `bodyMedium` (12pt) for compact UI rows; `body` (13pt) for axis stop names and inspector prose.
/// - `StudioKeyValueRow` is for simple inspector key/value rows only — not axis coordinate tables.
///
/// ## Color (semantic marks)
/// Body text stays neutral (`.primary` / `.secondary` / `.tertiary`). Semantic hues
/// belong on marks — gutters, fills, dots, icons, badge backgrounds. Full rules:
/// **Color system (semantic marks)** in `StudioColors` below.
///
/// ## Shared chrome contract (one semantic → one primitive)
/// - Dismiss / remove: `StudioDismissButton` only. `.outline` (`xmark.circle`) for
///   close/dismiss, `.fill` (`xmark.circle.fill`) for in-row / in-field remove.
///   Never a naked `xmark`; never `minus.circle` to mean "remove".
/// - Overflow: `StudioOverflowMenu` only (`.toolbar` or `.chip` scale). It never
///   renders the system menu chevron.
/// - Selection radio: `StudioElidableRadio` (or a sibling taking `isOn`) for every
///   mutually-exclusive "picked" control. NOTE: an include/exclude control that
///   carries its own meaning (check vs minus) is a *different* control — do not
///   collapse it into a plain radio.
/// - Count: `StudioCountBadge` only. Dirty: `StudioDirtyDot` only (accent color).
///   Master: `StudioMasterStar` only — shares the dirty-dot alignment slot so
///   the pair centers together (never a naked `star.fill` next to the dot).
/// - Link glyph: `StudioLinkGlyph` — keep outside `Menu` labels. Use
///   `StudioFormat3LinkLabel` only for non-Menu Format-3 suffixes. Add affordance label: `StudioAddLabel`.
/// - Icon scale: `StudioChromeScale` — one glyph weight (`.semibold`), two hit targets
///   (`.toolbar` 12/24, `.chip` 12/16). Do not hand-size chrome icons.
/// - Rename / edit affordance: `StudioSymbols.edit` (`pencil.line`) only.
///   Never `pencil` or `pencil.circle` (too thin / reads as a prohibition mark).
///
/// ## Spacing scale (4pt lattice)
/// - Base unit: `StudioSpace.unit` (4pt). Steps: `x0_5`…`x8` (incl. half-steps).
/// - Call sites: use a `StudioSpacing.*` semantic alias. Do not write raw
///   `.padding(8)` / `spacing: 10` for structural spacing.
/// - If no semantic alias fits: use a `StudioSpace.xN` step (not a magic number).
/// - Allowed micro exceptions (do not invent new ones): 1pt / 3pt optical nudges
///   already named on `StudioSpacing` (`instanceRowGap`, `groupHeaderBelow`, …).
/// - Column / panel layout enums (`StopTableLayout`, `AxisBlockLayout`, `SaveReviewLayout`,
///   `FillStopPreviewLayout`, `NameTableLayout`, `InspectorAxisCoordLayout`, …) are
///   local track contracts — not part of the spacing lattice. Stop-style tables (Axis Tree,
///   conflict resolver, combination styles) share `StopTableLayout`.
///
/// ## Container horizontal inset
/// - `StudioSpacing.panelHorizontal` (12pt) — every panel, sheet, window, and chrome band.
///   Trailing inset includes macOS overlay scrollbar clearance; never add extra scroll gutter.
/// - Aliases (`editorChromeInset`, `previewInset`, `sheetOuterPadding`, …) all resolve to
///   `panelHorizontal` — prefer `panelHorizontal` at new call sites.
///
/// ## Cross-panel chrome bands (vertical alignment)
/// Three shared horizontal bands across Axis Tree / Instances / Inspector so
/// body content starts on one baseline. Band heights are 4pt-lattice multiples.
/// Body density below the bands stays local (airy axis tables vs tight instance rows).
/// - `StudioChromeBand.header` — panel title bar
/// - `StudioChromeBand.scope` — tabs / Axis Tree project·file glance
/// - `StudioChromeBand.context` — filter / project title / instance-grid summary
enum StudioFieldMetrics {
    static let horizontalPadding: CGFloat = 6
    static let toolbarIconPointSize: CGFloat = 12
    static let toolbarIconHitSize: CGFloat = 24
    /// Compact chrome icons inside chips / dense trailing clusters — same glyph
    /// point size as toolbar (single visual weight) with a tighter hit target.
    static let chipIconPointSize: CGFloat = 12
    static let chipIconHitSize: CGFloat = 16

    /// Single-line row heights matched to `StudioTypography` tiers.
    static let captionRowHeight: CGFloat = 20
    static let bodyMediumRowHeight: CGFloat = 22
    static let bodyRowHeight: CGFloat = 24
    static let monoValueRowHeight: CGFloat = 20

    /// Tab / file chip chrome — selected state must not change outer height.
    static let tabChipHorizontalPadding: CGFloat = 10
    static let tabChipVerticalPadding: CGFloat = 4
    static let tabChipRowHeight: CGFloat = 22

    /// Shared layout slot for adjacent chip status badges (master star, dirty dot).
    static let statusBadgeSlot: CGFloat = 8
    static let dirtyDotSize: CGFloat = 6
    static let masterStarPointSize: CGFloat = 8

    /// DisclosureGroup label rows (file naming, naming order footer).
    static let disclosureLabelRowHeight: CGFloat = 22

    /// Standard selectable list row (instances, inspector coords).
    static let listRowMinHeight: CGFloat = 22

    static func rowHeight(caption: Bool = false, bodyMedium: Bool = false, body: Bool = false, monoValue: Bool = false) -> CGFloat {
        if body { return bodyRowHeight }
        if bodyMedium { return bodyMediumRowHeight }
        if monoValue { return monoValueRowHeight }
        return captionRowHeight
    }
}

/// List / row selection chrome policy.
enum StudioRowSelectionStyle {
    /// Fill highlight only — default for instances, axis stops, inspector rows.
    case fillOnly
    /// Fill plus hairline stroke — avoid; reserved for exceptional keyboard-focus affordance.
    case fillAndStroke
}

enum StudioInteractionState {
    case idle
    case hovered
    case pressed
}

/// Single opacity contract for brand/semantic foreground hovers and presses.
enum StudioInteractionRule {
    static func resolve(base: Color, state: StudioInteractionState) -> Color {
        switch state {
        case .idle: return base
        case .hovered: return base.opacity(0.85)
        case .pressed: return base.opacity(0.7)
        }
    }
}

extension StudioInteractionState {
    static func from(isPressed: Bool, isHovered: Bool) -> StudioInteractionState {
        if isPressed { return .pressed }
        if isHovered { return .hovered }
        return .idle
    }
}

private enum StudioLinkForeground {
    static func resolve(style: StudioHoverLinkStyle, state: StudioInteractionState) -> Color {
        switch style {
        case .accent:
            switch state {
            case .idle: return .primary
            case .hovered, .pressed:
                return StudioInteractionRule.resolve(base: StudioColors.brand, state: state)
            }
        case .secondary:
            switch state {
            case .idle: return .secondary
            case .hovered, .pressed: return .primary
            }
        case .primary:
            switch state {
            case .idle: return .primary
            case .hovered, .pressed:
                return StudioInteractionRule.resolve(base: .primary, state: state)
            }
        }
    }
}

private enum StudioIconForeground {
    static func resolve(tint: Color?, state: StudioInteractionState) -> Color {
        if let tint {
            return StudioInteractionRule.resolve(base: tint, state: state)
        }
        switch state {
        case .idle: return .secondary
        case .hovered, .pressed: return .primary
        }
    }
}

// MARK: - Color system (semantic marks)
//
// Canonical guidance for semantic color usage. See also `COLOR_OUTLINE.md` (swatches).
// Phase 1 documents decisions; phase 2+ migrates call sites.
//
// ## Principle
// **Semantic hue = mark. Readable hue = text.**
//
// System semantic colors (orange, teal, indigo, …) are poor body-text choices on
// adaptive neutral surfaces — they fail WCAG on white/gray chrome and read as
// “brown” or “muddy” when darkened for contrast. Colorways stay; they move to
// fills, strokes, gutters, dots, icons, and compact badges — the roles HIG
// intends — while labels and values use `.primary` / `.secondary` / `.tertiary`
// (or `primaryMuted` where softened idle copy is needed).
//
// Rejected alternative: per-hue custom light-mode text variants (custom readable
// orange text and similar) — too finicky to maintain across every semantic and appearance.
//
// ## Token tiers
// 1. **Brand** (`brand`, `selectionFill`, `computedHighlight`) — interaction,
//    selection, app tint, computed totals. Never axis/file semantics.
// 2. **Semantic marks** (`*Foreground` paired with `*Fill` / `*Stroke`) — hue
//    carriers for marks only. Despite the `Foreground` suffix, these are **not**
//    for body text after migration. Prefer the `*Fill` / `*Stroke` sibling at
//    call sites; `*Foreground` remains the canonical hue for icons, gutters, dots,
//    and badge strokes until a `StudioSemanticMark` helper exists.
// 3. **Neutrals** (`surface*`, `fieldFill`, `hoverFill`, `tag*`, `primaryMuted`)
//    — adaptive chrome via `StudioPrimaryWash` and system label colors.
// 4. **Canvas** (`canvas*`) — font preview panel only. Fixed paper white + black
//    ink. Never Review, Instancer, or inspector tables.
//
// ## Approved mark surfaces (use semantic hue here)
// - Leading gutter bar — `StudioStreamlinedDiffRow` (Save Review)
// - Leading edge bar — registration axis stops (3pt `registrationForeground`)
// - Row leading stripe — Instancer flagged rows (`StudioSemanticLeadingStripe`)
// - Fill / stroke on containers — `warningFill`, `customFill`, `*Stroke`, drop zones
// - Status icons — `StudioWarningBadge`, collision ◆, checkbox success/warning
// - Chain-rail dots — inspector axis coord rows (`registrationForeground` dot)
// - Filter badge tint — `InstancerFilterBadgeButton` background wash
// - Compact category pills — diff section counts, STAT `F1`/`F2`/`F3` badges
//   (hue on fill/stroke; label text neutral — see Pills below)
//
// ## Text that must stay neutral (never semantic `*Foreground` on `Text`)
// - Table cell values — axis digits, Save Review after-values, instancer coords
// - Row / field labels — instance names, stop names, banner message body
// - Inline prose — sheet copy, tooltips, empty states
// - Flag strings — “custom”, “fallback”, “collision” (mark beside, neutral inside)
//
// ## Pills and compact badges
// Hue lives in `*Background` and `*Stroke`; the label uses `.primary` or
// `.secondary`. Small monospaced chips (axis tag, diff category, STAT format)
// are marks, not paragraphs — they follow the same rule.
//
// ## Axis value mark (phase 2 — interim)
// Orange dot beside value digits; revisit after full migration for a better column mark.
//
// ## Warnings and errors
// Banner / sheet **message body** → `.primary`. **Icon or left accent** →
// `warningForeground` / `errorForeground`. Row-level flags: tinted capsule or
// leading symbol in semantic hue; label text neutral.
//
// ## Interaction and links
// - Links and pressed controls → `brand` via `Studio*ButtonStyle` resolvers only.
// - Caret / text selection → `brandNSColor` (`StudioTextInputAccentModifier`).
// - Do not use `Color.accentColor` or `.preferredColorScheme` in Views.
//
// ## What we are not changing
// - Adaptive neutral panel chrome (`.bar`, `surfaceMuted`, `StudioPrimaryWash`).
// - Font preview fixed white/black canvas.
// - Per-hue WCAG text variants (Option B).
//
// ## Brand hue (decided)
// `brand` stays `Color.blue` for interaction, selection, and app tint only.
//
// ## Custom palette (decided)
// System indigo reads too close to brand blue; system brown is poor on neutral chrome.
// Fixed RGB tokens (like `statFormat*`) for registration, code, and metric digits.
// See **Custom palette** in `COLOR_OUTLINE.md`.
//
// ## Migration phases
// - **Phase 1** (this document) — lock rules; no visual changes.
// - **Phase 2** — high-traffic tables: Review values, axis value column, Instancer
//   flags; `axisValue` / `diffRenamed` → `Color.orange` as mark hues only. **Done**.
// - **Phase 3** — pills, naming footer, remaining sheets; lint checks. **Done**.
// - **Phase 4** — audit polish: no unconditional value dots; semantic fill scale;
//   link idle neutral; Instancer leading stripe; token disambiguation. **Done**.
//
// ## Phase 4 punch list (post-audit)
// 1. Axis value dot — conditional only (`showMark` default false); column TBD.
// 2. Two opacity scales — chrome 0.03–0.16 vs semantic fills 0.20–0.30.
// 3. Links — `.accent` idle `.primary`, brand on hover/press.
// 4. Instancer — `StudioSemanticLeadingStripe`, not gradient fade.
// 5. Tokens — `diffProtected` slate; `diffRenamed` yellow; STAT slate/mauve set.
//
// ## Token audit rule
// Same hue = same meaning everywhere, or split the token. Category labels must not
// borrow status hues (success green, edited cyan, brand blue, warning orange).
//
private enum StudioPrimaryWash {
    static func make(name: String, light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.PrimaryWash.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.labelColor.withAlphaComponent(isDark ? dark : light)
        }))
    }
}

/// Semantic color tokens. See **Color system (semantic marks)** above for usage rules.
///
/// Naming note: `*Foreground` tokens name the canonical **hue** for a semantic.
/// After migration they are for marks (icons, gutters, dots, badge strokes) — not
/// for `Text` body copy. Pair with `*Fill` / `*Stroke` at call sites.
enum StudioColors {
    // MARK: Brand & interaction

    /// Tier 1 — fixed brand for interactive/selected chrome (not system accent).
    static let brand = Color.blue
    /// AppKit bridge for caret/selection styling in `StudioTextField`.
    static var brandNSColor: NSColor { NSColor(brand) }

    // MARK: Neutral tags

    /// Instance axis tag pills — neutral text on neutral wash.
    static let tagForeground = Color.secondary
    static let tagBackground = Color.secondary.opacity(0.12)

    // MARK: Semantic marks — axis & instancer

    /// **Mark hue** — axis value column (dot / column accent). Not for value digits.
    static let axisValue = Color.orange

    // MARK: Selection & hover (brand + neutral washes)

    static let selectionFill = brand.opacity(0.10)
    static let selectionStroke = brand.opacity(0.20)
    /// Neutral (non-accent) selection / hover-over-selection fills — not for borders.
    static let selectionNeutralFill = StudioPrimaryWash.make(name: "selectionNeutralFill", light: 0.11, dark: 0.08)
    static let selectionNeutralFillStrong = StudioPrimaryWash.make(name: "selectionNeutralFillStrong", light: 0.15, dark: 0.12)
    static let hoverFill = StudioPrimaryWash.make(name: "hoverFill", light: 0.08, dark: 0.05)

    // MARK: Canvas (font preview only — see color system guidance)

    /// Fixed paper-white glyph preview — font preview panel only (not Review/Instancer tables).
    static let canvasBackground = Color.white
    /// Ink on the font preview canvas — always black regardless of system appearance.
    static let canvasForeground = Color.black
    static let canvasSecondary = Color.black.opacity(0.55)
    static let canvasTertiary = Color.black.opacity(0.38)
    static let canvasQuaternary = Color.black.opacity(0.22)
    static let canvasDivider = Color.black.opacity(0.10)
    /// Status strip on the font preview panel.
    static let canvasPhaseHeader = Color(white: 0.96)
    static let canvasHoverFill = brand.opacity(0.08)

    // MARK: Semantic marks — status (warning / success / error)
    //
    // Opacity scale for status fills (0.20–0.30) — stronger than neutral chrome washes.

    static let warningFill = Color.orange.opacity(0.22)
    static let warningFillHover = Color.orange.opacity(0.30)
    /// Mark hue — warning icons, gutter accents, flag symbols. Not banner body text.
    static let warningForeground = Color.orange
    static let warningStroke = Color.orange.opacity(0.45)
    static let successStroke = Color.green.opacity(0.45)
    /// Mark hue — success icons and include-checkbox checkmark when on.
    static let successForeground = Color.green
    /// Mark hue — error icons, severe collision flags, destructive emphasis.
    static let errorForeground = Color.red
    static let errorStroke = Color.red.opacity(0.5)

    // MARK: Semantic marks — instancer row state

    /// Mark hue — name-only collision (distinct from amber fallback / red severe).
    static let collisionForeground = Color.pink
    static let collisionFill = collisionForeground.opacity(0.24)
    static let collisionStroke = collisionForeground.opacity(0.45)
    /// Mark hue — user-added custom instance row stripe / flag symbol.
    static let customForeground = Color.teal
    static let customFill = customForeground.opacity(0.24)
    /// Mark hue — edited-from-default name override (reserved; row stripe if needed).
    static let editedForeground = Color.cyan
    static let editedFill = editedForeground.opacity(0.24)

    // MARK: Semantic marks — Save Review diff

    static let diffRemoved = Color.red
    static let diffAdded = Color.green
    static let diffReflowed = Color.purple
    /// Protected/locked — slate, not brand (brand = interaction/selection).
    static let diffProtected = Color.gray
    /// Renamed/changed — informational yellow, not warning orange.
    static let diffRenamed = Color.yellow

    // MARK: Neutral surfaces & fields

    /// Neutral panel surfaces — light-mode opacities bumped for clearer hierarchy on pale chrome.
    static let surfaceSubtle = StudioPrimaryWash.make(name: "surfaceSubtle", light: 0.055, dark: 0.03)
    static let surfaceMuted = StudioPrimaryWash.make(name: "surfaceMuted", light: 0.07, dark: 0.04)
    static let surfaceLight = StudioPrimaryWash.make(name: "surfaceLight", light: 0.08, dark: 0.05)
    static let surfaceInset = StudioPrimaryWash.make(name: "surfaceInset", light: 0.09, dark: 0.06)
    /// Flat editable field fills — idle always present; focused is a stronger wash (no strokes).
    static let fieldFill = StudioPrimaryWash.make(name: "fieldFill", light: 0.09, dark: 0.06)
    static let fieldFillFocused = StudioPrimaryWash.make(name: "fieldFillFocused", light: 0.16, dark: 0.12)
    static let surfaceStroke = StudioPrimaryWash.make(name: "surfaceStroke", light: 0.11, dark: 0.08)
    static let surfaceStrokeStrong = StudioPrimaryWash.make(name: "surfaceStrokeStrong", light: 0.13, dark: 0.10)
    /// Disabled-selected chip stroke (stronger than `surfaceStroke`).
    static let surfaceStrokeEmphasized = StudioPrimaryWash.make(name: "surfaceStrokeEmphasized", light: 0.22, dark: 0.18)
    /// Softened primary for idle-but-enabled label text.
    static let primaryMuted = StudioPrimaryWash.make(name: "primaryMuted", light: 0.88, dark: 0.85)
    /// Flat secondary action fill (Cancel, Generate All…, Add Instance…).
    static let buttonSecondaryFill = StudioPrimaryWash.make(name: "buttonSecondaryFill", light: 0.15, dark: 0.12)
    static let buttonSecondaryFillDisabled = StudioPrimaryWash.make(name: "buttonSecondaryFillDisabled", light: 0.07, dark: 0.05)
    /// Readable placeholder in fields and search — stronger than `.tertiary`, softer than `.primary`.
    static let textPlaceholder = StudioPrimaryWash.make(name: "textPlaceholder", light: 0.42, dark: 0.48)
    /// Scannable metric digits — panel header counts, `StudioCountBadge`, summary cards.
    /// Steel blue: related to brand but darker; not used for buttons or selection chrome.
    static let metricForeground = Color(red: 0.082, green: 0.396, blue: 0.722)
    /// Legacy alias — prefer `metricForeground` at new call sites.
    static let computedHighlight = metricForeground
    /// Brand mark — elided STAT fallback segment in naming chains (neutral text + brand dot).
    static let elidedFallbackForeground = brand

    // MARK: Custom palette — registration & classification (fixed RGB)

    /// Mark hue — design-record / PS / clarifier. Plum violet — clearly not brand blue.
    static let registrationForeground = Color(red: 0.557, green: 0.290, blue: 0.624)
    static let registrationBackground = registrationForeground.opacity(0.22)
    static let registrationStroke = registrationForeground.opacity(0.40)
    /// Legacy clarifier alias — same plum as registration.
    static let clarifierForeground = registrationForeground
    static let clarifierBackground = registrationBackground
    static let clarifierStroke = registrationStroke
    /// Mark hue — OpenType classification code chip. Cool graphite — not brown.
    static let codeForeground = Color(red: 0.361, green: 0.396, blue: 0.439)
    static let codeBackground = codeForeground.opacity(0.22)
    static let codeStroke = codeForeground.opacity(0.45)

    // MARK: Semantic marks — STAT format badges
    //
    // Category distinguishers only — not success (green), edited (cyan), or brand.

    /// Mark hues for `StudioStatFormatBadge` fill/stroke (label text neutral).
    static let statFormat1 = Color(red: 0.50, green: 0.58, blue: 0.68)
    static let statFormat2 = Color(red: 0.58, green: 0.50, blue: 0.72)
    static let statFormat3 = Color(red: 0.48, green: 0.54, blue: 0.62)

    // MARK: Drag & drop zones

    /// Drop zone half fills — 5% tint over the target region during drag.
    static let dropZoneFillOpacity: CGFloat = 0.05
    static let dropZoneAddFill = registrationForeground.opacity(dropZoneFillOpacity)
    static let dropZoneNewFill = Color.green.opacity(dropZoneFillOpacity)
    /// Drop zone borders when the cursor is over a half.
    static let dropAddExisting = registrationForeground
    static let dropNewProject = Color.green
}

enum StudioFormatting {
    static func axisValue(_ value: Double) -> String {
        AxisCoordinateFormat.format(value)
    }

    /// Builds `key=value` tokens in naming order for compact list display.
    static func coordPairs(
        coords: [String: Double],
        namingOrder: [String]
    ) -> [String] {
        let extra = coords.keys.filter { !namingOrder.contains($0) }.sorted()
        let tags = namingOrder.filter { coords[$0] != nil } + extra
        return tags.compactMap { tag -> String? in
            guard let value = coords[tag] else { return nil }
            return "\(tag)=\(axisValue(value))"
        }
    }

    /// Truncates at pair boundaries so list rows never cut mid-value (`wght=3…`).
    static func truncatingCoordCaption(pairs: [String], maxLength: Int = 28) -> String {
        var result = ""
        for pair in pairs {
            let candidate = result.isEmpty ? pair : "\(result) \(pair)"
            if candidate.count > maxLength, !result.isEmpty { break }
            if candidate.count > maxLength { return pair }
            result = candidate
        }
        return result
    }
}

enum NamingVisualRole {
    case instance
    case registration
}

struct StudioTagPill: View {
    let text: String
    var compact: Bool = false
    var role: NamingVisualRole = .instance

    private static let horizontalPadding: CGFloat = 5
    private static let monospacedCharWidth: CGFloat = 5.5

    static func layoutWidth(for text: String) -> CGFloat {
        CGFloat(text.count) * monospacedCharWidth + horizontalPadding * 2
    }

    private var foreground: Color {
        switch role {
        case .instance: StudioColors.tagForeground
        case .registration: .primary
        }
    }

    private var background: Color {
        switch role {
        case .instance: StudioColors.tagBackground
        case .registration: StudioColors.registrationBackground
        }
    }

    var body: some View {
        Text(text)
            .font(StudioTypography.tag)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 2)
            .foregroundStyle(foreground)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: compact ? StudioRadius.small : StudioRadius.small)
            )
    }
}

struct StudioStatFormatBadge: View {
    let format: Int
    var action: (() -> Void)?

  private var markColor: Color {
        switch format {
        case 2: StudioColors.statFormat2
        case 3: StudioColors.statFormat3
        default: StudioColors.statFormat1
        }
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    badgeLabel
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: 3))
                .help("Change STAT format")
            } else {
                badgeLabel
            }
        }
    }

    private var badgeLabel: some View {
        Text("F\(format)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(.primary)
            .background(markColor.opacity(format == 2 ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(markColor.opacity(0.35), lineWidth: 0.5)
            }
    }
}

struct StudioClarifierPill: View {
    let label: String
    var showCategory: String? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let showCategory {
                Text(showCategory)
                    .font(StudioTypography.meta)
            }
            Text(label)
                .font(compact ? StudioTypography.caption : StudioTypography.bodyMedium)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 3 : 4)
        .foregroundStyle(.primary)
        .background(StudioColors.clarifierBackground, in: Capsule())
        .overlay {
            Capsule().strokeBorder(StudioColors.clarifierStroke, lineWidth: 0.5)
        }
    }
}

// MARK: - Pills & badges
//
// Compact badges are marks: hue on `background` / `border`; label uses `.primary`.

/// Capsule pill with semantic diff colors — Save Review section counts.
enum StudioDiffPillStyle {
    case removed, added, changed, reflowed, unchanged, protected

    var foreground: Color {
        switch self {
        case .removed: StudioColors.diffRemoved
        case .added: StudioColors.diffAdded
        case .changed: StudioColors.diffRenamed
        case .reflowed: StudioColors.diffReflowed
        case .unchanged: .secondary
        case .protected: StudioColors.diffProtected
        }
    }

    var background: Color { foreground.opacity(0.20) }
    var border: Color { foreground.opacity(0.35) }
}

struct StudioSemanticPill: View {
    let text: String
    let style: StudioDiffPillStyle

    var body: some View {
        Text(text)
            .font(StudioTypography.pillLabel)
            .foregroundStyle(style == .unchanged ? .secondary : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style.background, in: Capsule())
            .overlay(Capsule().strokeBorder(style.border, lineWidth: 0.5))
    }
}

struct StudioDiffPillItem: Identifiable {
    let id = UUID()
    let text: String
    let style: StudioDiffPillStyle

    init(_ text: String, style: StudioDiffPillStyle) {
        self.text = text
        self.style = style
    }
}

// MARK: - Semantic mark views

/// Filled circle for **conditional** semantic marks — only when state varies row-to-row.
struct StudioSemanticDot: View {
    var color: Color
    var size: CGFloat = 4

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

/// Axis value column — neutral monospaced digits. Pass `showMark: true` only when
/// the dot encodes conditional state (not for every row in the value column).
struct StudioAxisValueLabel: View {
    let text: String
    var font: Font = StudioTypography.monoValue
    var markColor: Color = StudioColors.axisValue
    var muted: Bool = false
    var showMark: Bool = false
    var minHeight: CGFloat? = nil

    var body: some View {
        HStack(spacing: StudioSpace.x1) {
            if showMark {
                StudioSemanticDot(color: markColor)
            }
            Text(text)
                .font(font)
                .foregroundStyle(muted ? Color.secondary.opacity(0.55) : Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .trailing)
    }
}

/// Full-height leading-edge stripe for list-row semantic state (Instancer flags).
struct StudioSemanticLeadingStripe: View {
    let color: Color
    var width: CGFloat = 3

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width)
    }
}

/// Instancer / table flag — tinted symbol + neutral label text.
struct StudioFlagLabel: View {
    let symbol: String
    let text: String
    let tint: Color
    var font: Font = StudioTypography.meta

    var body: some View {
        HStack(spacing: 3) {
            Text(symbol)
                .foregroundStyle(tint)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .font(font)
    }
}

/// Numeric count capsule for aligned metric slots (axis header stop counts).
///
/// **Fixed width:** When `fixedWidth` is set, digits scale down before truncating so trailing
/// header clusters stay aligned. The axis-tree slot is 32pt (fits 1–3 digit counts at `meta`).
/// Use 36pt+ for 4-digit totals. Trailing cluster today: optional Resolve button, count badge,
/// instance-axis toggle — not the legacy "Pinned" label (replaced by the switch).
struct StudioCountBadge: View {
    let text: String
    var highlighted: Bool = true
    var fixedWidth: CGFloat? = nil
    var help: String = ""

    var body: some View {
        Text(text)
            .font(StudioTypography.meta.weight(.medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(highlighted ? AnyShapeStyle(StudioColors.metricForeground) : AnyShapeStyle(.secondary))
            .frame(width: fixedWidth)
            // Free (non-aligned) badges need breathing room; fixed-width column
            // badges (axis headers) keep their exact alignment slot.
            .padding(.horizontal, fixedWidth == nil ? 6 : 0)
            .padding(.vertical, 2)
            .background(
                highlighted ? StudioColors.selectionFill : StudioColors.surfaceSubtle,
                in: Capsule()
            )
            .help(help)
    }
}

// MARK: - Disclosure & metrics

/// Icon-swap chevron for custom expand toggles — preserves Save Review / axis header behavior (not `DisclosureGroup` rotation).
struct StudioDisclosureChevron: View {
    var isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(StudioTypography.disclosureChevron)
            .foregroundStyle(.tertiary)
            .frame(width: 12)
    }
}

/// Nested-section chevron (footer rows, combination styles) — larger hit target than top-level disclosure.
struct StudioNestedDisclosureChevron: View {
    var isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.down.square" : "chevron.right.square")
            .font(.system(size: StudioFieldMetrics.toolbarIconPointSize))
            .foregroundStyle(.tertiary)
            .frame(width: StudioFieldMetrics.toolbarIconHitSize, height: StudioFieldMetrics.toolbarIconHitSize)
    }
}

@available(*, deprecated, renamed: "StudioNestedDisclosureChevron")
typealias StudioSquareDisclosureChevron = StudioNestedDisclosureChevron

/// Mutually exclusive elision control for axis stops (one elidable stop per axis).
/// Use `StudioElidableSwitch` only where each row can elide independently (e.g. combination styles).
struct StudioElidableRadio: View {
    let isOn: Bool
    var helpText: String? = nil
    let action: () -> Void

    private var resolvedHelp: String {
        helpText
            ?? (isOn
                ? "Clear elidable stop — only one stop per axis can be elided"
                : "Mark as the elidable stop for this axis (clears any other)")
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: StudioStroke.regular)
                .frame(width: 14, height: 14)
            if isOn {
                Circle()
                    .fill(StudioColors.brand)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .studioHoverFill(shape: .circle)
        .highPriorityGesture(
            TapGesture().onEnded { action() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elidable")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityAction { action() }
        .help(resolvedHelp)
    }
}

/// Independent on/off elision for rows that are not mutually exclusive (combination styles).
struct StudioElidableSwitch: View {
    @Binding var isOn: Bool
    var helpText: String = "Omit this name from the composed style when it is the default choice"

    var body: some View {
        Toggle("Elidable", isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .help(helpText)
    }

    init(isOn: Binding<Bool>, helpText: String = "Omit this name from the composed style when it is the default choice") {
        _isOn = isOn
        self.helpText = helpText
    }

    init(isOn: Bool, helpText: String = "Omit this name from the composed style when it is the default choice", action: @escaping () -> Void) {
        _isOn = Binding(get: { isOn }, set: { _ in action() })
        self.helpText = helpText
    }
}

/// Save Review / dashboard summary metric tile.
///
/// **Sizing contract** (`minWidth` defaults to 72):
/// - **Values:** `statValue` (16pt) with `monospacedDigit()` — comfortable through 4 digits at 72pt;
///   5+ digits may need a wider `minWidth` (84–96) rather than shrinking the value line.
/// - **Labels:** `gridSummaryValue` (9pt uppercase, +0.4 tracking), single line — fits labels up to
///   ~14 characters at 72pt (`"New name IDs"`, `"STAT values"`). Longer copy should use a shorter
///   label, raise `minWidth`, or accept `minimumScaleFactor` shrink — labels do not wrap.
struct StudioMetricCard: View {
    let value: String
    let label: String
    var minWidth: CGFloat = 72
    var accentValue: Bool = false
    /// When true, the visible card (background + border included) stretches to
    /// fill its column instead of hugging its content and floating in extra
    /// invisible frame space — use for equal-width metric rows (Save Review cards).
    var fillsWidth: Bool = false
    /// Save Review summary row — prototype `.card .n` scale (20pt bold value).
    var prominent: Bool = false

    var body: some View {
        VStack(spacing: prominent ? 3 : 2) {
            Text(value)
                .font(prominent ? .system(size: 20, weight: .bold) : StudioTypography.statValue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(accentValue ? StudioColors.computedHighlight : .primary)
            Text(label)
                .font(prominent ? .system(size: 10, weight: .medium) : StudioTypography.gridSummaryValue)
                .textCase(.uppercase)
                .tracking(prominent ? 0.35 : 0.4)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(minWidth: minWidth, maxWidth: fillsWidth ? .infinity : nil)
        .padding(.horizontal, prominent ? 6 : 12)
        .padding(.vertical, prominent ? 10 : 8)
        .background(StudioColors.surfaceLight, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: 0.5)
        )
    }
}

// MARK: - Diff rows

enum StudioDiffRowSide {
    case before
    case after
}

/// TTX side-by-side diff row — annotation bar, key, value, optional role label.
struct StudioDiffRow: View {
    let change: CommitDiffChangeKind
    let key: String
    let value: String?
    var roleLabel: String? = nil
    let side: StudioDiffRowSide
    var reflow: Bool = false
    var protected: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Self.annotationColor(change: change, side: side, reflow: reflow, protected: protected))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let value, !value.isEmpty {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(Self.valueColor(change: change, side: side, reflow: reflow, protected: protected))
                            .lineLimit(1)
                        if let roleLabel, !roleLabel.isEmpty {
                            Text(roleLabel)
                                .font(StudioTypography.meta)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("—")
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    static func annotationColor(
        change: CommitDiffChangeKind,
        side: StudioDiffRowSide,
        reflow: Bool = false,
        protected: Bool = false
    ) -> Color {
        if protected { return StudioColors.diffProtected }
        if reflow { return StudioColors.diffReflowed }
        switch change {
        case .added:
            return side == .after ? StudioColors.diffAdded : .clear
        case .removed:
            return side == .before ? StudioColors.diffRemoved : .clear
        case .changed:
            return StudioColors.diffRenamed
        case .unchanged:
            return .clear
        }
    }

    static func valueColor(
        change: CommitDiffChangeKind,
        side: StudioDiffRowSide,
        reflow: Bool = false,
        protected: Bool = false
    ) -> Color {
        .primary
    }
}

// MARK: - Save Review (streamlined diff)

/// Spacing tokens for the Save Review window — on the 4pt lattice.
/// (`gutterWidth` stays a 3pt micro for the change rail.)
enum SaveReviewLayout {
    static let horizontalPadding: CGFloat = StudioSpacing.panelHorizontal
    static let summaryCardGap: CGFloat = StudioSpace.x2 // 8
    static let chromeSectionGap: CGFloat = StudioSpace.x3 // 12
    static let filterBadgeGap: CGFloat = StudioSpace.x1_5 // 6
    /// nameID slot column (right-aligned digits) — sits between field label and value.
    static let nameIDColumnWidth: CGFloat = 36
    /// Gap between field-label column and nameID.
    static let nameIDColumnLeadingGap: CGFloat = StudioSpace.x2 // 8
    /// Gap between nameID and value column.
    static let nameIDColumnTrailingGap: CGFloat = StudioSpace.x2 // 8
    /// Field label column — human row identifier (+ optional detail line).
    static let fieldColumnWidth: CGFloat = 200
    static let rowVerticalPadding: CGFloat = StudioSpace.x2 // 8
    /// Search row + tab headline band (shared so those toolbars stay the same height).
    static let toolRowMinHeight: CGFloat = StudioSpace.x9 // 36
    static let toolRowVerticalPadding: CGFloat = StudioSpace.x1_5 // 6
    static let gutterWidth: CGFloat = 3
    static let gutterLeadingPadding: CGFloat = StudioSpacing.panelHorizontal
    static let gutterTrailingPadding: CGFloat = StudioSpacing.panelHorizontal

    /// Sticky section band in the diff table — matches neutral chrome elsewhere.
    static let phaseHeaderBackground = StudioColors.surfaceMuted
}

/// Spacing tokens for the Instancer window — shares Review density where chrome matches.
enum InstancerLayout {
    static let horizontalPadding: CGFloat = SaveReviewLayout.horizontalPadding
    static let chromeSectionGap: CGFloat = SaveReviewLayout.chromeSectionGap
    static let filterBadgeGap: CGFloat = SaveReviewLayout.filterBadgeGap
    static let toolRowMinHeight: CGFloat = SaveReviewLayout.toolRowMinHeight
    static let toolRowVerticalPadding: CGFloat = SaveReviewLayout.toolRowVerticalPadding
    static let statusBarHeight: CGFloat = StudioSpace.x7 // 28
    static let searchFieldWidth: CGFloat = 180

    /// Checkbox / progress column.
    static let selectColumnWidth: CGFloat = StudioIncludeCheckbox.hitSize
    /// Same track as Axis Tree Value — fits typical axis coords (e.g. 1000, 112.5).
    static let axisColumnWidth: CGFloat = StopTableLayout.valueColumnWidth
    /// Fits “Bold Italic” in caption.
    static let styleColumnWidth: CGFloat = 80
    /// Uniform gap between fixed columns (select, name, axes…).
    static let columnGap: CGFloat = StudioSpace.x2_5 // 10
    /// Extra lead into left-aligned text columns after numeric axes (matches Axis Tree `nameGap`).
    static let textColumnLeadingGap: CGFloat = StopTableLayout.nameGap
    static let flagColumnWidth: CGFloat = 140
    static let nameColumnMinWidth: CGFloat = 160
    static let outputColumnMinWidth: CGFloat = 200

    /// Shared Name / Output widths — both flex with the window; axes + Style stay fixed.
    struct ColumnWidths: Equatable {
        var name: CGFloat
        var output: CGFloat
    }

    static func columnWidths(totalWidth: CGFloat, axisCount: Int) -> ColumnWidths {
        let axes = max(axisCount, 0)
        let axisBlock = CGFloat(axes) * axisColumnWidth
        let axisGaps = CGFloat(max(axes - 1, 0)) * columnGap
        // Gaps: select→name, name→axes, axes→style (text lead), style→output (text lead), output→flags
        let fixed =
            horizontalPadding * 2
            + selectColumnWidth
            + axisBlock
            + axisGaps
            + styleColumnWidth
            + flagColumnWidth
            + columnGap * 3
            + textColumnLeadingGap * 2
        let flex = max(nameColumnMinWidth + outputColumnMinWidth, totalWidth - fixed)
        // Name ~42%, Output the rest — both grow on wide windows (no hard name cap).
        let name = max(nameColumnMinWidth, flex * 0.42)
        let output = max(outputColumnMinWidth, flex - name)
        return ColumnWidths(name: name, output: output)
    }
}

extension SaveReviewDisplayCategory {
    var pillStyle: StudioDiffPillStyle {
        switch self {
        case .same: .unchanged
        case .protected: .protected
        case .reflow: .reflowed
        case .renamed: .changed
        case .added: .added
        case .removed: .removed
        }
    }
}

struct StudioFilterBadge: View {
    let category: SaveReviewDisplayCategory
    let count: Int
    var isHidden: Bool
    var isIsolated: Bool
    let action: (_ commandClick: Bool) -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action(NSEvent.modifierFlags.contains(.command))
        } label: {
            Text("\(category.filterLabel.uppercased()) \(count)")
                .font(StudioTypography.filterBadgeLabel)
                .tracking(0.3)
                .foregroundStyle(isHidden ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.primary))
                .padding(.horizontal, StudioSpacing.pillHorizontalInset)
                .padding(.vertical, StudioSpacing.instanceRowVertical)
                .background {
                    ZStack {
                        if !isHidden {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(category.pillStyle.background)
                        }
                        if isHovered, !isHidden, !isIsolated {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(StudioColors.hoverFill)
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            isIsolated ? Color.primary.opacity(0.22) : (isHidden ? Color.clear : category.pillStyle.border),
                            lineWidth: isIsolated ? 1 : 0.5
                        )
                }
                .opacity(isHidden ? 0.32 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct StudioSaveReviewTabBar: View {
    let tabs: [SaveReviewTabPresentation]
    @Binding var selectedTab: SaveReviewTableTab

    var body: some View {
        HStack(spacing: 3) {
            ForEach(tabs, id: \.tabID) { tab in
                let isSelected = selectedTab == tab.id
                let hasChanges = tab.changedCount > 0
                Button {
                    selectedTab = tab.id
                } label: {
                    HStack(spacing: 7) {
                        Text(tab.label)
                            .font(StudioTypography.bodyMedium.weight(isSelected ? .semibold : .regular))
                        Text("\(tab.changedCount) of \(tab.totalCount)")
                            .font(StudioTypography.columnLabel)
                            .monospacedDigit()
                            .foregroundStyle(hasChanges ? Color.primary : Color.secondary.opacity(0.7))
                            .padding(.horizontal, StudioSpace.x1_5)
                            .padding(.vertical, StudioSpacing.instanceRowGap)
                            .background(
                                hasChanges ? StudioColors.warningFill : StudioColors.selectionNeutralFill,
                                in: Capsule()
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .background(
                        isSelected ? StudioColors.surfaceLight : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .shadow(color: isSelected ? Color.black.opacity(0.2) : .clear, radius: 2, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(
                    shape: .roundedRect(cornerRadius: 6),
                    isEnabled: !isSelected
                )
            }
        }
        .padding(3)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: 0.5)
        )
    }
}

struct StudioSaveReviewPhaseHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(StudioTypography.sectionLabel)
            .tracking(0.5)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background(SaveReviewLayout.phaseHeaderBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(StudioColors.surfaceStroke)
                    .frame(height: 0.5)
            }
            .zIndex(1)
    }
}

struct StudioSaveReviewCategoryTag: View {
    let category: SaveReviewDisplayCategory

    var body: some View {
        Text(category.filterLabel.uppercased())
            .font(StudioTypography.filterBadgeLabel)
            .tracking(0.3)
            .foregroundStyle(.primary)
            .padding(.horizontal, StudioSpacing.tagHorizontalInset)
            .padding(.vertical, StudioSpace.x0_5)
            .background(category.pillStyle.background, in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(category.pillStyle.border, lineWidth: 0.5)
            }
    }
}

// MARK: - Save Review row typography
//
// File-bound content (coordinates, quoted strings, tag=value, nameID slots in values)
// → monospaced. Human labels, section context, and read-only notes → system sans.
enum SaveReviewTypography {
    static let fieldLabel = Font.system(size: 12, weight: .medium)
    static let fieldLabelMono = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let fieldDetail = Font.system(size: 10)
    static let nameID = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let value = Font.system(size: 10.5, design: .monospaced)
    static let valueSecondary = Font.system(size: 10, design: .monospaced)
    static let note = Font.system(size: 10)

    /// Row identifier when it is a file-native key (e.g. `wgth = 400`).
    static func fieldTitleFont(_ title: String) -> Font {
        if title.range(of: #"^[a-zA-Z]{4} = "#, options: .regularExpression) != nil {
            return fieldLabelMono
        }
        return fieldLabel
    }

    /// Subtitle lines that carry coordinates / tags use mono; descriptive labels use sans.
    static func fieldDetailFont(_ subtitle: String) -> Font {
        if subtitle.contains("=") || subtitle.hasPrefix("tag=") {
            return valueSecondary
        }
        return fieldDetail
    }
}

struct StudioStreamlinedDiffRow: View {
    let row: SaveReviewRowPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(gutterColor)
                .frame(width: SaveReviewLayout.gutterWidth)
                .padding(.leading, SaveReviewLayout.gutterLeadingPadding)
                .padding(.trailing, SaveReviewLayout.gutterTrailingPadding)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.fieldTitle)
                        .font(SaveReviewTypography.fieldTitleFont(row.fieldTitle))
                        .lineLimit(2)
                    if !row.fieldSubtitle.isEmpty {
                        Text(row.fieldSubtitle)
                            .font(SaveReviewTypography.fieldDetailFont(row.fieldSubtitle))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                .frame(width: SaveReviewLayout.fieldColumnWidth, alignment: .leading)
                .layoutPriority(1)

                Group {
                    if let nameID = row.nameID {
                        Text("\(nameID)")
                            .font(SaveReviewTypography.nameID)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    } else {
                        Text("—")
                            .font(SaveReviewTypography.fieldDetail)
                            .foregroundStyle(.quaternary)
                    }
                }
                .frame(width: SaveReviewLayout.nameIDColumnWidth, alignment: .trailing)
                .padding(.leading, SaveReviewLayout.nameIDColumnLeadingGap)
                .padding(.trailing, SaveReviewLayout.nameIDColumnTrailingGap)
                .layoutPriority(2)

                VStack(alignment: .leading, spacing: 3) {
                    if let afterValue = row.afterValue, !afterValue.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            StudioSaveReviewCategoryTag(category: row.category)
                            Text(afterValue)
                                .font(SaveReviewTypography.value)
                                .foregroundStyle(valueColor)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else if row.category == .removed {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            StudioSaveReviewCategoryTag(category: row.category)
                            Text("—")
                                .font(SaveReviewTypography.value)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if let secondaryLine {
                        Text(secondaryLine)
                            .font(row.noteLine != nil && row.wasLine == nil ? SaveReviewTypography.note : SaveReviewTypography.valueSecondary)
                            .foregroundStyle(.tertiary)
                            .italic(row.noteLine != nil && row.wasLine == nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, SaveReviewLayout.rowVerticalPadding)
        .padding(.trailing, SaveReviewLayout.horizontalPadding)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StudioColors.surfaceStroke)
                .frame(height: 0.5)
                .padding(.leading, SaveReviewLayout.horizontalPadding)
        }
    }

    /// Collapses `wasLine` + `noteLine` onto a single row so the value column
    /// never grows past badge/value + one secondary line (2 lines total).
    private var secondaryLine: String? {
        let parts = [row.wasLine, row.noteLine].compactMap { $0 }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private var gutterColor: Color {
        if row.category == .same {
            return StudioColors.surfaceStroke
        }
        return row.category.pillStyle.foreground
    }

    private var valueColor: Color {
        row.category == .same ? .secondary : .primary
    }
}

struct StudioSectionLabel: View {
    let title: String
    /// When `false` (floating menus/popovers), uses `.secondary` for readable contrast on material surfaces.
    var muted: Bool = true

    var body: some View {
        Text(title.uppercased())
            .font(StudioTypography.sectionLabel)
            .foregroundStyle(muted ? .tertiary : .secondary)
            .tracking(0.4)
    }
}

/// Cross-panel vertical chrome bands — fixed heights so Axis Tree / Instances /
/// Inspector body content shares a start baseline. Values are `StudioSpace` multiples.
enum StudioChromeBand {
    /// Panel title bar (AXIS TREE / INSTANCES / INSPECTOR).
    static let header: CGFloat = StudioSpace.x9
    /// Scope / tab row (Instances|Names, Project|Instance, Axis Tree glance).
    static let scope: CGFloat = StudioSpace.x9
    /// Context / tools row (filter, project title, instance-grid summary).
    static let context: CGFloat = StudioSpace.x17
}

/// Shared empty-state copy so Studio + Instancer read as one product.
enum StudioEmptyCopy {
    static let openOrDropFont = "Open or drop a variable font to get started."
    static let openOrDropFontOrProject = "Open or drop fonts or projects to get started."
    static let instancerListHint = "Select a project font tab to load its named instances."
    static let noProjectInspector = "Open or drop fonts or projects to get started."
}

/// Shared panel header band with bottom divider — use for section headers and collapsed panel rails.
struct StudioPanelHeaderChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(height: StudioChromeBand.header)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}

/// Panel section header — fixed height via `StudioChromeBand.header`.
struct StudioPanelHeader<Trailing: View>: View {
    let title: String
    var horizontalPadding: CGFloat = StudioSpacing.panelHorizontal
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        horizontalPadding: CGFloat = StudioSpacing.panelHorizontal,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.horizontalPadding = horizontalPadding
        self.trailing = trailing
    }

    var body: some View {
        StudioPanelHeaderChrome {
            HStack(spacing: StudioSpacing.controlGap) {
                StudioSectionLabel(title: title)
                Spacer(minLength: 0)
                trailing()
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}

struct StudioWarningBadge: View {
    static let slotSize: CGFloat = 16

    let help: String
    var systemImage: String = "exclamationmark.triangle.fill"
    var action: (() -> Void)?

    var body: some View {
        let icon = Image(systemName: systemImage)
            .font(.system(size: 9))
            .foregroundStyle(StudioColors.warningForeground)
            .frame(width: Self.slotSize, height: Self.slotSize)

        if let action {
            Button(action: action) { icon }
                .buttonStyle(.plain)
                .studioHoverIcon(tint: StudioColors.warningForeground)
                .help(help)
        } else {
            icon.help(help)
        }
    }
}

struct StudioFilterChip<Trailing: View>: View {
    var icon: String? = "line.3.horizontal.decrease"
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    init(
        icon: String? = "line.3.horizontal.decrease",
        label: String,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.label = label
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Label(label, systemImage: icon)
                    .font(StudioTypography.meta)
            } else {
                Text(label)
                    .font(StudioTypography.meta)
            }
            trailing()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}

struct StudioIncludeCheckbox: View {
    let isOn: Bool
    var isIndeterminate: Bool = false
    let action: () -> Void

    static let size: CGFloat = 13
    static let hitSize: CGFloat = 16

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: StudioRadius.small)
                    .strokeBorder(
                        isOn || isIndeterminate
                            ? StudioColors.brand.opacity(0.55)
                            : Color.secondary.opacity(0.35),
                        lineWidth: StudioStroke.regular
                    )
                    .frame(width: Self.size, height: Self.size)
                if isIndeterminate {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 1.5)
                } else if isOn {
                    Image(systemName: "checkmark")
                        .font(StudioTypography.iconGlyph.weight(.bold))
                        .foregroundStyle(StudioColors.brand)
                }
            }
            .frame(width: Self.hitSize, height: Self.hitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.small))
        .studioInteractiveCursor()
        .help(helpText)
    }

    private var helpText: String {
        if isIndeterminate {
            return "Mixed inclusion — click to include all"
        }
        return isOn ? "Exclude from export" : "Include in export"
    }
}

struct StudioGroupHeader: View {
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: StudioSpacing.rowGap) {
            Text(label)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(count)")
                .foregroundStyle(.primary)
        }
        .font(StudioTypography.columnLabel)
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        // Opaque flat band — no padding outside this view; list owns section spacing.
        .background {
            Rectangle()
                .fill(.background)
                .padding(.horizontal, -StudioSpacing.panelHorizontal)
        }
    }
}

struct StudioCompactToolbar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, StudioSpacing.toolbarVertical)
    }
}

struct StudioInspectorBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            StudioSectionLabel(title: title)
            content
        }
    }
}

struct StudioKeyValueRow: View {
    let key: String
    let value: String
    var valueFont: Font = StudioTypography.body
    var valueColor: Color = .primary
    var muted: Bool = false

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioTagPill(text: key, compact: true)
                .opacity(muted ? 0.65 : 1)
            Text(value)
                .font(valueFont)
                .foregroundStyle(muted ? Color.secondary : valueColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

/// Return / Escape keyboard contract for `StudioTextField` and `StudioInlineTextField`.
enum StudioTextSubmitBehavior {
    /// Return accepts the edit and resigns focus — default for forms and inspector fields.
    case commit
    /// Return runs `onSubmit` without resigning — multi-field sheets (Add Stop) that sequence fields on Return.
    case advance
}

@MainActor
enum StudioFieldFocus {
    static func resignIfEditing() {
        guard NSApp.keyWindow?.firstResponder is NSTextView else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
}

/// Routes caret + selection highlight through `StudioColors.brand` instead of system accent.
private struct StudioTextInputAccentModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(StudioColors.brand)
            .background {
                StudioTextInputAccentConfigurator()
                    .frame(width: 0, height: 0)
            }
    }
}

private struct StudioTextInputAccentConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> StudioTextInputAccentView {
        let view = StudioTextInputAccentView()
        view.coordinator = context.coordinator
        context.coordinator.hostView = view
        context.coordinator.startObserving()
        return view
    }

    func updateNSView(_ nsView: StudioTextInputAccentView, context: Context) {
        nsView.applyAccent()
    }

    final class Coordinator {
        weak var hostView: StudioTextInputAccentView?
        private var observers: [NSObjectProtocol] = []

        func startObserving() {
            guard observers.isEmpty else { return }
            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidBeginEditingNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.hostView?.applyAccent()
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidEndEditingNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.hostView?.applyAccent()
                }
            )
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}

private final class StudioTextInputAccentView: NSView {
    weak var coordinator: StudioTextInputAccentConfigurator.Coordinator?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAccent()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        applyAccent()
    }

    func applyAccent() {
        guard let field = findNearestTextField() else { return }
        let brand = StudioColors.brandNSColor
        if let editor = field.currentEditor() as? NSTextView {
            editor.insertionPointColor = brand
            editor.selectedTextAttributes = [
                .backgroundColor: brand.withAlphaComponent(0.28),
                .foregroundColor: editor.textColor ?? .textColor,
            ]
        }
    }

    private func findNearestTextField() -> NSTextField? {
        var view: NSView? = superview
        while let current = view {
            if let field = findTextField(in: current) {
                return field
            }
            view = current.superview
        }
        return nil
    }

    private func findTextField(in root: NSView) -> NSTextField? {
        if let field = root as? NSTextField, field.isEditable || field.isSelectable {
            return field
        }
        for subview in root.subviews {
            if let field = findTextField(in: subview) {
                return field
            }
        }
        return nil
    }
}

extension View {
    /// Fixed brand tint for switches, links, and controls that would otherwise follow system accent.
    func studioBrandTint() -> some View {
        tint(StudioColors.brand)
    }
}

/// Compact text field — fixed row height, flat fill, darker when focused, no stroke / focus ring.
struct StudioTextField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = StudioTypography.caption
    var rowHeight: CGFloat = StudioFieldMetrics.captionRowHeight
    /// When false, renders without field chrome (for embedding in `StudioSearchField`).
    var showsFieldChrome: Bool = true

    /// When set, non-empty value text uses this color (e.g. clarifier fields in file naming).
    var filledForeground: Color? = nil
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var submitBehavior: StudioTextSubmitBehavior = .commit
    var focusBinding: FocusState<Bool>.Binding? = nil

    @FocusState private var internalFocus: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var activeFocus: FocusState<Bool>.Binding {
        focusBinding ?? $internalFocus
    }

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(font)
                .foregroundStyle(StudioColors.textPlaceholder)
        )
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(valueForeground)
            .padding(.horizontal, showsFieldChrome ? StudioFieldMetrics.horizontalPadding : 0)
            .frame(height: rowHeight, alignment: .center)
            .background {
                if showsFieldChrome {
                    RoundedRectangle(cornerRadius: StudioRadius.control)
                        .fill(fieldBackground)
                }
            }
            .focused(activeFocus)
            .modifier(StudioFocusRingSuppression())
            .modifier(StudioTextInputAccentModifier())
            .studioInteractiveCursor()
            .onSubmit { handleSubmit() }
            .onExitCommand { handleCancel() }
    }

    private func handleSubmit() {
        onSubmit?()
        guard submitBehavior == .commit else { return }
        activeFocus.wrappedValue = false
        StudioFieldFocus.resignIfEditing()
    }

    private func handleCancel() {
        onCancel?()
        activeFocus.wrappedValue = false
        StudioFieldFocus.resignIfEditing()
    }

    private var valueForeground: Color {
        if !isEnabled { return .secondary }
        if !text.isEmpty, let filledForeground { return filledForeground }
        return .primary
    }

    private var fieldBackground: Color {
        activeFocus.wrappedValue ? StudioColors.fieldFillFocused : StudioColors.fieldFill
    }
}

/// Soft-wrapping text field — grows by wrapped lines; flat focused fill; no stroke.
/// Return commits via `onSubmit`; Escape via `onCancel`. Lives in StudioDesign so
/// call sites never use a raw `TextField`.
struct StudioWrappingTextField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = StudioTypography.monoValue
    var lineSpacing: CGFloat = StudioSpace.x1
    var lineLimit: ClosedRange<Int> = 1...12
    var horizontalPadding: CGFloat = StudioFieldMetrics.horizontalPadding
    var verticalPadding: CGFloat = StudioSpace.x1_5
    var minHeight: CGFloat = StudioFieldMetrics.monoValueRowHeight
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .font(font)
                .foregroundStyle(StudioColors.textPlaceholder),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(font)
        .lineSpacing(lineSpacing)
        .lineLimit(lineLimit)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: StudioRadius.control)
                .fill(StudioColors.fieldFillFocused)
        }
        .modifier(StudioFocusRingSuppression())
        .modifier(StudioTextInputAccentModifier())
        .focused($focused)
        .onAppear { focused = true }
        .onSubmit { onSubmit?() }
        .onKeyPress(.return) {
            onSubmit?()
            return .handled
        }
        .onExitCommand { onCancel?() }
    }
}

/// Search bar with magnifier and optional clear button — same flat field chrome as `StudioTextField`.
struct StudioSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    var isFocused: FocusState<Bool>.Binding? = nil

    @FocusState private var internalFocus: Bool

    private var activeFocus: FocusState<Bool>.Binding {
        isFocused ?? $internalFocus
    }

    private var isFieldFocused: Bool {
        activeFocus.wrappedValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(StudioTypography.meta)
                .foregroundStyle(StudioColors.textPlaceholder)

            StudioTextField(
                placeholder: placeholder,
                text: $text,
                showsFieldChrome: false,
                focusBinding: activeFocus
            )

            if !text.isEmpty {
                StudioDismissButton(scale: .chip, style: .fill) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, 7)
        .frame(height: StudioFieldMetrics.captionRowHeight + 8)
        .background(
            isFieldFocused ? StudioColors.fieldFillFocused : StudioColors.fieldFill,
            in: RoundedRectangle(cornerRadius: StudioRadius.control)
        )
    }
}

/// Optional / required numeric field — same flat chrome as `StudioTextField`.
struct StudioNumberField: View {
    let placeholder: String
    @Binding var value: Double?
    var font: Font = StudioTypography.monoMeta
    var rowHeight: CGFloat = StudioFieldMetrics.monoValueRowHeight
    var alignment: TextAlignment = .leading
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            "",
            value: $value,
            format: .number,
            prompt: Text(placeholder)
                .font(font)
                .foregroundStyle(StudioColors.textPlaceholder)
        )
        .textFieldStyle(.plain)
        .font(font)
        .multilineTextAlignment(alignment)
        .padding(.horizontal, StudioFieldMetrics.horizontalPadding)
        .frame(height: rowHeight, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: StudioRadius.control)
                .fill(isFocused ? StudioColors.fieldFillFocused : StudioColors.fieldFill)
        }
        .focused($isFocused)
        .modifier(StudioFocusRingSuppression())
        .modifier(StudioTextInputAccentModifier())
        .onSubmit {
            onSubmit?()
            isFocused = false
            StudioFieldFocus.resignIfEditing()
        }
    }
}

/// Non-optional numeric field — same flat chrome as `StudioTextField`.
struct StudioBoundNumberField: View {
    @Binding var value: Double
    var font: Font = StudioTypography.monoMeta
    var rowHeight: CGFloat = StudioFieldMetrics.monoValueRowHeight
    var alignment: TextAlignment = .trailing
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", value: $value, format: .number)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .padding(.horizontal, StudioFieldMetrics.horizontalPadding)
            .frame(height: rowHeight, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: StudioRadius.control)
                    .fill(isFocused ? StudioColors.fieldFillFocused : StudioColors.fieldFill)
            }
            .focused($isFocused)
            .modifier(StudioFocusRingSuppression())
            .modifier(StudioTextInputAccentModifier())
            .onSubmit {
                onSubmit?()
                isFocused = false
                StudioFieldFocus.resignIfEditing()
            }
    }
}

/// Inline table / axis-tree edit field with shared chrome.
struct StudioInlineTextField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = StudioTypography.body
    var foreground: Color = .primary
    var rowHeight: CGFloat = StudioFieldMetrics.bodyRowHeight
    var alignment: TextAlignment = .leading
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var submitBehavior: StudioTextSubmitBehavior = .commit

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(foreground)
            .multilineTextAlignment(alignment)
            .studioInlineEditField(isActive: true, isFocused: isFocused, rowHeight: rowHeight)
            .modifier(StudioFocusRingSuppression())
            .modifier(StudioTextInputAccentModifier())
            .focused($isFocused)
            .studioInteractiveCursor()
            .onSubmit { handleSubmit() }
            .onExitCommand { handleCancel() }
    }

    private func handleSubmit() {
        onSubmit?()
        guard submitBehavior == .commit else { return }
        isFocused = false
        StudioFieldFocus.resignIfEditing()
    }

    private func handleCancel() {
        onCancel?()
        isFocused = false
        StudioFieldFocus.resignIfEditing()
    }
}

enum StudioTabChipShape {
    case capsule
    case roundedRect
}

/// Project / file / save-review tab chip — stable padding and height.
struct StudioTabChip<Label: View, Trailing: View>: View {
    var isSelected: Bool = false
    var isHighlighted: Bool = false
    var isDropTarget: Bool = false
    var dropTargetTint: Color = StudioColors.dropAddExisting
    var shape: StudioTabChipShape = .capsule
    @ViewBuilder var label: () -> Label
    @ViewBuilder var trailing: () -> Trailing
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            label()
            trailing()
        }
        .padding(.horizontal, StudioFieldMetrics.tabChipHorizontalPadding)
        .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
        .frame(minHeight: StudioFieldMetrics.tabChipRowHeight)
        .background {
            switch shape {
            case .capsule:
                Capsule()
                    .fill(chipFill)
                    .overlay {
                        if isHighlighted {
                            Capsule()
                                .strokeBorder(StudioColors.selectionStroke, lineWidth: 0.5)
                        }
                    }
            case .roundedRect:
                RoundedRectangle(cornerRadius: StudioRadius.chip)
                    .fill(chipFill)
                    .overlay {
                        if isHighlighted {
                            RoundedRectangle(cornerRadius: StudioRadius.chip)
                                .strokeBorder(StudioColors.selectionStroke, lineWidth: 0.5)
                        }
                    }
            }
        }
        .overlay(alignment: .bottom) {
            if isDropTarget {
                Rectangle()
                    .fill(dropTargetTint)
                    .frame(height: 1)
                    .padding(.horizontal, shape == .capsule ? 8 : 2)
            }
        }
        .background {
            if isDropTarget {
                chipDropFill
            }
        }
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var chipDropFill: some View {
        switch shape {
        case .capsule:
            Capsule()
                .fill(dropTargetTint.opacity(StudioColors.dropZoneFillOpacity))
        case .roundedRect:
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .fill(dropTargetTint.opacity(StudioColors.dropZoneFillOpacity))
        }
    }

    private var chipFill: Color {
        if isSelected || isHighlighted {
            return StudioColors.selectionFill
        }
        if isHovered {
            return StudioColors.hoverFill
        }
        return Color.primary.opacity(0.04)
    }
}

/// Fixed-height row for `DisclosureGroup` labels — prevents expand/collapse layout shift.
struct StudioDisclosureLabelRow<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: StudioFieldMetrics.disclosureLabelRowHeight, alignment: .center)
    }
}

/// Static label occupying the same vertical space and idle fill as `StudioTextField`.
struct StudioFieldLabel: View {
    let text: String
    var font: Font = StudioTypography.caption
    var rowHeight: CGFloat = StudioFieldMetrics.captionRowHeight
    var fontWeight: Font.Weight = .regular
    var foreground: Color = .primary
    /// Match editable field chrome so display ↔ edit does not shift.
    var showsFieldChrome: Bool = true

    var body: some View {
        Text(text)
            .font(font.weight(fontWeight))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, StudioFieldMetrics.horizontalPadding)
            .frame(height: rowHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if showsFieldChrome {
                    RoundedRectangle(cornerRadius: StudioRadius.control)
                        .fill(StudioColors.fieldFill)
                }
            }
    }
}

/// Chrome icon scale — one glyph weight, two hit targets. Chrome icons should be
/// sized through this, never hand-tuned per call site.
enum StudioChromeScale {
    case toolbar
    case chip

    /// Shared SF Symbol weight for chrome icons (dismiss, overflow, toolbar, edit).
    static let symbolWeight: Font.Weight = .semibold

    var pointSize: CGFloat {
        switch self {
        case .toolbar: StudioFieldMetrics.toolbarIconPointSize
        case .chip: StudioFieldMetrics.chipIconPointSize
        }
    }

    var hitSize: CGFloat {
        switch self {
        case .toolbar: StudioFieldMetrics.toolbarIconHitSize
        case .chip: StudioFieldMetrics.chipIconHitSize
        }
    }
}

/// Shared SF Symbol names for Studio chrome — keep call sites on these, not ad-hoc strings.
enum StudioSymbols {
    /// Rename / edit affordance. Prefer over bare `pencil` or `pencil.circle`.
    static let edit = "pencil.line"
}

/// Unified dismiss / remove control. Replaces the ad-hoc `xmark`, `xmark.circle`,
/// and `xmark.circle.fill` buttons previously scattered across tabs, chips, rows,
/// and fields. Use `.outline` for close/dismiss, `.fill` for in-row/field remove.
struct StudioDismissButton: View {
    enum Style {
        case outline
        case fill

        var symbol: String {
            switch self {
            case .outline: "xmark.circle"
            case .fill: "xmark.circle.fill"
            }
        }
    }

    var scale: StudioChromeScale = .toolbar
    var style: Style = .fill
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: style.symbol)
                .font(.system(size: scale.pointSize, weight: StudioChromeScale.symbolWeight))
                .symbolRenderingMode(.monochrome)
                .frame(width: scale.hitSize, height: scale.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(StudioIconButtonStyle())
        .help(help)
    }
}

/// Unified overflow (ellipsis) menu. Never renders the system menu chevron so it
/// reads as a single icon next to its neighbors. Replaces `StudioToolbarIconMenu`.
struct StudioOverflowMenu<Content: View>: View {
    var scale: StudioChromeScale = .toolbar
    var help: String = "Actions"
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: scale.pointSize, weight: StudioChromeScale.symbolWeight))
                .symbolRenderingMode(.monochrome)
                .frame(width: scale.hitSize, height: scale.hitSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .studioHoverIcon()
        .help(help)
    }
}

/// Display-only selection mark (the visual half of a radio). Use inside an existing
/// Button / row for mutually-exclusive "picked" state. `StudioElidableRadio` remains
/// the self-contained interactive version for the axis-tree Elided column.
struct StudioRadioMark: View {
    let isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1)
                .frame(width: 14, height: 14)
            if isOn {
                Circle()
                    .fill(StudioColors.brand)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 16, height: 16)
    }
}

/// Canonical linked-value glyph (Format-3 links, fill preview). One size everywhere.
/// Keep this *outside* any `Menu` label — AppKit menu-button chrome can rescale
/// SF Symbols inside the label even when an explicit `.font` is applied.
///
/// - `isEditable: false` (default) — muted / locked (Naming axis, read-only).
/// - `isEditable: true` — primary (changeable link-to target).
struct StudioLinkGlyph: View {
    var isEditable: Bool = false

    var body: some View {
        Image(systemName: "link")
            .font(StudioTypography.linkGlyph)
            .foregroundStyle(isEditable ? .primary : .tertiary)
    }
}

/// Format-3 linked-target suffix for non-Menu contexts (read-only preview rows).
/// For interactive stop rows, compose `StudioLinkGlyph` + target `Text` as siblings
/// beside a `Menu` so the chain is not hosted inside menu chrome.
struct StudioFormat3LinkLabel: View {
    let linkedTargetName: String?
    var placeholder: String = "Link…"

    var body: some View {
        HStack(spacing: 4) {
            StudioLinkGlyph()
            Text(linkedTargetName ?? placeholder)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Canonical "add" affordance label — one glyph size and spacing across add actions.
/// The symbol may vary (`plus`, `folder.badge.plus`, …) but its sizing does not.
struct StudioAddLabel: View {
    let title: String
    var systemImage: String = "plus"
    var foreground: Color = .secondary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(StudioTypography.caption)
            .foregroundStyle(foreground)
            .labelStyle(.titleAndIcon)
    }
}

/// Toolbar / header icon control — fixed hit target, consistent symbol size.
struct StudioToolbarIconButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(
                    size: StudioFieldMetrics.toolbarIconPointSize,
                    weight: StudioChromeScale.symbolWeight
                ))
                .symbolRenderingMode(.monochrome)
                .frame(
                    width: StudioFieldMetrics.toolbarIconHitSize,
                    height: StudioFieldMetrics.toolbarIconHitSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(StudioIconButtonStyle())
        .studioInteractiveCursor()
        .help(help)
    }
}

/// Legacy overflow menu — renders the system menu chevron. Superseded by
/// `StudioOverflowMenu`; call sites migrate in Phase 2. Do not use in new code.
struct StudioToolbarIconMenu<Content: View>: View {
    var help: String = "Actions"
    @ViewBuilder var content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(
                    size: StudioFieldMetrics.toolbarIconPointSize,
                    weight: StudioChromeScale.symbolWeight
                ))
                .symbolRenderingMode(.monochrome)
                .frame(
                    width: StudioFieldMetrics.toolbarIconHitSize,
                    height: StudioFieldMetrics.toolbarIconHitSize
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .studioHoverIcon()
        .help(help)
    }
}

struct StudioFocusRingSuppression: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

extension View {
    /// Inline axis-tree / table edit chrome — fixed height, flat fill, no stroke.
    func studioInlineEditField(
        isActive: Bool,
        isFocused: Bool = true,
        rowHeight: CGFloat = StudioFieldMetrics.bodyRowHeight
    ) -> some View {
        padding(.horizontal, isActive ? StudioFieldMetrics.horizontalPadding : 0)
            .frame(height: isActive ? rowHeight : nil, alignment: .center)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: StudioRadius.control)
                        .fill(isFocused ? StudioColors.fieldFillFocused : StudioColors.fieldFill)
                }
            }
            .modifier(StudioFocusRingSuppression())
    }
}

// MARK: - Hover chrome

enum StudioHoverShape: Equatable {
    case rect
    case roundedRect(cornerRadius: CGFloat = StudioRadius.row)
    case capsule
    case circle
}

private struct StudioHoverFillModifier: ViewModifier {
    var shape: StudioHoverShape
    var isEnabled: Bool
    var emphasized: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background {
                if isEnabled, isHovered {
                    hoverBackground
                }
            }
            .onHover { hovering in
                isHovered = isEnabled && hovering
            }
    }

    @ViewBuilder
    private var hoverBackground: some View {
        let fill = emphasized ? Color.primary.opacity(0.08) : StudioColors.hoverFill
        switch shape {
        case .rect:
            Rectangle().fill(fill)
        case .roundedRect(let radius):
            RoundedRectangle(cornerRadius: radius).fill(fill)
        case .capsule:
            Capsule().fill(fill)
        case .circle:
            Circle().fill(fill)
        }
    }
}

/// Pointer-over color shift for plain text links — no fill wash, no weight change.
enum StudioHoverLinkStyle: Equatable {
    case accent
    case secondary
    case primary
}

private struct StudioHoverLinkModifier: ViewModifier {
    var style: StudioHoverLinkStyle
    var isEnabled: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(resolvedForeground)
            .onHover { hovering in
                isHovered = isEnabled && hovering
            }
    }

    private var interactionState: StudioInteractionState {
        guard isEnabled else { return .idle }
        return isHovered ? .hovered : .idle
    }

    private var resolvedForeground: Color {
        StudioLinkForeground.resolve(style: style, state: interactionState)
    }
}

/// Pointer-over color shift for toolbar / row icons — secondary → primary, or tinted brighten.
private struct StudioHoverIconModifier: ViewModifier {
    var isEnabled: Bool
    var tint: Color?
    @State private var isHovered = false

    func body(content: Content) -> some View {
        Group {
            if isEnabled {
                content
                    .foregroundStyle(resolvedForeground)
                    .onHover { hovering in
                        isHovered = hovering
                    }
            } else {
                content
            }
        }
    }

    private var interactionState: StudioInteractionState {
        isHovered ? .hovered : .idle
    }

    private var resolvedForeground: Color {
        StudioIconForeground.resolve(tint: tint, state: interactionState)
    }
}

extension View {
    /// Pointer-over fill for chips, segment tabs, and other padded controls.
    func studioHoverFill(
        shape: StudioHoverShape = .roundedRect(),
        isEnabled: Bool = true,
        emphasized: Bool = false
    ) -> some View {
        modifier(StudioHoverFillModifier(shape: shape, isEnabled: isEnabled, emphasized: emphasized))
    }

    /// Pointer-over color shift for plain text links — no background wash or weight change.
    func studioHoverLink(
        _ style: StudioHoverLinkStyle = .primary,
        isEnabled: Bool = true
    ) -> some View {
        modifier(StudioHoverLinkModifier(style: style, isEnabled: isEnabled))
    }

    /// Pointer-over color shift for icons — secondary → primary, or subtle tint brighten.
    func studioHoverIcon(isEnabled: Bool = true, tint: Color? = nil) -> some View {
        modifier(StudioHoverIconModifier(isEnabled: isEnabled, tint: tint))
    }

    /// Dashed hover ring + open-hand cursor for press-drag reorder targets (no fill wash).
    func studioDragAffordances(
        isEnabled: Bool = true,
        isDragging: Bool = false,
        cornerRadius: CGFloat = StudioRadius.chip,
        showsOutline: Bool = true,
        showsCursor: Bool = true,
        /// Extends the dashed outline into horizontal margins without shifting content.
        outlineHorizontalOutset: CGFloat = 0
    ) -> some View {
        modifier(
            StudioDragAffordancesModifier(
                isEnabled: isEnabled,
                isDragging: isDragging,
                cornerRadius: cornerRadius,
                showsOutline: showsOutline,
                showsCursor: showsCursor,
                outlineHorizontalOutset: outlineHorizontalOutset
            )
        )
    }

    /// Marks a control that should show the arrow pointer inside a drag-hover container.
    func studioInteractiveCursor() -> some View {
        modifier(StudioInteractiveCursorModifier())
    }
}

private struct StudioInteractiveHoverKey: PreferenceKey {
    static var defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct StudioDragCursorGateKey: EnvironmentKey {
    static var defaultValue: StudioDragCursorGate? = nil
}

extension EnvironmentValues {
    fileprivate var studioDragCursorGate: StudioDragCursorGate? {
        get { self[StudioDragCursorGateKey.self] }
        set { self[StudioDragCursorGateKey.self] = newValue }
    }
}

/// Synchronous grab-cursor suppressor for interactive children inside drag targets.
private final class StudioDragCursorGate {
    private var depth = 0
    var onChange: ((Bool) -> Void)?

    var isSuppressed: Bool { depth > 0 }

    func push() {
        depth += 1
        if depth == 1 {
            onChange?(true)
            NSCursor.arrow.set()
        }
    }

    func pop() {
        guard depth > 0 else { return }
        depth -= 1
        if depth == 0 {
            onChange?(false)
        }
    }
}

private struct StudioInteractiveCursorModifier: ViewModifier {
    @State private var isHovered = false
    @Environment(\.studioDragCursorGate) private var gate

    func body(content: Content) -> some View {
        content
            .overlay {
                StudioInteractiveHoverReporter(isHovered: $isHovered, gate: gate)
            }
            .preference(key: StudioInteractiveHoverKey.self, value: isHovered)
    }
}

private enum StudioCursorMarkers {
    static let interactive = NSUserInterfaceItemIdentifier("studio.interactive.cursor")
}

private enum StudioDragCursorPolicy {
    static func defersDragCursor(
        at locationInWindow: NSPoint,
        in window: NSWindow?,
        suppressGrabCursor: Bool,
        gate: StudioDragCursorGate? = nil
    ) -> Bool {
        if suppressGrabCursor || gate?.isSuppressed == true { return true }
        guard let window, let contentView = window.contentView else { return false }
        let point = contentView.convert(locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(point) else { return false }
        return hitView.studioDefersDragCursor
    }
}

private extension NSView {
    var studioDefersDragCursor: Bool {
        var view: NSView? = self
        while let current = view {
            if current.identifier == StudioCursorMarkers.interactive {
                return true
            }
            if current is NSControl {
                return true
            }
            if let textField = current as? NSTextField, textField.isEditable {
                return true
            }
            if current is NSTextView {
                return true
            }
            let typeName = String(describing: Swift.type(of: current))
            if typeName.contains("Switch")
                || typeName.contains("PopUpButton")
                || typeName.contains("Button")
                || typeName.contains("TextField") {
                return true
            }
            view = current.superview
        }
        return false
    }
}

/// AppKit hover reporter for interactive controls inside drag targets.
private struct StudioInteractiveHoverReporter: NSViewRepresentable {
    @Binding var isHovered: Bool
    var gate: StudioDragCursorGate?

    func makeCoordinator() -> Coordinator {
        Coordinator(isHovered: $isHovered, gate: gate)
    }

    func makeNSView(context: Context) -> StudioInteractiveHoverView {
        let view = StudioInteractiveHoverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: StudioInteractiveHoverView, context: Context) {
        context.coordinator.isHovered = $isHovered
        context.coordinator.gate = gate
    }

    final class Coordinator {
        var isHovered: Binding<Bool>
        var gate: StudioDragCursorGate?

        init(isHovered: Binding<Bool>, gate: StudioDragCursorGate?) {
            self.isHovered = isHovered
            self.gate = gate
        }

        func setHover(_ hovering: Bool) {
            guard isHovered.wrappedValue != hovering else { return }
            isHovered.wrappedValue = hovering
            if hovering {
                gate?.push()
            } else {
                gate?.pop()
            }
        }
    }
}

private final class StudioInteractiveHoverView: NSView {
    weak var coordinator: StudioInteractiveHoverReporter.Coordinator?
    private var isMouseInside = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = StudioCursorMarkers.interactive
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        identifier = StudioCursorMarkers.interactive
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .activeInKeyWindow,
                    .inVisibleRect,
                    .mouseEnteredAndExited,
                    .mouseMoved,
                    .cursorUpdate,
                ],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        setMouseInside(true)
    }

    override func mouseExited(with event: NSEvent) {
        setMouseInside(false)
    }

    override func mouseMoved(with event: NSEvent) {
        syncMouseInside(at: event.locationInWindow)
        if isMouseInside {
            NSCursor.arrow.set()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isPointerInside(event: event) {
            NSCursor.arrow.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    private func setMouseInside(_ inside: Bool) {
        guard isMouseInside != inside else { return }
        isMouseInside = inside
        coordinator?.setHover(inside)
        if inside {
            NSCursor.arrow.set()
        }
    }

    private func syncMouseInside(at locationInWindow: NSPoint) {
        setMouseInside(isPointerInside(locationInWindow: locationInWindow))
    }

    private func isPointerInside(event: NSEvent) -> Bool {
        isPointerInside(locationInWindow: event.locationInWindow)
    }

    private func isPointerInside(locationInWindow: NSPoint) -> Bool {
        let point = convert(locationInWindow, from: nil)
        return bounds.contains(point)
    }
}

private struct StudioDragAffordancesModifier: ViewModifier {
    var isEnabled: Bool
    var isDragging: Bool
    var cornerRadius: CGFloat
    var showsOutline: Bool
    var showsCursor: Bool
    var outlineHorizontalOutset: CGFloat
    @State private var isHovered = false
    @State private var interactiveChildHovered = false
    @State private var cursorGate = StudioDragCursorGate()

    private var affordanceActive: Bool {
        isEnabled && !isDragging && isHovered
    }

    private var trackingEnabled: Bool {
        isEnabled && !isDragging
    }

    func body(content: Content) -> some View {
        content
            .environment(\.studioDragCursorGate, cursorGate)
            .onAppear {
                cursorGate.onChange = { interactiveChildHovered = $0 }
            }
            .overlay {
                if affordanceActive, showsOutline {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            Color.secondary.opacity(0.4),
                            style: StrokeStyle(lineWidth: StudioStroke.regular, dash: StudioStroke.dragDash)
                        )
                        .padding(.horizontal, -outlineHorizontalOutset)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                StudioDragHoverBridge(
                    isHovered: $isHovered,
                    isEnabled: trackingEnabled,
                    showsCursor: showsCursor,
                    suppressGrabCursor: interactiveChildHovered,
                    gate: cursorGate
                )
            }
            .onPreferenceChange(StudioInteractiveHoverKey.self) { interactiveChildHovered = $0 }
            .onChange(of: isDragging) { _, dragging in
                if dragging { isHovered = false }
            }
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { isHovered = false }
            }
    }
}

/// AppKit hover + cursor bridge. SwiftUI `onHover` misses fast pointer moves and
/// flickers across child controls; this view owns enter/exit via tracking areas.
private struct StudioDragHoverBridge: NSViewRepresentable {
    @Binding var isHovered: Bool
    var isEnabled: Bool
    var showsCursor: Bool
    var suppressGrabCursor: Bool
    var gate: StudioDragCursorGate?

    func makeCoordinator() -> Coordinator {
        Coordinator(isHovered: $isHovered)
    }

    func makeNSView(context: Context) -> StudioDragHoverView {
        let view = StudioDragHoverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: StudioDragHoverView, context: Context) {
        context.coordinator.isHovered = $isHovered
        nsView.showsCursor = showsCursor
        let suppressChanged = nsView.suppressGrabCursor != suppressGrabCursor
            || nsView.gate !== gate
        nsView.suppressGrabCursor = suppressGrabCursor
        nsView.gate = gate
        nsView.setEnabled(isEnabled)
        if suppressChanged, let window = nsView.window {
            nsView.applyCursor(at: window.mouseLocationOutsideOfEventStream)
        }
    }

    final class Coordinator {
        var isHovered: Binding<Bool>

        init(isHovered: Binding<Bool>) {
            self.isHovered = isHovered
        }

        func setHover(_ hovering: Bool) {
            guard isHovered.wrappedValue != hovering else { return }
            isHovered.wrappedValue = hovering
        }
    }
}

private final class StudioDragHoverView: NSView {
    weak var coordinator: StudioDragHoverBridge.Coordinator?
    weak var gate: StudioDragCursorGate?
    var showsCursor = true
    var suppressGrabCursor = false
    private var isEnabled = true
    private var isMouseInside = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func setEnabled(_ enabled: Bool) {
        let wasEnabled = isEnabled
        isEnabled = enabled
        window?.invalidateCursorRects(for: self)
        if !enabled {
            if isMouseInside {
                isMouseInside = false
                coordinator?.setHover(false)
            }
            if wasEnabled, showsCursor {
                NSCursor.arrow.set()
            }
            return
        }
        if isMouseInside {
            coordinator?.setHover(true)
            applyCursor()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .activeInKeyWindow,
                    .inVisibleRect,
                    .mouseEnteredAndExited,
                    .mouseMoved,
                    .cursorUpdate,
                ],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            syncHoverState(for: window?.mouseLocationOutsideOfEventStream)
        }
    }

    override func layout() {
        super.layout()
        syncHoverState(for: window?.mouseLocationOutsideOfEventStream)
    }

    override func mouseEntered(with event: NSEvent) {
        setMouseInside(true)
    }

    override func mouseExited(with event: NSEvent) {
        setMouseInside(false)
    }

    override func mouseMoved(with event: NSEvent) {
        syncHoverState(for: event.locationInWindow)
        updateCursor(at: event.locationInWindow)
    }

    override func cursorUpdate(with event: NSEvent) {
        if isEnabled, showsCursor, isPointerInside(event: event) {
            updateCursor(at: event.locationInWindow)
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func resetCursorRects() {
        // Open-hand is applied in cursorUpdate / mouseMoved so child controls can defer.
    }

    private func setMouseInside(_ inside: Bool) {
        guard isMouseInside != inside else { return }
        isMouseInside = inside
        if isEnabled {
            coordinator?.setHover(inside)
            if inside {
                applyCursor()
            }
        }
    }

    private func syncHoverState(for locationInWindow: NSPoint?) {
        guard let locationInWindow else { return }
        setMouseInside(isPointerInside(locationInWindow: locationInWindow))
    }

    private func isPointerInside(event: NSEvent? = nil) -> Bool {
        if let event {
            return isPointerInside(locationInWindow: event.locationInWindow)
        }
        return isMouseInside
    }

    private func isPointerInside(locationInWindow: NSPoint) -> Bool {
        let point = convert(locationInWindow, from: nil)
        return bounds.contains(point)
    }

    func applyCursor(at locationInWindow: NSPoint? = nil) {
        guard let window else { return }
        let point = locationInWindow ?? window.mouseLocationOutsideOfEventStream
        updateCursor(at: point)
    }

    private func updateCursor(at locationInWindow: NSPoint) {
        guard isEnabled, showsCursor, isPointerInside(locationInWindow: locationInWindow) else { return }
        if StudioDragCursorPolicy.defersDragCursor(
            at: locationInWindow,
            in: window,
            suppressGrabCursor: suppressGrabCursor,
            gate: gate
        ) {
            NSCursor.arrow.set()
        } else {
            NSCursor.openHand.set()
        }
    }
}

/// Flat menu picker — solid field fill + accent chevron badge. Replaces system `.pickerStyle(.menu)`.
struct StudioMenuPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    var showsTitle: Bool = true

    private var selectedTitle: String {
        options.first(where: { $0.value == selection })?.title ?? ""
    }

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            if showsTitle, !title.isEmpty {
                Text(title)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize()
            }

            Menu {
                ForEach(options, id: \.value) { option in
                    Button {
                        selection = option.value
                    } label: {
                        if option.value == selection {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: StudioSpacing.tightGap) {
                    Text(selectedTitle.isEmpty ? "Select…" : selectedTitle)
                        .font(StudioTypography.caption)
                        .foregroundStyle(selectedTitle.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: StudioSpacing.tightGap)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(StudioTypography.iconGlyph)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        .background(StudioColors.brand, in: RoundedRectangle(cornerRadius: StudioRadius.small))
                }
                .padding(.leading, StudioSpacing.panelHorizontal)
                .padding(.trailing, StudioSpace.x1)
                .padding(.vertical, StudioSpace.x1_5)
                .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.bodyRowHeight, alignment: .leading)
                .background(StudioColors.buttonSecondaryFill, in: RoundedRectangle(cornerRadius: StudioRadius.control))
                .contentShape(RoundedRectangle(cornerRadius: StudioRadius.control))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
            .studioInteractiveCursor()
            .accessibilityLabel(title.isEmpty ? selectedTitle : title)
        }
    }
}

/// Flat filled action — primary (accent) or secondary (gray). No border, no dashed chrome.
struct StudioFlatButton: View {
    enum Role {
        case primary
        case secondary
        /// Tinted variant (e.g. Add Naming Axis registration indigo).
        case tinted(foreground: Color, background: Color)
    }

    enum Size {
        /// Sheet footers, Instancer Generate / Add Instance.
        case regular
        /// Compact toolbar actions (Add ID…, Resolve).
        case compact
        /// Full-width axis-tree action rows (Add Stop / Fill stops…).
        case row
    }

    let title: String
    var systemImage: String? = nil
    var role: Role = .secondary
    var size: Size = .regular
    var isEnabled: Bool = true
    var expands: Bool = false
    var isDefaultAction: Bool = false
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text(title)
                }
            }
            .font(StudioFlatButtonChrome.font(size: size))
            .lineLimit(1)
        }
        .buttonStyle(StudioFlatButtonStyle(role: role, size: size, expands: expands))
        .disabled(!isEnabled)
        .modifier(StudioDefaultActionModifier(isEnabled: isDefaultAction))
        .studioInteractiveCursor()
        .help(help)
    }
}

/// Fill-based button chrome — hover/press use overlay washes, not foreground dimming.
private enum StudioFlatButtonChrome {
    static func font(size: StudioFlatButton.Size) -> Font {
        switch size {
        case .regular, .row: StudioTypography.caption
        case .compact: StudioTypography.meta
        }
    }

    static func horizontalPadding(size: StudioFlatButton.Size) -> CGFloat {
        StudioSpacing.panelHorizontal
    }

    static func verticalPadding(size: StudioFlatButton.Size) -> CGFloat {
        switch size {
        case .regular: StudioSpacing.tightGap + StudioSpace.x0_5
        case .compact: StudioSpacing.tightGap
        case .row: StudioSpacing.instanceRowVertical
        }
    }

    static func roleIsPrimary(_ role: StudioFlatButton.Role) -> Bool {
        if case .primary = role { return true }
        return false
    }

    static func foreground(role: StudioFlatButton.Role, isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch role {
            case .primary: return Color.primary.opacity(0.35)
            case .secondary: return Color.secondary.opacity(0.55)
            case .tinted(let foreground, _): return foreground.opacity(0.45)
            }
        }
        switch role {
        case .primary: return .white
        case .secondary: return .primary
        case .tinted(let foreground, _): return foreground
        }
    }

    static func fill(role: StudioFlatButton.Role, isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch role {
            case .primary: return StudioColors.brand.opacity(0.22)
            case .secondary: return StudioColors.buttonSecondaryFillDisabled
            case .tinted(_, let background): return background.opacity(0.45)
            }
        }
        switch role {
        case .primary: return StudioColors.brand
        case .secondary: return StudioColors.buttonSecondaryFill
        case .tinted(_, let background): return background
        }
    }

    /// Fill buttons use overlay washes on hover/press — not `StudioInteractionRule` on label color.
    static func overlayOpacity(role: StudioFlatButton.Role, state: StudioInteractionState) -> CGFloat {
        let isPrimary = roleIsPrimary(role)
        switch state {
        case .idle: return 0
        case .hovered: return isPrimary ? 0.10 : 0.06
        case .pressed: return isPrimary ? 0.14 : 0.10
        }
    }
}

struct StudioFlatButtonStyle: ButtonStyle {
    var role: StudioFlatButton.Role
    var size: StudioFlatButton.Size
    var expands: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let state = StudioInteractionState.from(
            isPressed: configuration.isPressed,
            isHovered: isEnabled && isHovered
        )
        let overlayOpacity = StudioFlatButtonChrome.overlayOpacity(role: role, state: state)

        configuration.label
            .foregroundStyle(StudioFlatButtonChrome.foreground(role: role, isEnabled: isEnabled))
            .frame(
                maxWidth: expands || size == .row ? .infinity : nil,
                minHeight: size == .row ? StudioFieldMetrics.listRowMinHeight : nil
            )
            .padding(.horizontal, StudioFlatButtonChrome.horizontalPadding(size: size))
            .padding(.vertical, StudioFlatButtonChrome.verticalPadding(size: size))
            .background(
                StudioFlatButtonChrome.fill(role: role, isEnabled: isEnabled),
                in: RoundedRectangle(cornerRadius: StudioRadius.control)
            )
            .overlay {
                if overlayOpacity > 0 {
                    RoundedRectangle(cornerRadius: StudioRadius.control)
                        .fill(Color.primary.opacity(overlayOpacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: StudioRadius.control))
            .onHover { isHovered = $0 }
    }
}

struct StudioLinkButtonStyle: ButtonStyle {
    var linkStyle: StudioHoverLinkStyle

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let state = StudioInteractionState.from(
            isPressed: configuration.isPressed,
            isHovered: isEnabled && isHovered
        )
        configuration.label
            .foregroundStyle(StudioLinkForeground.resolve(style: linkStyle, state: state))
            .onHover { isHovered = $0 }
    }
}

struct StudioIconButtonStyle: ButtonStyle {
    var tint: Color?

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let state: StudioInteractionState = {
            guard isEnabled else { return .idle }
            return StudioInteractionState.from(
                isPressed: configuration.isPressed,
                isHovered: isHovered
            )
        }()
        configuration.label
            .foregroundStyle(StudioIconForeground.resolve(tint: tint, state: state))
            .onHover { isHovered = $0 }
    }
}

struct StudioSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var expands: Bool

    @State private var isHovered = false

    private var cornerRadius: CGFloat {
        expands ? StudioRadius.row : StudioRadius.small
    }

    func makeBody(configuration: Configuration) -> some View {
        let state = StudioInteractionState.from(
            isPressed: configuration.isPressed,
            isHovered: isHovered
        )
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(segmentBackground(state: state))
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onHover { isHovered = $0 }
    }

    private func segmentBackground(state: StudioInteractionState) -> Color {
        if isSelected {
            return StudioColors.brand.opacity(0.16)
        }
        switch state {
        case .idle: return .clear
        case .hovered: return StudioColors.hoverFill
        case .pressed: return Color.primary.opacity(0.08)
        }
    }
}

private struct StudioDefaultActionModifier: ViewModifier {
    var isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.keyboardShortcut(.defaultAction)
        } else {
            content
        }
    }
}

/// Plain text/icon action — accent, secondary, or quiet. Replaces one-off `.buttonStyle(.plain)` links.
struct StudioPlainLinkButton: View {
    enum Role {
        case accent
        case secondary
        case quiet
    }

    let title: String
    var systemImage: String?
    var role: Role = .accent
    var font: Font = StudioTypography.caption
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(font)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StudioLinkButtonStyle(linkStyle: hoverLinkStyle))
        .help(help)
    }

    private var hoverLinkStyle: StudioHoverLinkStyle {
        switch role {
        case .accent: .accent
        case .secondary: .secondary
        case .quiet: .secondary
        }
    }
}

/// Segmented scope control (Instances | Names, Project | Instance, footer mode).
/// Selected = accent fill; no outline. Place inside a `surfaceInset` tray at the call site when needed.
struct StudioSegmentButton: View {
    let title: String
    var isSelected: Bool = false
    var expands: Bool = false
    var font: Font = StudioTypography.meta
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? StudioColors.brand : Color.primary.opacity(0.78))
                .frame(maxWidth: expands ? .infinity : nil)
                .padding(.horizontal, expands ? 0 : StudioSpacing.panelHorizontal)
                .padding(.vertical, expands ? StudioSpacing.panelVertical : StudioSpacing.tightGap)
        }
        .buttonStyle(StudioSegmentButtonStyle(isSelected: isSelected, expands: expands))
        .help(help)
    }
}

// MARK: - Row chrome

enum StudioRowChrome {
    static func fill(isSelected: Bool, isHovered: Bool, isWarning: Bool) -> Color {
        if isWarning {
            return isHovered ? StudioColors.warningFillHover : StudioColors.warningFill
        }
        if isSelected {
            return StudioColors.selectionFill
        }
        if isHovered {
            return StudioColors.hoverFill
        }
        return .clear
    }
}

struct StudioDirtyDot: View {
    var body: some View {
        Circle()
            .fill(StudioColors.brand)
            .frame(width: StudioFieldMetrics.dirtyDotSize, height: StudioFieldMetrics.dirtyDotSize)
            .frame(width: StudioFieldMetrics.statusBadgeSlot, height: StudioFieldMetrics.statusBadgeSlot)
    }
}

/// Master-font star. Shares `statusBadgeSlot` with `StudioDirtyDot` so the pair
/// centers on the same axis when adjacent in a chip/row.
struct StudioMasterStar: View {
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: StudioFieldMetrics.masterStarPointSize))
            .foregroundStyle(StudioColors.brand)
            // `star.fill` sits optically low in its glyph box relative to a true
            // circle; nudge so it shares a visual center with StudioDirtyDot.
            .offset(y: -1)
            .frame(width: StudioFieldMetrics.statusBadgeSlot, height: StudioFieldMetrics.statusBadgeSlot)
    }
}

struct StudioRowBackground: View {
    let isSelected: Bool
    let isHovered: Bool
    var isWarning: Bool = false
    var selectionStyle: StudioRowSelectionStyle = .fillOnly

    var body: some View {
        RoundedRectangle(cornerRadius: StudioRadius.row)
            .fill(StudioRowChrome.fill(
                isSelected: isSelected,
                isHovered: isHovered,
                isWarning: isWarning
            ))
            .overlay {
                if isSelected && selectionStyle == .fillAndStroke && !isWarning {
                    RoundedRectangle(cornerRadius: StudioRadius.row)
                        .strokeBorder(StudioColors.selectionStroke, lineWidth: 0.5)
                }
            }
    }
}

// MARK: - View helpers

extension View {
    func studioPanelPadding() -> some View {
        padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, StudioSpacing.panelVertical)
    }

    func studioRowInsets() -> some View {
        padding(.horizontal, StudioSpacing.rowHorizontal)
            .padding(.vertical, StudioSpacing.instanceRowVertical)
    }

    func studioCompactControl() -> some View {
        font(StudioTypography.caption)
            .controlSize(.small)
    }
}

// MARK: - Inspector components

struct StudioInspectorConflictBadge: View {
    let count: Int
    var action: (() -> Void)?

    var body: some View {
        let label = Text("\(count) conflict\(count == 1 ? "" : "s")")
            .font(StudioTypography.meta.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(StudioColors.warningFill, in: Capsule())

        if let action {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .capsule)
                .help("Show conflict details")
        } else {
            label
        }
    }
}

/// Simple warning caption row for lists (Save Review warnings, etc.).
struct StudioWarningMessage: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(StudioTypography.meta)
                .foregroundStyle(StudioColors.warningForeground)
            Text(message)
                .font(StudioTypography.caption)
                .foregroundStyle(.primary)
        }
    }
}

struct StudioConflictAlert: View {
    let message: String
    var actionTitle: String = "Resolve…"
    let action: () -> Void

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(StudioTypography.meta)
                .foregroundStyle(StudioColors.warningForeground)

            Text(message)
                .font(StudioTypography.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 0)

            StudioFlatButton(
                title: actionTitle,
                size: .compact,
                action: action
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioColors.warningFill, in: RoundedRectangle(cornerRadius: StudioRadius.row))
    }
}

struct StudioComposedNameCallout: View {
    let name: String
    var isDuplicate: Bool = false

    var body: some View {
        Text(name)
            .font(.system(size: 15, weight: .semibold))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isDuplicate ? StudioColors.warningFill : StudioColors.selectionFill.opacity(0.35),
                in: RoundedRectangle(cornerRadius: StudioRadius.row)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isDuplicate ? StudioColors.warningForeground : StudioColors.brand)
                    .frame(width: 3)
            }
    }
}

struct StudioInstanceComposedName: View {
    let links: [NamingChainLink]
    let fallback: String
    var included: Bool = true
    var hideElided: Bool = false

    private var displayLinks: [NamingChainLink] {
        hideElided ? links.filter { !$0.elided } : links
    }

    private var showsCollapsedElidedFallback: Bool {
        hideElided && !links.isEmpty && displayLinks.isEmpty
    }

    var body: some View {
        Group {
            if links.isEmpty {
                Text(fallback)
                    .foregroundStyle(included ? .primary : .secondary)
            } else if showsCollapsedElidedFallback {
                Text(fallback)
                    .foregroundStyle(included ? .primary : .secondary)
            } else {
                composedText(from: displayLinks)
            }
        }
        .font(StudioTypography.bodyMedium)
        .lineLimit(1)
        .help(showsCollapsedElidedFallback ? "Elided fallback — all elidable segments hidden" : "")
    }

    private func composedText(from segments: [NamingChainLink]) -> Text {
        segments.enumerated().reduce(Text("")) { partial, item in
            let (index, link) = item
            var result = partial
            if index > 0 {
                result = result + Text(" ")
            }
            var segment = Text(link.name)
                .foregroundStyle(segmentColor(for: link))
            if link.elided {
                segment = segment.strikethrough(true, color: .secondary)
            }
            return result + segment
        }
    }

    private func segmentColor(for link: NamingChainLink) -> Color {
        if link.elided { return Color.secondary.opacity(0.55) }
        return included ? Color.primary : Color.secondary
    }
}

struct InspectorInstanceNamingChain: View {
    let links: [NamingChainLink]
    var onLinkTap: ((String) -> Void)?

    var body: some View {
        if links.isEmpty {
            Text("No naming chain entries")
                .font(StudioTypography.caption)
                .foregroundStyle(.tertiary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                        if index > 0 {
                            namingArrow
                        }
                        namingSegment(link)
                    }
                }
            }
        }
    }

    private var namingArrow: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(StudioColors.brand.opacity(0.3))
                .frame(width: 8, height: 1.5)
            Image(systemName: "chevron.right")
                .font(.system(size: 7, weight: .light))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func namingSegment(_ link: NamingChainLink) -> some View {
        Group {
            if link.kind == .clarifier {
                HStack(spacing: 5) {
                    StudioClarifierPill(
                        label: link.name,
                        showCategory: NamingToken.clarifierDisplayName[link.tag] ?? link.tag,
                        compact: true
                    )
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else if link.kind == .code {
                Text(link.name)
                    .font(StudioTypography.monoMeta.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(StudioColors.codeBackground, in: RoundedRectangle(cornerRadius: StudioRadius.chip))
            } else if link.kind == .compound {
                HStack(spacing: 5) {
                    Text("F4")
                        .font(StudioTypography.meta.weight(.semibold))
                        .foregroundStyle(StudioColors.statFormat1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(StudioColors.statFormat1.opacity(0.16), in: Capsule())
                    Text(link.tag)
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.secondary)
                        .opacity(link.elided ? 0.55 : 1)
                    Text(link.name)
                        .font(StudioTypography.bodyMedium)
                        .foregroundStyle(segmentForeground(for: link))
                        .strikethrough(link.elided, color: Color.secondary.opacity(0.45))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else {
                Button {
                    onLinkTap?(link.tag)
                } label: {
                    HStack(spacing: 5) {
                        StudioTagPill(
                            text: link.tag,
                            compact: true,
                            role: link.kind == .registration ? .registration : .instance
                        )
                            .opacity(link.elided ? 0.55 : 1)

                        Text(link.name)
                            .font(StudioTypography.bodyMedium)
                            .foregroundStyle(segmentForeground(for: link))
                            .strikethrough(link.elided, color: Color.secondary.opacity(0.45))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.chip), isEnabled: onLinkTap != nil)
            }
        }
    }

    private func segmentForeground(for link: NamingChainLink) -> Color {
        link.elided ? Color.secondary.opacity(0.55) : Color.primary
    }
}

/// Inspector axis-coordinate list columns (on-lattice).
/// `elisionWidth` fits the spelled-out “Elidable” header — wider than stop-table “Elided”.
enum InspectorAxisCoordLayout {
    static let badgeWidth: CGFloat = 34
    static let chainWidth: CGFloat = StudioSpace.x3 // 12
    static let valueWidth: CGFloat = 44
    static let elisionWidth: CGFloat = 52
}

struct InspectorAxisCoordinatesView: View {
    let rows: [InspectorAxisCoordRow]
    var selectedStopID: String?
    var onRowTap: ((InspectorAxisCoordRow) -> Void)?
    var onElisionToggle: ((InspectorAxisCoordRow) -> Void)?

    private var showsElisionColumn: Bool {
        rows.contains(where: \.showsElisionToggle)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                axisCoordRow(
                    row,
                    isFirst: index == 0,
                    isLast: index == rows.count - 1,
                    linkActiveToNext: chainLinkActive(at: index)
                )
            }
        }
    }

    private func chainLinkActive(at index: Int) -> Bool {
        guard index + 1 < rows.count else { return false }
        return rows[index].participatesInNaming && rows[index + 1].participatesInNaming
    }

    private func axisCoordRow(
        _ row: InspectorAxisCoordRow,
        isFirst: Bool,
        isLast: Bool,
        linkActiveToNext: Bool
    ) -> some View {
        InspectorAxisCoordRowView(
            row: row,
            isFirst: isFirst,
            isLast: isLast,
            linkActiveToNext: linkActiveToNext,
            isSelected: row.stopID == selectedStopID,
            showsElisionColumn: showsElisionColumn,
            onRowTap: onRowTap,
            onElisionToggle: onElisionToggle
        )
    }
}

private struct InspectorAxisCoordRowView: View {
    let row: InspectorAxisCoordRow
    let isFirst: Bool
    let isLast: Bool
    let linkActiveToNext: Bool
    let isSelected: Bool
    let showsElisionColumn: Bool
    var onRowTap: ((InspectorAxisCoordRow) -> Void)?
    var onElisionToggle: ((InspectorAxisCoordRow) -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            Button {
                onRowTap?(row)
            } label: {
                HStack(spacing: StudioSpacing.controlGap) {
                    chainRail
                        .frame(width: InspectorAxisCoordLayout.chainWidth)

                    StudioAxisValueLabel(
                        text: StudioFormatting.axisValue(row.value),
                        muted: !row.participatesInNaming
                    )
                    .frame(width: InspectorAxisCoordLayout.valueWidth, alignment: .trailing)

                    StudioTagPill(text: row.tag, compact: true)
                        .opacity(row.participatesInNaming ? 1 : 0.5)
                        .frame(width: InspectorAxisCoordLayout.badgeWidth, alignment: .center)

                    Text(row.stopName)
                        .font(StudioTypography.body)
                        .foregroundStyle(nameColor)
                        .strikethrough(row.isElided, color: Color.secondary.opacity(0.45))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 4)
                .frame(minHeight: StudioFieldMetrics.listRowMinHeight)
                .background {
                    StudioRowBackground(
                        isSelected: isSelected,
                        isHovered: isHovered && !isSelected
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(onRowTap == nil || row.stopID == nil)
            .onHover { isHovered = $0 }

            if showsElisionColumn {
                Group {
                    if row.showsElisionToggle {
                        StudioElidableRadio(isOn: row.isElided) {
                            onElisionToggle?(row)
                        }
                    }
                }
                .frame(width: InspectorAxisCoordLayout.elisionWidth, alignment: .center)
            }
        }
        .help(row.participatesInNaming
            ? (row.isElided ? "Elided from composed name — focus axis stop" : "Focus this axis stop")
            : "Not in the instance naming grid")
    }

    private var nameColor: Color {
        if !row.participatesInNaming { return Color.secondary }
        if row.isElided { return Color.secondary.opacity(0.55) }
        return Color.primary
    }

    @ViewBuilder
    private var chainRail: some View {
        let dotColor: Color = {
            if isSelected { return StudioColors.brand }
            if row.participatesInNaming && !row.isElided { return StudioColors.registrationForeground }
            if row.isElided { return .secondary.opacity(0.35) }
            return .secondary.opacity(0.25)
        }()

        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .frame(height: 6)
            }

            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)

            if !isLast {
                Rectangle()
                    .fill(linkActiveToNext ? StudioColors.brand.opacity(0.3) : Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

struct InspectorOpenTypeSourcePill: View {
    let source: InspectorOpenTypeSource

    var body: some View {
        Text(source.rawValue)
            .font(StudioTypography.meta)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: StudioRadius.small))
    }
}

struct InspectorOpenTypeTable: View {
    let rows: [InspectorOpenTypeRow]

    private let tableWidth: CGFloat = 52
    private let fieldWidth: CGFloat = 108

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: StudioSpacing.controlGap) {
                Text("Table")
                    .frame(width: tableWidth, alignment: .leading)
                Text("Field")
                    .frame(width: fieldWidth, alignment: .leading)
                Text("Content")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(StudioTypography.columnLabel)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 4)

            ForEach(rows) { row in
                HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                    Text(row.table)
                        .font(StudioTypography.monoMeta)
                        .frame(width: tableWidth, alignment: .leading)
                    Text(row.field)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: fieldWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.content)
                            .font(row.isDerived ? StudioTypography.caption : StudioTypography.body)
                            .foregroundStyle(row.isDerived ? .tertiary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !row.sources.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(row.sources, id: \.rawValue) { source in
                                    InspectorOpenTypeSourcePill(source: source)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
    }
}
