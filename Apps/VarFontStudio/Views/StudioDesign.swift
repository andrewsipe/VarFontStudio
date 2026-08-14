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
    /// Naming-chain connector (`arrowshape.right.fill`) between chips.
    static let chainArrow = Font.system(size: 8, weight: .semibold)
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
    /// Standard horizontal content inset for panels, sheets, cards, and chrome rails.
    /// Symmetric left/right — trailing space includes macOS overlay scrollbar clearance.
    /// Formerly `panelHorizontal` / sheet/card/list inset aliases (all the same 12pt rail).
    static let contentInset: CGFloat = StudioSpace.x3
    static let panelVertical: CGFloat = StudioSpace.x1_5
    static let rowHorizontal: CGFloat = StudioSpace.x1_5
    static let rowVertical: CGFloat = StudioSpace.x0_5
    static let rowGap: CGFloat = StudioSpace.x1_5
    /// Tight inter-element gap inside chips / compact tool clusters.
    static let tightGap: CGFloat = StudioSpace.x1
    static let controlGap: CGFloat = StudioSpace.x2
    /// Section-level rhythm between axis blocks / grouped sections — independent of row density.
    static let sectionGap: CGFloat = StudioSpace.x2_5
    /// Root spacing in stacked editor sheets — slightly looser than `sectionGap` for dense multi-section layouts.
    static let sheetSectionSpacing: CGFloat = StudioSpace.x3_5
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


/// Shared row-density tiers. Axis Tree headers use `standard`; Instances rows and
/// Axis Tree stop-detail rows use `compact`. Section openness is controlled by
/// `StudioSpacing.sectionGap`, not a third row tier.
enum StudioDensity {
    static let standard = (
        rowVertical: StudioSpacing.rowVertical,
        rowGap: StudioSpacing.rowGap,
        rowHorizontal: StudioSpacing.rowHorizontal
    )
    static let compact = (
        rowVertical: StudioSpacing.instanceRowVertical,
        rowGap: StudioSpacing.instanceRowGap
    )
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

/// Dashed reorder ring — Axis Tree headers, Naming Order chips, drop targets.
enum StudioDragOutline {
    /// Default gap (Naming Order chips) — uniform on all sides.
    static let outset: CGFloat = StudioSpace.x1 // 4
    /// Axis Tree headers need a wider horizontal breath than vertical.
    static let axisTreeOutsetHorizontal: CGFloat = StudioSpace.x2 // 8
    static let axisTreeOutsetVertical: CGFloat = outset // 4
    /// Matches the control nest anchor (buttons / fields).
    static let cornerRadius: CGFloat = StudioRadius.control

    /// Expanded dashed ring (hover affordance, source placeholder, floating ghost).
    static func expandedRing(
        color: Color = Color.secondary.opacity(0.4),
        lineWidth: CGFloat = StudioStroke.regular,
        horizontalOutset: CGFloat = outset,
        verticalOutset: CGFloat = outset
    ) -> some View {
        RoundedRectangle.studio(cornerRadius)
            .strokeBorder(
                color,
                style: StrokeStyle(lineWidth: lineWidth, dash: StudioStroke.dragDash)
            )
            .padding(.horizontal, -horizontalOutset)
            .padding(.vertical, -verticalOutset)
            .allowsHitTesting(false)
    }

    /// Axis Tree preset — 8pt horizontal / 4pt vertical.
    static func axisTreeRing(
        color: Color = Color.secondary.opacity(0.4),
        lineWidth: CGFloat = StudioStroke.regular
    ) -> some View {
        expandedRing(
            color: color,
            lineWidth: lineWidth,
            horizontalOutset: axisTreeOutsetHorizontal,
            verticalOutset: axisTreeOutsetVertical
        )
    }
}

/// Concentric corner scale. Nesting rule: outer ≈ inner + the padding at that boundary.
/// Anchor at `control` (buttons/fields); derive larger tokens for padded cards / panels.
enum StudioRadius {
    /// Hairline gutter stripes / checkbox ticks — not part of the nest ladder.
    static let hairline: CGFloat = StudioSpace.x0_5 // 2
    /// Micro marks / compact segment corners (off-lattice).
    static let small: CGFloat = 3
    /// Pills, badges, naming chips.
    static let chip: CGFloat = StudioSpace.x1 // 4
    /// Buttons, fields, drag rings — nest anchor.
    static let control: CGFloat = StudioSpace.x1_5 // 6
    /// Padded inset cards / warning banners (≈ control + typical content padding).
    static let surface: CGFloat = StudioSpace.x2_5 // 10
    /// Sheet / large panel chrome nesting a surface-level card.
    static let panel: CGFloat = StudioSpace.x4 // 16
}

extension RoundedRectangle {
    /// Studio default curve — continuous (squircle), matching system chrome.
    static func studio(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
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
/// - Inspector key/value and OpenType tables live in `InspectorComponents.swift`.
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
///   renders the system menu chevron. Neutral idle/hover (not brand) — overrides
///   app `studioBrandTint()` with an explicit `.tint`.
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
/// - Column / panel layout enums (`StopTableLayout`, `AxisBlockLayout`, `SaveReviewLayout` in StudioSharedLayouts,
///   `FillStopPreviewLayout`, `NameTableLayout`, `InspectorAxisCoordLayout`, …) are
///   local track contracts — not part of the spacing lattice. Stop-style tables (Axis Tree,
///   conflict resolver, combination styles) share `StopTableLayout`.
///
/// ## Container horizontal inset
/// - `StudioSpacing.contentInset` (12pt) — every panel, sheet, window, and chrome band.
///   Trailing inset includes macOS overlay scrollbar clearance; never add extra scroll gutter.
///   Sheet outer, card, list, and chrome call sites all use this single rail (aliases removed).
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
    static func resolve(tint: Color?, state: StudioInteractionState, onAccent: Bool = false) -> Color {
        if onAccent {
            // White chrome on `brandSecondaryFill` — brand/secondary blues wash out there.
            switch state {
            case .idle: return Color.white.opacity(0.88)
            case .hovered, .pressed: return .white
            }
        }
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
// 1. **Brand** (`brand`, `brandSecondaryFill`) — CTA fill, selected tab/segment
//    chrome, app tint. **Metrics / small marks on neutrals** use `metricForeground`
//    (sky family) so dark-mode digits don’t vibrate against charcoal.
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
// `brand` / selection / metric are Tailwind single family, solid steps.
// Never bake `brand@opacity` over charcoal for area fills (composites to teal/indigo).
//
// ## Chromatic palette (decided)
// `StudioPalette` is Tailwind CSS v4 chromatic families (sRGB hex from official OKLCH).
// Semantic roles on `StudioColors` pick light/dark steps. Neutrals stay Apple system
// + `StudioPrimaryWash` / opaque panel washes — not slate/zinc.
//
// ## Migration phases
// - **Phase 1** (this document) — lock rules; no visual changes.
// - **Phase 2** — high-traffic tables: Review values, axis value column, Instancer
//   flags; `axisValue` / `diffRenamed` → mark hues only. **Done**.
// - **Phase 3** — pills, naming footer, remaining sheets; lint checks. **Done**.
// - **Phase 4** — audit polish: no unconditional value dots; semantic fill scale;
//   link idle neutral; Instancer leading stripe; token disambiguation. **Done**.
//
// ## Phase 4 punch list (post-audit)
// 1. Axis value dot — conditional only (`showMark` default false); column TBD.
// 2. Opaque area fills — semantic / selection / hover *Fill tokens bake alpha over
//    the window background (`StudioOpaqueFill` / `StudioOpaquePanelWash`). Opacity
//    remains for edges only (*Stroke, dividers, drag tints, focus rings). Neutral
//    panel chrome (`surface*`, field fills) stays translucent/adaptive.
// 3. Links — `.accent` idle `.primary`, brand on hover/press.
// 4. Instancer — `StudioSemanticLeadingStripe`, not gradient fade.
// 5. Tokens — `diffProtected` brand; `diffRenamed` orange; STAT rose ramp.
//
// ## Token audit rule
// Same hue = same meaning everywhere, or split the token. Category labels must not
// borrow status hues (success green, edited teal, warning amber marks / yellow
// containers). Protected IDs use brand — Studio-owned, not a write.
//
private enum StudioPrimaryWash {
    static func make(name: String, light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.PrimaryWash.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor.labelColor.withAlphaComponent(isDark ? dark : light)
        }))
    }
}

/// Shared src-over bake used by opaque fill / panel-wash tokens.
private enum StudioColorComposite {
    static func composite(_ src: NSColor, over dst: NSColor) -> NSColor? {
        guard let s = src.usingColorSpace(.sRGB),
              let d = dst.usingColorSpace(.sRGB) else { return nil }
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        s.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        d.getRed(&dr, green: &dg, blue: &db, alpha: &da)
        return NSColor(
            srgbRed: sr * sa + dr * (1 - sa),
            green: sg * sa + dg * (1 - sa),
            blue: sb * sa + db * (1 - sa),
            alpha: 1
        )
    }
}

/// Opaque color that matches a `StudioPrimaryWash` composited over the window
/// background. Use for neutral text tokens and under translucent chip fills so
/// row selection/hover cannot show through (washes alone are translucent and
/// will pick up whatever is behind).
private enum StudioOpaquePanelWash {
    static func make(name: String, light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.OpaquePanelWash.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let alpha = isDark ? dark : light
            var result: NSColor = .windowBackgroundColor
            appearance.performAsCurrentDrawingAppearance {
                let base = NSColor.windowBackgroundColor
                let wash = NSColor.labelColor.withAlphaComponent(alpha)
                result = StudioColorComposite.composite(wash, over: base) ?? base
            }
            return result
        }))
    }
}

/// Opaque color that matches a hued wash composited over the window background.
/// Use for semantic / selection area fills so translucent surfaces beneath cannot
/// bleed through and muddy the tint. Keep `.opacity()` for edges (`*Stroke`,
/// dividers, drag tints) — not for fills.
private enum StudioOpaqueFill {
    static func make(name: String, hue: Color, light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.OpaqueFill.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let alpha = isDark ? dark : light
            var result: NSColor = .windowBackgroundColor
            appearance.performAsCurrentDrawingAppearance {
                let base = NSColor.windowBackgroundColor
                let wash = NSColor(hue).withAlphaComponent(alpha)
                result = StudioColorComposite.composite(wash, over: base) ?? base
            }
            return result
        }))
    }
}

/// Dynamic color built from two independently-authored sRGB stops rather than one fixed
/// RGB value + system opacity. Use for any custom (non-system) semantic hue that appears
/// as `Text` foreground, where light/dark need separately verified contrast — not just for
/// marks, which can tolerate a single value under `StudioPrimaryWash`-style opacity.
private enum StudioHuedToken {
    static func make(
        name: String,
        light: (r: Double, g: Double, b: Double),
        dark: (r: Double, g: Double, b: Double)
    ) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.Hued.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let stop = isDark ? dark : light
            return NSColor(srgbRed: stop.r, green: stop.g, blue: stop.b, alpha: 1)
        }))
    }
}

/// Semantic color tokens. See **Color system (semantic marks)** above for usage rules.
///
/// Naming note: `*Foreground` tokens name the canonical **hue** for a semantic.
/// After migration they are for marks (icons, gutters, dots, badge strokes) — not
/// for `Text` body copy. Pair with `*Fill` / `*Stroke` at call sites.
enum StudioColors {
    /// Opaque composite over the window background for an arbitrary hue — the same
    /// bake `successFill`/`warningFill`-style tokens use, exposed for call sites that
    /// pick their tint dynamically (e.g. a per-row accent) and can't predeclare a
    /// named token. Prefer `.opacity()` only for edges/strokes, never for area fills.
    static func opaqueFill(_ hue: Color, light: CGFloat, dark: CGFloat) -> Color {
        StudioOpaqueFill.make(name: "adhoc.\(UUID().uuidString)", hue: hue, light: light, dark: dark)
    }

    // MARK: Brand & interaction
    //
    // One Tailwind family — solid steps only for area fills. Baking
    // `brand@0.16` over charcoal used to composite to ~`#1B303F` (indigo/teal);
    // solid `blue-100`/`blue-900` keeps the same hue as the Export CTA.

    /// Tier 1 — mark hue + primary CTA fill (Export, Include checkbox fill, tab underline).
    /// Light/dark both `600` so white button labels clear ~5:1 AA.
    static let brand = StudioPalette.color(.blue, light: .s600, dark: .s600)
    /// Soft brand wash — reserved for rare tinted chrome (not selected tabs/rows).
    /// Prefer `brandSecondaryFill` (tabs/segments) or `selectionNeutralFill*` (list rows).
    /// Dark `950` + sky labels was the sky-on-navy failure mode — do not pair with
    /// `metricForeground` for selected control labels.
    static let selectionFill = StudioPalette.color(.blue, light: .s300, dark: .s950)
    /// Quieter brand wash — soft highlights only (one step under `selectionFill` in light).
    static let selectionFillSoft = StudioPalette.color(.blue, light: .s200, dark: .s900)
    /// Checkbox-list row selection (Instancer). Brand baked over the window —
    /// not a solid `blue-900` step, which reads as a full-row blue blast.
    static let selectionRowFill = StudioOpaqueFill.make(name: "selectionRowFill", hue: brand, light: 0.10, dark: 0.16)
    static let selectionRowFillHover = StudioOpaqueFill.make(name: "selectionRowFillHover", hue: brand, light: 0.14, dark: 0.22)
    /// Secondary selected control fill — tabs / segments. Mid blue + white (or `.primary`)
    /// labels — not navy fill with sky text. Sits under primary CTA `brand` (600).
    static let brandSecondaryFill = StudioPalette.color(.blue, light: .s500, dark: .s700)
    /// Legacy alias — prefer `brandSecondaryFill` or semantic source fills (`fvarBackground`).
    static let brandBackground = brandSecondaryFill
    /// Disabled primary button fill (was `brand.opacity(0.22)`).
    static let brandFillDisabled = StudioPalette.color(.blue, light: .s100, dark: .s800)
    /// Selection / focus ring edge — opacity OK (edge, not area fill).
    static let selectionStroke = brand.opacity(0.35)
    /// AppKit bridge for caret/selection styling in `StudioTextField`.
    static var brandNSColor: NSColor { NSColor(brand) }

    // MARK: Neutral tags

    /// Instance axis tag pills — readable on `tagBackground`. System `.secondary` was
    /// too faint on the light wash (especially `ousd`/`insd` mono labels).
    static let tagForeground = StudioOpaquePanelWash.make(name: "tagForeground", light: 0.62, dark: 0.72)
    static let tagBackground = StudioOpaqueFill.make(name: "tagBackground", hue: .secondary, light: 0.14, dark: 0.16)
    /// Truly opaque backdrop under translucent chip washes. Bakes `surfaceMuted`
    /// over the window background — `surfaceMuted` itself is a translucent wash,
    /// so using it alone still let selection/hover bleed through the pills.
    static let chipSurface = StudioOpaquePanelWash.make(name: "chipSurface", light: 0.07, dark: 0.04)
    /// Punch-out label on Review chips — window/panel background, so dark charcoal
    /// in dark mode and paper-light in light mode (the reverse of `.primary`).
    static let chipLabel = Color(nsColor: .windowBackgroundColor)

    // MARK: Semantic marks — axis & instancer

    /// **Mark hue** — axis value column (dot / column accent). Not for value digits.
    static let axisValue = StudioPalette.color(.orange, light: .s600, dark: .s400)

    // MARK: Selection & hover (neutral washes; brand selection is `selectionFill` above)

    /// Neutral (non-accent) selection / hover-over-selection fills — not for borders.
    static let selectionNeutralFill = StudioOpaquePanelWash.make(name: "selectionNeutralFill", light: 0.11, dark: 0.08)
    static let selectionNeutralFillStrong = StudioOpaquePanelWash.make(name: "selectionNeutralFillStrong", light: 0.15, dark: 0.12)
    static let hoverFill = StudioOpaquePanelWash.make(name: "hoverFill", light: 0.08, dark: 0.05)

    // MARK: Canvas (font preview only — see color system guidance)

    /// Fixed paper-white glyph preview — font preview panel only (not Review/Instancer tables).
    ///static let paper = StudioHuedToken.make(
    ///name: "paper", light: (1.0, 0.992, 0.976), dark: (0.937, 0.914, 0.867)
    ///)
    
    ///static let ink = StudioHuedToken.make(
    ///name: "ink", light: (0.129, 0.114, 0.086), dark: (0.110, 0.094, 0.067)
    ///)
    static let canvasBackground = StudioPalette.color(.paper, light: .s100, dark: .s200)
    /// Ink on the font preview canvas — always black regardless of system appearance.
    static let canvasForeground = StudioPalette.color(.ink, light: .s800, dark: .s950)
    static let canvasSecondary = StudioPalette.color(.ink, step: .s600)//.opacity(0.55)
    static let canvasTertiary = StudioPalette.color(.ink, step: .s400)//.opacity(0.38)
    static let canvasQuaternary = StudioPalette.color(.ink, step: .s200)//.opacity(0.22)
    static let canvasDivider = StudioPalette.color(.ink, step: .s100)//.opacity(0.10)
    /// Status strip on the font preview panel — paper chrome (canvas is always light).
    static let canvasPhaseHeader = StudioPalette.color(.paper, step: .s200)
    /// Soft wash on paper canvas / status (always light blue-100 — never dark-mode
    /// `selectionFillSoft`, which goes navy and fails ink contrast on the paper strip).
    static let canvasHoverFill = StudioPalette.color(.blue, step: .s100)
    /// Peek-mode pill label on `canvasHoverFill` — blue-800 clears strongly on blue-100.
    static let canvasPeekForeground = StudioPalette.color(.blue, step: .s800)

    // MARK: Semantic marks — status (warning / success / error)
    //
    // Warning chrome splits two Tailwind families so marks stay prominent on the fill:
    //   **yellow** — conflict/issue containers AND Review CTA chip fills
    //   **amber**  — warning triangles / strokes (marks only)
    // Hierarchy:
    //   warningFillStrong  — summary header strip (“N issues to review”)
    //   warningFill        — detail body / standalone banners
    //   warningFillHover   — yellow CTA chips on yellow containers

    /// Soft yellow conflict-container wash (Issues detail body, alerts, row tint).
    /// Light: 200 (up from pale 100). Dark: mid gold 500 — not 700–900 (those read
    /// muddy mustard on charcoal). Body copy on these fills uses `warningOnFillForeground`.
    static let warningFill = StudioPalette.color(.yellow, light: .s200, dark: .s300)
    /// Deeper yellow for the Issues-band summary strip — separates “N issues” from
    /// the specific warning rows below without a second card.
    static let warningFillStrong = StudioPalette.color(.yellow, light: .s300, dark: .s400)
    /// Yellow CTA chip on yellow (or neutral) chrome — Review / Resolve buttons.
    /// Light/dark steps sit above the container wash so the chip still reads as a control.
    static let warningFillHover = StudioPalette.color(.yellow, light: .s400, dark: .s500)
    /// Label on warning CTA chips. Dark ink — system `.primary` (white in dark mode)
    /// fails AA on bright yellow CTAs; ink holds 5:1+ in both appearances.
    static let warningButtonForeground = StudioPalette.color(.stone, light: .s900, dark: .s950)
    /// Body / caption text sitting on `warningFill` / `warningFillStrong`. Same ink as
    /// CTA labels — white `.primary` fails on mid yellows in dark mode.
    static let warningOnFillForeground = StudioPalette.color(.stone, light: .s700, dark: .s800)
    /// Mark hue — warning icons / triangles, gutter accents, flag symbols. Amber so
    /// it stays readable on yellow containers and pops on neutral chrome. Darker steps
    /// than the CTA chip so triangles clear the gold wash (~3:1+).
    static let warningForeground = StudioPalette.color(.amber, light: .s600, dark: .s600)
    static let warningStroke = warningForeground.opacity(0.45)
    /// Soft/unselected variant of `warningFill` — baked opaque composite, not
    /// `warningFill.opacity()`. `warningFill` is already a solid Tailwind step, so
    /// layering `.opacity()` on top reintroduces translucency and lets the surface
    /// behind (often a vibrant/blurred material) mute the yellow.
    static let warningFillSoft = StudioOpaqueFill.make(name: "warningFillSoft", hue: warningFill, light: 0.35, dark: 0.35)
    static let successFill = StudioOpaqueFill.make(
        name: "successFill",
        hue: StudioPalette.color(.green, light: .s500, dark: .s400),
        light: 0.22,
        dark: 0.22
    )
    static let successStroke = StudioPalette.color(.green, light: .s600, dark: .s400).opacity(0.45)
    /// Mark hue — success icons. Do not use as standalone text/foreground color on a
    /// matching-hue fill — pair with `.primary`/`.secondary` text and reserve the hue
    /// for the icon/mark/stroke. Include-checkbox marks use `metricForeground` (sky).
    static let successForeground = StudioPalette.color(.green, light: .s600, dark: .s400)
    /// Mark hue — error icons, severe collision flags, destructive emphasis. Same pairing
    /// rule as `successForeground`: text stays neutral, hue lives on the mark.
    static let errorForeground = StudioPalette.color(.red, light: .s600, dark: .s400)
    static let errorFill = StudioOpaqueFill.make(name: "errorFill", hue: errorForeground, light: 0.22, dark: 0.32)
    static let errorStroke = errorForeground.opacity(0.5)

    // MARK: Semantic marks — instancer row state

    /// Mark hue — name-only collision (distinct from amber fallback / red severe).
    /// Pink family primary mark steps (3:1 non-text).
    static let collisionForeground = StudioPalette.color(.pink, light: .s600, dark: .s300)
    static let collisionFill = StudioOpaqueFill.make(name: "collisionFill", hue: collisionForeground, light: 0.22, dark: 0.36)
    static let collisionStroke = collisionForeground.opacity(0.45)
    /// Mark hue — user-added custom instance row stripe / flag symbol.
    /// Indigo family (kept far from teal `editedForeground` and brand blue).
    static let customForeground = StudioPalette.color(.teal, light: .s500, dark: .s500)
    static let customFill = StudioOpaqueFill.make(name: "customFill", hue: customForeground, light: 0.28, dark: 0.52)
    /// Unselected / post-generate custom instance row — quieter than `customFill`
    /// so include-checkbox state is visible. Baked opaque, not `customFill.opacity()`.
    static let customFillSoft = StudioOpaqueFill.make(name: "customFillSoft", hue: customForeground, light: 0.10, dark: 0.18)
    /// Mark hue — edited-from-default name override (reserved; row stripe if needed).
    /// Teal family — do not reuse for pending export (see `pendingForeground`).
    static let editedForeground = StudioPalette.color(.teal, light: .s600, dark: .s300)
    static let editedFill = StudioOpaqueFill.make(name: "editedFill", hue: editedForeground, light: 0.24, dark: 0.24)
    /// Mark hue — pending export (Instances badge / filter). Emerald, unclaimed by
    /// edited-teal / success-green / code teal — so pending and edited can co-occur.
    /// Code uses a darker teal step (`codeForeground`) to stay distinct from edited.
    static let pendingForeground = StudioPalette.color(.emerald, light: .s600, dark: .s300)
    static let pendingFill = StudioOpaqueFill.make(name: "pendingFill", hue: pendingForeground, light: 0.24, dark: 0.24)

    // MARK: Semantic marks — Save Review diff
    //
    // Diff accents bind to Tailwind families. Protected IDs use brand (Studio-owned,
    // not a write). Renamed uses orange (informational); yellow is reserved for warning
    // containers.

    static let diffRemoved = StudioPalette.color(.red, light: .s500, dark: .s300)
    /// Green family — distinct from `codeForeground` (teal) and `pendingForeground` (emerald).
    static let diffAdded = StudioPalette.color(.green, light: .s600, dark: .s300)
    static let diffReflowed = StudioPalette.color(.violet, light: .s500, dark: .s300)
    /// Protected / read-only name IDs — brand, not slate, so they don’t read as SAME.
    static let diffProtected = brand
    /// Renamed/changed — informational orange (yellow is reserved for warning containers).
    static let diffRenamed = StudioPalette.color(.orange, light: .s600, dark: .s300)

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
    /// Opaque bake — translucent `labelColor@alpha` washed out over tinted fills.
    static let primaryMuted = StudioOpaquePanelWash.make(name: "primaryMuted", light: 0.88, dark: 0.85)
    /// Flat secondary action fill (Cancel, Generate All…, Add Instance…).
    static let buttonSecondaryFill = StudioPrimaryWash.make(name: "buttonSecondaryFill", light: 0.15, dark: 0.12)
    static let buttonSecondaryFillDisabled = StudioPrimaryWash.make(name: "buttonSecondaryFillDisabled", light: 0.07, dark: 0.05)
    /// Readable placeholder in fields and search — stronger than `.tertiary`, softer than `.primary`.
    static let textPlaceholder = StudioOpaquePanelWash.make(name: "textPlaceholder", light: 0.42, dark: 0.48)
    /// Muted-but-legible informational text (elided naming-chain links, non-participating axis
    /// coordinate rows, muted axis-value digits). ~3.5–4:1 against panel in both appearances —
    /// opaque bake rather than stacking `.opacity()` on system `.secondary`/`.tertiary`,
    /// which compounds their own built-in translucency into ~2:1 and washes out.
    static let mutedForeground = StudioOpaquePanelWash.make(name: "mutedForeground", light: 0.50, dark: 0.40)
    /// Section titles, phase headers, and column headers — readable at a glance without
    /// matching `.primary`'s weight. Verified ~4.8–5.2:1 against representative panel
    /// backgrounds in both appearances (plain system `.secondary` only clears ~3.95:1 in
    /// light mode, below the 4.5:1 AA floor this tier exists to guarantee). Opaque so it
    /// stays crisp over tinted banners and selection fills.
    static let sectionHeading = StudioOpaquePanelWash.make(name: "sectionHeading", light: 0.58, dark: 0.50)
    /// Opaque sticky-pin fill matching `surfaceMuted`'s wash strength. Pinned section
    /// headers (Save Review phases, Instancer groups) must fully cover scrolling rows —
    /// translucent `surfaceMuted` alone let content bleed through.
    static let stickyHeaderFill = StudioOpaquePanelWash.make(name: "stickyHeaderFill", light: 0.07, dark: 0.04)
    /// Scannable metric digits / small marks on neutral chrome (header counts,
    /// `StudioCountBadge`, include checkmarks, active sort headers).
    /// Tailwind **sky** — lighter than brand blue so dark-mode digits don’t vibrate
    /// against charcoal. Light `700` / dark `300`. CTAs stay on `brand` (blue-600).
    /// On `brandSecondaryFill` chips use on-accent white (`studioOnAccentFill`), not this.
    static let metricForeground = StudioPalette.color(.blue, light: .s700, dark: .s500)

    // MARK: Custom palette — registration & classification (dual-tone)

    /// Mark hue — design-record / PS / clarifier. fuchsia (Tailwind; was bespoke magenta).
    static let registrationForeground = StudioPalette.color(.fuchsia, light: .s600, dark: .s500)
    static let registrationBackground = StudioOpaqueFill.make(name: "registrationBackground", hue: registrationForeground, light: 0.22, dark: 0.22)
    static let registrationStroke = registrationForeground.opacity(0.40)
    /// Legacy clarifier alias — same fuchsia as registration.
    static let clarifierForeground = registrationForeground
    static let clarifierBackground = registrationBackground
    static let clarifierStroke = registrationStroke
    /// Mark hue — OpenType classification code chip. Teal (not emerald pending /
    /// not green diffAdded) so Code stays distinct from status and pending.
    static let codeForeground = StudioPalette.color(.teal, light: .s700, dark: .s400)
    static let codeBackground = StudioOpaqueFill.make(name: "codeBackground", hue: codeForeground, light: 0.22, dark: 0.22)
    static let codeStroke = codeForeground.opacity(0.45)
    /// Mark hue — OpenType `fvar` source chip. Cyan (not brand blue / not code teal).
    static let fvarForeground = StudioPalette.color(.cyan, light: .s600, dark: .s400)
    static let fvarBackground = StudioOpaqueFill.make(name: "fvarBackground", hue: fvarForeground, light: 0.22, dark: 0.22)
    static let fvarStroke = fvarForeground.opacity(0.45)

    // MARK: Semantic marks — STAT format badges

    /// Lime tonal ramp — primary → tertiary within one family
    /// (F1 common → richest legible; F4 combinations → lightest legible).
    static let statFormat1 = StudioPalette.color(.lime, light: .s600, dark: .s600)
    static let statFormat2 = StudioPalette.color(.lime, light: .s700, dark: .s500)
    static let statFormat3 = StudioPalette.color(.lime, light: .s800, dark: .s400)
    /// Format 4 (multi-axis combination) — lightest step on the STAT lime ramp.
    static let statFormat4 = StudioPalette.color(.lime, light: .s900, dark: .s300)
    /// Soft lime wash for Format 4 chrome (combination CTA, suggestion pill, builder hint).
    /// Strength matches `registrationBackground` so Add Combination reads like Add Naming Axis.
    static let statFormat4Background = StudioOpaqueFill.make(
        name: "statFormat4Background",
        hue: statFormat1,
        light: 0.22,
        dark: 0.22
    )
    /// Edge on Format 4 tinted surfaces (builder chrome, policy box).
    static let statFormat4Stroke = statFormat1.opacity(0.35)
    /// Baked badge fill for the `statFormat1` compound-name capsule — opaque composite,
    /// not `statFormat1.opacity()`.
    static let statFormat1Background = StudioOpaqueFill.make(
        name: "statFormat1Background",
        hue: statFormat1,
        light: 0.16,
        dark: 0.16
    )

    // MARK: Drag & drop zones

    /// Drop zone half fills — 5% tint over the target region during drag.
    static let dropZoneFillOpacity: CGFloat = 0.05
    /// Add-to-existing project — brand blue (pairs with selection / interaction, not registration).
    static let dropZoneAddFill = brand.opacity(dropZoneFillOpacity)
    static let dropZoneNewFill = StudioPalette.color(.green, light: .s500, dark: .s400).opacity(dropZoneFillOpacity)
    /// Drop zone borders when the cursor is over a half.
    static let dropAddExisting = brand
    static let dropNewProject = StudioPalette.color(.green, light: .s600, dark: .s400)
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
            .studioChipBackground(
                background,
                cornerRadius: compact ? StudioRadius.small : StudioRadius.small
            )
    }
}

struct StudioStatFormatBadge: View {
    let format: Int
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

  private var markColor: Color {
        switch format {
        case 2: StudioColors.statFormat2
        case 3: StudioColors.statFormat3
        case 4: StudioColors.statFormat4
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
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.chip))
                .help("Change STAT format")
            } else {
                badgeLabel
            }
        }
    }

    // Light mode: hue-colored text on a translucent tint of the same hue — the light-mode
    // stops are deep/saturated enough that text-vs-fill separation holds. Dark mode: the
    // dark-mode stops are intentionally pale/light (that's what clears 4.5:1 as *text* on a
    // near-black panel), so reusing that same pale hue for the fill made text and fill
    // collapse into one low-contrast blob. Flip to a near-solid fill of that pale hue with
    // near-black text instead — the pale color's high luminance guarantees strong contrast
    // against dark text, and the fill itself stays fully saturated/legible as a hue.
    private var isDark: Bool { colorScheme == .dark }

    private var badgeLabel: some View {
        Text("F\(format)")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .foregroundStyle(isDark ? StudioPalette.color(.ink, step: .s800) : markColor)
            .studioChipBackground(
                markColor.opacity(isDark ? 0.92 : 0.20),
                cornerRadius: StudioRadius.chip
            )
            .overlay {
                RoundedRectangle.studio(StudioRadius.chip)
                    .strokeBorder(markColor.opacity(isDark ? 1.0 : 0.45), lineWidth: 0.5)
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
                    .font(StudioTypography.caption)
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
// Exception: `StudioStatFormatBadge` colors its label too — with only short-lived
// glyphs ("F1"…"F4") shown side-by-side and no icon to anchor on, a neutral label
// left the badges distinguishable only by reading text, not by glancing at hue.

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

    var background: Color {
        // System yellow measures far lower luminance-contrast against a light panel than the
        // other diff hues at the same bake alpha, so it needs a stronger wash to register at all.
        // Opaque bake so translucent row/selection chrome cannot muddy the pill fill.
        switch self {
        case .removed: Self.removedFill
        case .added: Self.addedFill
        case .changed: Self.changedFill
        case .reflowed: Self.reflowedFill
        case .unchanged: Self.unchangedFill
        case .protected: Self.protectedFill
        }
    }
    /// Punch-out text — panel background, not `.primary`.
    var label: Color { StudioColors.chipLabel }

    /// Light hue edge on a darker fill — Review chips in both appearances.
    var stroke: Color {
        foreground.opacity(0.75)
    }

    var border: Color { stroke }

    private static let removedFill = StudioOpaqueFill.make(name: "diffPillRemoved", hue: StudioColors.diffRemoved, light: 0.52, dark: 0.58)
    private static let addedFill = StudioOpaqueFill.make(name: "diffPillAdded", hue: StudioColors.diffAdded, light: 0.52, dark: 0.58)
    private static let changedFill = StudioOpaqueFill.make(name: "diffPillChanged", hue: StudioColors.diffRenamed, light: 0.58, dark: 0.64)
    private static let reflowedFill = StudioOpaqueFill.make(name: "diffPillReflowed", hue: StudioColors.diffReflowed, light: 0.52, dark: 0.58)
    private static let unchangedFill = StudioOpaqueFill.make(name: "diffPillUnchanged", hue: .secondary, light: 0.42, dark: 0.46)
    private static let protectedFill = StudioOpaqueFill.make(name: "diffPillProtected", hue: StudioColors.diffProtected, light: 0.52, dark: 0.58)
}

struct StudioSemanticPill: View {
    let text: String
    let style: StudioDiffPillStyle

    var body: some View {
        Text(text)
            .font(StudioTypography.pillLabel)
            .foregroundStyle(style.label)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style.background, in: Capsule())
            .overlay(Capsule().strokeBorder(style.stroke, lineWidth: 0.5))
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
                .foregroundStyle(muted ? StudioColors.mutedForeground : Color.primary)
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
    var font: Font = StudioTypography.caption

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
/// Pin compact toggle — not the legacy switch / "Pinned" label.
struct StudioCountBadge: View {
    enum Emphasis {
        case metric
        case muted
        case warning
    }

    let text: String
    var highlighted: Bool = true
    var emphasis: Emphasis? = nil
    var fixedWidth: CGFloat? = nil
    var help: String = ""
    @Environment(\.studioOnAccentFill) private var onAccent

    private var resolvedEmphasis: Emphasis {
        emphasis ?? (highlighted ? .metric : .muted)
    }

    var body: some View {
        Text(text)
            .font(StudioTypography.caption.weight(.medium))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(digitForeground)
            .frame(width: fixedWidth)
            // Free (non-aligned) badges need breathing room; fixed-width column
            // badges (axis headers) keep their exact alignment slot.
            .padding(.horizontal, fixedWidth == nil ? 6 : 0)
            .padding(.vertical, 2)
            .background(capsuleFill, in: Capsule())
            .help(help)
    }

    private var digitForeground: AnyShapeStyle {
        if onAccent {
            return AnyShapeStyle(Color.white)
        }
        switch resolvedEmphasis {
        case .metric: return AnyShapeStyle(StudioColors.metricForeground)
        case .muted: return AnyShapeStyle(.secondary)
        case .warning: return AnyShapeStyle(StudioColors.warningOnFillForeground)
        }
    }

    private var capsuleFill: Color {
        if onAccent {
            // Soft white wash on secondary-blue chips — keeps the count readable.
            return Color.white.opacity(0.22)
        }
        switch resolvedEmphasis {
        case .metric: return StudioColors.surfaceMuted
        case .muted: return StudioColors.surfaceSubtle
        case .warning: return StudioColors.warningFill
        }
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

/// Connector between naming-chain chips (Inspector + Naming Order). Single SF Symbol —
/// not a dash + chevron mashup, which read as “- >”.
struct StudioChainArrow: View {
    var isActive: Bool = true

    var body: some View {
        Image(systemName: "arrowshape.right.fill")
            .font(StudioTypography.chainArrow)
            .foregroundStyle(Color.secondary.opacity(isActive ? 0.55 : 0.35))
            .padding(.horizontal, StudioSpacing.rowGap)
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
/// Also used for combination-style Elided (independent per compound; same mark language).
/// Prefer this over `StudioElidableSwitch` so Elided chrome matches the Axis Tree.
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

/// Independent on/off elision switch — prefer `StudioElidableRadio` for Axis Tree /
/// combination Elided so the mark matches. Kept for rare cases that need a true switch.
struct StudioElidableSwitch: View {
    @Binding var isOn: Bool
    var helpText: String = "Omit this name from the composed style when it is the default choice"

    var body: some View {
        Toggle("Elidable", isOn: $isOn)
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .studioBrandTint()
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
                .foregroundStyle(accentValue ? StudioColors.metricForeground : .primary)
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
        .background(StudioColors.surfaceLight, in: RoundedRectangle.studio(StudioRadius.control))
        .overlay(
            RoundedRectangle.studio(StudioRadius.control)
                .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: 0.5)
        )
    }
}


struct StudioSectionLabel: View {
    let title: String
    /// When `false` (floating menus/popovers, empty-state placeholders with no sibling
    /// title to out-rank), uses `.primary` for maximum contrast. Default uses
    /// `sectionHeading` — readable at a glance, still one weight below `.primary`.
    var muted: Bool = true

    var body: some View {
        Text(title.uppercased())
            .font(StudioTypography.sectionLabel)
            .foregroundStyle(muted ? StudioColors.sectionHeading : Color.primary)
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
    static let reviewNoChanges = "No changes to review — this export won't modify anything."
    static let reviewNoFilterMatch = "No rows match the current filters."
    static let reviewNoPreview = "No preview loaded yet."
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
    var horizontalPadding: CGFloat = StudioSpacing.contentInset
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        horizontalPadding: CGFloat = StudioSpacing.contentInset,
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
                    .font(StudioTypography.caption)
            } else {
                Text(label)
                    .font(StudioTypography.caption)
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
                RoundedRectangle.studio(StudioRadius.small)
                    .strokeBorder(
                        isOn || isIndeterminate
                            ? StudioColors.metricForeground.opacity(0.65)
                            : Color.secondary.opacity(0.35),
                        lineWidth: StudioStroke.regular
                    )
                    .frame(width: Self.size, height: Self.size)
                if isIndeterminate {
                    RoundedRectangle.studio(StudioRadius.hairline)
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 6, height: 1.5)
                } else if isOn {
                    Image(systemName: "checkmark")
                        .font(StudioTypography.iconGlyph.weight(.bold))
                        .foregroundStyle(StudioColors.metricForeground)
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
                .padding(.horizontal, -StudioSpacing.contentInset)
        }
    }
}

struct StudioCompactToolbar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioSpacing.toolbarVertical)
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
    /// Trailing clear control when the field has text (Preview sample, etc.).
    var showsClearButton: Bool = false

    /// When set, non-empty value text uses this color (e.g. clarifier fields in file naming).
    var filledForeground: Color? = nil
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil
    var submitBehavior: StudioTextSubmitBehavior = .commit
    var focusBinding: FocusState<Bool>.Binding? = nil
    /// Fired when this field becomes focused (e.g. scroll-to-focus parents).
    var onFocused: (() -> Void)? = nil

    @FocusState private var internalFocus: Bool
    @Environment(\.isEnabled) private var isEnabled

    private var activeFocus: FocusState<Bool>.Binding {
        focusBinding ?? $internalFocus
    }

    var body: some View {
        HStack(spacing: StudioSpacing.tightGap) {
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
            .focused(activeFocus)
            .modifier(StudioFocusRingSuppression())
            .modifier(StudioTextInputAccentModifier())
            .studioInteractiveCursor()
            .onSubmit { handleSubmit() }
            .onExitCommand { handleCancel() }
            .onChange(of: activeFocus.wrappedValue) { _, isFocused in
                if isFocused {
                    onFocused?()
                }
            }

            if showsClearButton, !text.isEmpty {
                StudioDismissButton(scale: .chip, style: .fill, help: "Clear") {
                    text = ""
                }
            }
        }
        .padding(.horizontal, showsFieldChrome ? StudioFieldMetrics.horizontalPadding : 0)
        .frame(height: rowHeight, alignment: .center)
        .background {
            if showsFieldChrome {
                RoundedRectangle.studio(StudioRadius.control)
                    .fill(fieldBackground)
            }
        }
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
            RoundedRectangle.studio(StudioRadius.control)
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
    /// Instances / Review / Instancer tool rows — 28pt compact chrome.
    var compact: Bool = false

    @FocusState private var internalFocus: Bool

    private var activeFocus: FocusState<Bool>.Binding {
        isFocused ?? $internalFocus
    }

    private var isFieldFocused: Bool {
        activeFocus.wrappedValue
    }

    var body: some View {
        HStack(spacing: compact ? StudioSpacing.tightGap : 4) {
            Image(systemName: "magnifyingglass")
                .font(compact ? StudioCompactControlChrome.symbolFont : StudioTypography.caption)
                .foregroundStyle(StudioColors.textPlaceholder)

            StudioTextField(
                placeholder: placeholder,
                text: $text,
                font: compact ? StudioCompactControlChrome.labelFont : StudioTypography.caption,
                rowHeight: compact
                    ? StudioCompactControlChrome.searchHeight - 4
                    : StudioFieldMetrics.captionRowHeight,
                showsFieldChrome: false,
                focusBinding: activeFocus
            )

            if !text.isEmpty {
                StudioDismissButton(scale: .chip, style: .fill) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, compact ? StudioCompactControlChrome.horizontalPadding : 7)
        .frame(height: compact ? StudioCompactControlChrome.searchHeight : StudioFieldMetrics.captionRowHeight + 8)
        .background(
            isFieldFocused
                ? StudioColors.fieldFillFocused
                : (compact ? StudioCompactControlChrome.idleFill : StudioColors.fieldFill),
            in: RoundedRectangle.studio(
                compact ? StudioCompactControlChrome.cornerRadius : StudioRadius.control
            )
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
            RoundedRectangle.studio(StudioRadius.control)
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
                RoundedRectangle.studio(StudioRadius.control)
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

    /// Selected / highlighted chips use `brandSecondaryFill` — children switch to
    /// white on-accent chrome via this environment (counts, dirty dots, dismiss).
    private var onAccentFill: Bool { isSelected || isHighlighted }

    var body: some View {
        HStack(spacing: 5) {
            label()
            trailing()
        }
        .padding(.horizontal, StudioFieldMetrics.tabChipHorizontalPadding)
        .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
        .frame(minHeight: StudioFieldMetrics.tabChipRowHeight)
        .environment(\.studioOnAccentFill, onAccentFill)
        .foregroundStyle(onAccentFill ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
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
                RoundedRectangle.studio(StudioRadius.chip)
                    .fill(chipFill)
                    .overlay {
                        if isHighlighted {
                            RoundedRectangle.studio(StudioRadius.chip)
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
            RoundedRectangle.studio(StudioRadius.chip)
                .fill(dropTargetTint.opacity(StudioColors.dropZoneFillOpacity))
        }
    }

    private var chipFill: Color {
        if isSelected || isHighlighted {
            return StudioColors.brandSecondaryFill
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
                    RoundedRectangle.studio(StudioRadius.control)
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
///
/// Neutral chrome by design — app-level `studioBrandTint()` would otherwise paint
/// `Menu` labels brand blue. On selected tab chips (`studioOnAccentFill`), uses white.
struct StudioOverflowMenu<Content: View>: View {
    var scale: StudioChromeScale = .toolbar
    var help: String = "Actions"
    @ViewBuilder var content: () -> Content
    @Environment(\.studioOnAccentFill) private var onAccent
    @State private var isHovered = false

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
        // Override app `studioBrandTint()` — Menu ignores label `foregroundStyle`.
        .tint(menuTint)
        .onHover { isHovered = $0 }
        .help(help)
    }

    private var menuTint: Color {
        StudioIconForeground.resolve(
            tint: nil,
            state: isHovered ? .hovered : .idle,
            onAccent: onAccent
        )
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

/// Panel-header collapse / expand control (`sidebar.left` / `sidebar.right`).
///
/// Lays out at glyph size so the trailing edge matches other headers’ `contentInset`
/// (a full `toolbarIconHitSize` square was optically short on the divider). Hit area
/// expands toward the title, not past the inset.
struct StudioPanelCollapseButton: View {
    enum Edge {
        case leading
        case trailing

        var systemName: String {
            switch self {
            case .leading: "sidebar.left"
            case .trailing: "sidebar.right"
            }
        }
    }

    var edge: Edge
    var help: String
    let action: () -> Void

    private var hitPad: CGFloat {
        (StudioFieldMetrics.toolbarIconHitSize - StudioFieldMetrics.toolbarIconPointSize) / 2
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: edge.systemName)
                .font(.system(
                    size: StudioFieldMetrics.toolbarIconPointSize,
                    weight: StudioChromeScale.symbolWeight
                ))
                .symbolRenderingMode(.monochrome)
                .frame(
                    width: StudioFieldMetrics.toolbarIconPointSize,
                    height: StudioFieldMetrics.toolbarIconPointSize
                )
                // Grow hit toward the title; keep glyph flush with header content inset.
                .padding(.leading, hitPad * 2)
                .padding(.vertical, hitPad)
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
    @Environment(\.studioOnAccentFill) private var onAccent
    @State private var isHovered = false

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
        .tint(StudioIconForeground.resolve(
            tint: nil,
            state: isHovered ? .hovered : .idle,
            onAccent: onAccent
        ))
        .onHover { isHovered = $0 }
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
                    RoundedRectangle.studio(StudioRadius.control)
                        .fill(isFocused ? StudioColors.fieldFillFocused : StudioColors.fieldFill)
                }
            }
            .modifier(StudioFocusRingSuppression())
    }
}

// MARK: - Hover chrome

enum StudioHoverShape: Equatable {
    case rect
    case roundedRect(cornerRadius: CGFloat = StudioRadius.control)
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
            RoundedRectangle.studio(radius).fill(fill)
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
    @Environment(\.studioOnAccentFill) private var onAccent

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
        StudioIconForeground.resolve(tint: tint, state: interactionState, onAccent: onAccent)
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
    /// Default ring: `StudioDragOutline` 4pt all sides, 6pt radius.
    /// Pass outsets for Axis Tree (8pt horizontal / 4pt vertical).
    func studioDragAffordances(
        isEnabled: Bool = true,
        isDragging: Bool = false,
        showsOutline: Bool = true,
        showsCursor: Bool = true,
        outlineHorizontalOutset: CGFloat = StudioDragOutline.outset,
        outlineVerticalOutset: CGFloat = StudioDragOutline.outset
    ) -> some View {
        modifier(
            StudioDragAffordancesModifier(
                isEnabled: isEnabled,
                isDragging: isDragging,
                showsOutline: showsOutline,
                showsCursor: showsCursor,
                outlineHorizontalOutset: outlineHorizontalOutset,
                outlineVerticalOutset: outlineVerticalOutset
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

private struct StudioOnAccentFillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    fileprivate var studioDragCursorGate: StudioDragCursorGate? {
        get { self[StudioDragCursorGateKey.self] }
        set { self[StudioDragCursorGateKey.self] = newValue }
    }

    /// True inside selected/highlighted `StudioTabChip` (`brandSecondaryFill`).
    /// Counts, dirty/master marks, and icon chrome switch to white on-accent.
    var studioOnAccentFill: Bool {
        get { self[StudioOnAccentFillKey.self] }
        set { self[StudioOnAccentFillKey.self] = newValue }
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
    var showsOutline: Bool
    var showsCursor: Bool
    var outlineHorizontalOutset: CGFloat
    var outlineVerticalOutset: CGFloat
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
                    StudioDragOutline.expandedRing(
                        horizontalOutset: outlineHorizontalOutset,
                        verticalOutset: outlineVerticalOutset
                    )
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
                        .background(StudioColors.brand, in: RoundedRectangle.studio(StudioRadius.small))
                }
                .padding(.leading, StudioSpacing.contentInset)
                .padding(.trailing, StudioSpace.x1)
                .padding(.vertical, StudioSpace.x1_5)
                .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.bodyRowHeight, alignment: .leading)
                .background(StudioColors.buttonSecondaryFill, in: RoundedRectangle.studio(StudioRadius.control))
                .contentShape(RoundedRectangle.studio(StudioRadius.control))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
            .studioInteractiveCursor()
            .accessibilityLabel(title.isEmpty ? selectedTitle : title)
        }
    }
}

// MARK: - Compact continuous value

/// Thin-track value control for dense chrome (font preview size, etc.).
/// Replaces `Slider` + `.controlSize(.mini)`, which draws macOS tick marks and
/// fights the Studio compact language. Neutral track/thumb — not brand.
struct StudioCompactSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1

    private let trackHeight: CGFloat = 3
    private let thumbWidth: CGFloat = 7
    private let thumbHeight: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = range.upperBound > range.lowerBound
                ? (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                : 0
            let thumbX = CGFloat(fraction) * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.28))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(Color.secondary.opacity(0.55))
                    .frame(width: max(thumbWidth, thumbX), height: trackHeight)

                Capsule()
                    .fill(Color.primary.opacity(0.85))
                    .frame(width: thumbWidth, height: thumbHeight)
                    .position(x: min(width, max(0, thumbX)), y: geo.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0 else { return }
                        let raw = Double(drag.location.x / width)
                        let clamped = min(1, max(0, raw))
                        let unstepped = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                        let stepped = (step > 0)
                            ? (range.lowerBound + (round((unstepped - range.lowerBound) / step) * step))
                            : unstepped
                        value = min(range.upperBound, max(range.lowerBound, stepped))
                    }
            )
        }
        .frame(height: StudioCompactControlChrome.controlHeight)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Compact filter / toolbar chrome

/// Shared compact control chrome (Instances filter bar, Naming Order footer toggles, etc.).
/// Fixed 22pt height, always-on idle fill, stronger active fill, SF Rounded labels.
enum StudioCompactControlChrome {
    /// Text-button labels only. Symbols keep their own SF Symbol metrics.
    /// Resolved via `NSFont` + `.rounded` — SwiftUI's `Font.system(design: .rounded)` alone
    /// can silently fall back to SF Pro on macOS when an environment font wins.
    static let labelFont: Font = {
        let size: CGFloat = 11
        let base = NSFont.systemFont(ofSize: size, weight: .regular)
        if let rounded = base.fontDescriptor.withDesign(.rounded),
           let nsFont = NSFont(descriptor: rounded, size: size) {
            return Font(nsFont)
        }
        return Font.system(size: size, weight: .regular, design: .rounded)
    }()
    /// SF Symbol size for compact icon segments — not rounded-design text.
    static let symbolFont = Font.system(size: 11, weight: .medium)
    static let cornerRadius = StudioRadius.control
    static let segmentcornerRadius = StudioRadius.small
    static let horizontalPadding = StudioSpacing.contentInset
    /// Leading inset when the button embeds a checkbox — half of `horizontalPadding`
    /// so the mark lines up with instance-row checkboxes (panel + rowContentInset).
    static var checkboxLeadingPadding: CGFloat { horizontalPadding / 2 }
    /// Gap between the embedded checkbox and the title — absorbs the leading half
    /// that was removed, so total button width stays the same.
    static var checkboxTitleGap: CGFloat { StudioSpacing.tightGap + checkboxLeadingPadding }
    /// Outer pad inside a Names|Coords-style tray around the segments.
    static let trayInset = StudioSpace.x0_5
    /// Locked to the text-only control height (Hide elided / Code / Restore).
    static let controlHeight: CGFloat = 22
    /// Search field is allowed to read taller than the button row.
    static let searchHeight: CGFloat = 28
    /// Checkbox mark sized to fit inside `controlHeight` without growing the button.
    static let checkboxSize: CGFloat = 12

    static var idleFill: Color { StudioColors.surfaceInset }
    static var activeFill: Color { StudioColors.selectionNeutralFillStrong }
    /// Inverted selection chip: light fill / dark label (opposite of idle buttons).
    static var chipFill: Color { Color.primary }
    static var chipForeground: Color { Color(nsColor: .textBackgroundColor) }

    static func fill(isActive: Bool, accentFill: Color? = nil) -> Color {
        guard isActive else { return idleFill }
        return accentFill ?? activeFill
    }

    static func foreground(isActive: Bool, isEnabled: Bool = true, accentForeground: Color? = nil) -> Color {
        guard isEnabled else { return Color.secondary.opacity(0.45) }
        guard isActive else { return Color.secondary }
        return accentForeground ?? Color.primary
    }

    /// Segment height inside a tray (tray inset on top + bottom).
    static var segmentHeight: CGFloat { controlHeight - trayInset * 2 }
}

/// Checkbox mark for bulk-select triggers (Instances Include, Instancer Select).
enum StudioBulkSelectMark {
    case all
    case none
    case mixed

    var systemImage: String {
        switch self {
        case .all: "checkmark.square"
        case .none: "square"
        case .mixed: "minus.square"
        }
    }
}

/// Compact check / square / minus.square trigger with an opaque action popover.
struct StudioBulkSelectMenu<Content: View>: View {
    var mark: StudioBulkSelectMark
    var help: String = ""
    var isEnabled: Bool = true
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Image(systemName: mark.systemImage)
                    .font(StudioCompactControlChrome.symbolFont)
                    .foregroundStyle(StudioColors.metricForeground)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, StudioCompactControlChrome.horizontalPadding)
            .frame(height: StudioCompactControlChrome.controlHeight)
            .background(
                StudioCompactControlChrome.idleFill,
                in: RoundedRectangle.studio(StudioCompactControlChrome.cornerRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioCompactControlChrome.cornerRadius))
        .disabled(!isEnabled)
        .help(help)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
                content()
            }
            .padding(StudioSpace.x0_5)
            .frame(minWidth: 188)
            .presentationBackground(StudioColors.chipSurface)
        }
    }
}

/// One action row inside `StudioBulkSelectMenu` — leading check, title, trailing mark.
struct StudioBulkSelectMenuRow: View {
    let title: String
    var mark: StudioBulkSelectMark
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StudioSpacing.tightGap) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColors.metricForeground)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12, alignment: .leading)
                Text(title)
                    .font(StudioCompactControlChrome.labelFont)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: mark.systemImage)
                    .font(StudioCompactControlChrome.symbolFont)
                    .foregroundStyle(StudioColors.metricForeground)
            }
            .padding(.horizontal, StudioSpace.x1_5)
            .padding(.vertical, StudioSpacing.panelVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
    }
}

/// Semantic active tint for compact toggles (hue lives in fill/stroke; label stays readable).
enum StudioCompactToggleAccent {
    /// Matches the naming-chain Code chip (`StudioColors.code*`).
    case code

    var fill: Color {
        switch self {
        case .code: StudioColors.codeBackground
        }
    }

    var foreground: Color {
        switch self {
        case .code: StudioColors.codeForeground
        }
    }

    var stroke: Color {
        switch self {
        case .code: StudioColors.codeStroke
        }
    }
}

/// Compact filled toggle / action — same chrome as Instances "Hide elided" / "Include all".
struct StudioCompactToggleButton: View {
    let title: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    var help: String = ""
    /// When set, active state uses this semantic wash instead of the neutral active fill.
    var accent: StudioCompactToggleAccent? = nil
    /// Embeds an include-checkbox mark inside the button (Instances Include all).
    var showsCheckbox: Bool = false
    var checkboxOn: Bool = false
    var checkboxIndeterminate: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: showsCheckbox
                   ? StudioCompactControlChrome.checkboxTitleGap
                   : StudioSpacing.tightGap) {
                if showsCheckbox {
                    includeMark
                }
                Text(title)
                    .font(StudioCompactControlChrome.labelFont)
                    .foregroundStyle(StudioCompactControlChrome.foreground(
                        isActive: isActive,
                        isEnabled: isEnabled,
                        accentForeground: accent?.foreground
                    ))
            }
            .padding(
                .leading,
                showsCheckbox
                    ? StudioCompactControlChrome.checkboxLeadingPadding
                    : StudioCompactControlChrome.horizontalPadding
            )
            .padding(.trailing, StudioCompactControlChrome.horizontalPadding)
            .frame(height: StudioCompactControlChrome.controlHeight)
            .background(
                StudioCompactControlChrome.fill(isActive: isActive, accentFill: accent?.fill),
                in: RoundedRectangle.studio(StudioCompactControlChrome.cornerRadius)
            )
            .overlay {
                if isActive, let stroke = accent?.stroke {
                    RoundedRectangle.studio(StudioCompactControlChrome.cornerRadius)
                        .strokeBorder(stroke, lineWidth: StudioStroke.regular)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: StudioCompactControlChrome.cornerRadius),
            isEnabled: isEnabled && !isActive
        )
        .help(help)
    }

    /// Same visual language as `StudioIncludeCheckbox`, but mark-only and sized to
    /// fit `controlHeight` so Include all doesn't grow taller than Hide elided.
    private var includeMark: some View {
        let size = StudioCompactControlChrome.checkboxSize
        return ZStack {
            RoundedRectangle.studio(StudioRadius.small)
                .strokeBorder(
                    checkboxOn || checkboxIndeterminate
                        ? StudioColors.brand.opacity(0.55)
                        : Color.secondary.opacity(0.35),
                    lineWidth: StudioStroke.regular
                )
                .frame(width: size, height: size)
            if checkboxIndeterminate {
                RoundedRectangle.studio(StudioRadius.hairline)
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 5, height: 1.5)
            } else if checkboxOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioColors.brand)
            }
        }
        .frame(width: size, height: size)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Flat filled action — primary (accent) or secondary (gray). No border, no dashed chrome.
struct StudioFlatButton: View {
    enum Role {
        case primary
        case secondary
        /// Tinted variant — `foreground` is the label color; `background` is the chip fill.
        /// Warning CTAs: `warningAction`. Soft washes (registration): pass `.primary` as label.
        case tinted(foreground: Color, background: Color)

        /// Shared Review / Resolve CTA on amber — dark ink on `warningFillHover`.
        static var warningAction: Role {
            .tinted(
                foreground: StudioColors.warningButtonForeground,
                background: StudioColors.warningFillHover
            )
        }

        /// Destructive choice on secondary fill — red label, not a solid red chip.
        static var destructiveAction: Role {
            .tinted(
                foreground: StudioColors.errorForeground,
                background: StudioColors.buttonSecondaryFill
            )
        }
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
        case .compact: StudioTypography.caption
        }
    }

    static func horizontalPadding(size: StudioFlatButton.Size) -> CGFloat {
        StudioSpacing.contentInset
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
            case .secondary, .tinted: return Color.secondary.opacity(0.55)
            }
        }
        switch role {
        case .primary: return .white
        // `.tinted` uses the caller-supplied label color so bright fills (warning amber)
        // can pick dark ink instead of `.primary` (white in dark mode — fails AA on the
        // CTA chip). Soft tinted fills (registration) pass `.primary`.
        case .secondary: return .primary
        case .tinted(let foreground, _): return foreground
        }
    }

    static func fill(role: StudioFlatButton.Role, isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch role {
            case .primary: return StudioColors.brandFillDisabled
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
                in: RoundedRectangle.studio(StudioRadius.control)
            )
            .overlay {
                if overlayOpacity > 0 {
                    RoundedRectangle.studio(StudioRadius.control)
                        .fill(Color.primary.opacity(overlayOpacity))
                }
            }
            .contentShape(RoundedRectangle.studio(StudioRadius.control))
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
    @Environment(\.studioOnAccentFill) private var onAccent
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
            .foregroundStyle(StudioIconForeground.resolve(tint: tint, state: state, onAccent: onAccent))
            .onHover { isHovered = $0 }
    }
}

struct StudioSegmentButtonStyle: ButtonStyle {
    var isSelected: Bool
    var expands: Bool

    @State private var isHovered = false

    private var cornerRadius: CGFloat {
        expands ? StudioRadius.control : StudioRadius.small
    }

    func makeBody(configuration: Configuration) -> some View {
        let state = StudioInteractionState.from(
            isPressed: configuration.isPressed,
            isHovered: isHovered
        )
        configuration.label
            .background {
                RoundedRectangle.studio(cornerRadius)
                    .fill(segmentBackground(state: state))
            }
            .contentShape(RoundedRectangle.studio(cornerRadius))
            .onHover { isHovered = $0 }
    }

    private func segmentBackground(state: StudioInteractionState) -> Color {
        if isSelected {
            return StudioColors.brandSecondaryFill
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

/// Compact confirm sheet with stacked `StudioFlatButton`s.
/// Prefer this over `.confirmationDialog` / `.alert` when chrome must match the studio.
struct StudioConfirmDialog: View {
    struct Action {
        let title: String
        var role: StudioFlatButton.Role = .secondary
        var isDefaultAction: Bool = false
        var isCancelAction: Bool = false
        let perform: () -> Void
    }

    let title: String
    let message: String
    let actions: [Action]

    var body: some View {
        VStack(spacing: StudioSpace.x5) {
            VStack(spacing: StudioSpacing.tightGap) {
                Text(title)
                    .font(StudioTypography.emphasis)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(StudioTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: StudioSpacing.controlGap) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    actionButton(action)
                }
            }
        }
        .padding(StudioSpace.x5)
        .frame(width: 340)
    }

    @ViewBuilder
    private func actionButton(_ action: Action) -> some View {
        let button = StudioFlatButton(
            title: action.title,
            role: action.role,
            expands: true,
            isDefaultAction: action.isDefaultAction,
            action: action.perform
        )
        if action.isCancelAction {
            button.keyboardShortcut(.cancelAction)
        } else {
            button
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
    var font: Font = StudioTypography.caption
    var help: String = ""
    /// Marks the segment when its panel holds unresolved issues, so the user does not
    /// have to open the tab to find out.
    var showsWarning: Bool = false
    var badge: String? = nil
    var badgeEmphasis: StudioCountBadge.Emphasis = .muted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StudioSpace.x1) {
                Text(title)
                    .font(font.weight(isSelected ? .semibold : .regular))
                    // Selected = white on `brandSecondaryFill` (mid blue). Avoids the
                    // former sky-on-navy pairing of `metricForeground` + `selectionFill`.
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.78))
                if let badge {
                    StudioCountBadge(text: badge, emphasis: badgeEmphasis)
                }
                if showsWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(StudioColors.warningForeground)
                }
            }
            .frame(maxWidth: expands ? .infinity : nil)
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, expands ? StudioSpacing.panelVertical : StudioSpacing.tightGap)
            .environment(\.studioOnAccentFill, isSelected)
        }
        .buttonStyle(StudioSegmentButtonStyle(isSelected: isSelected, expands: expands))
        .help(help)
    }
}

// MARK: - Row chrome

enum StudioRowChrome {
    static func fill(isSelected: Bool, isHovered: Bool, isWarning: Bool) -> Color {
        if isWarning {
            // Stay in the yellow container family on hover — amber is reserved for CTAs.
            return isHovered ? StudioColors.warningFillStrong : StudioColors.warningFill
        }
        if isSelected {
            // Neutral selected row — same language as hover, one step stronger.
            // Brand / secondary blue stays on CTAs and tabs, not list chrome.
            return StudioColors.selectionNeutralFillStrong
        }
        if isHovered {
            return StudioColors.hoverFill
        }
        return .clear
    }
}

struct StudioDirtyDot: View {
    var tint: Color = StudioColors.brand
    @Environment(\.studioOnAccentFill) private var onAccent

    var body: some View {
        Circle()
            .fill(onAccent ? Color.white : tint)
            .frame(width: StudioFieldMetrics.dirtyDotSize, height: StudioFieldMetrics.dirtyDotSize)
            .frame(width: StudioFieldMetrics.statusBadgeSlot, height: StudioFieldMetrics.statusBadgeSlot)
    }
}

/// Master-font star. Shares `statusBadgeSlot` with `StudioDirtyDot` so the pair
/// centers on the same axis when adjacent in a chip/row.
struct StudioMasterStar: View {
    @Environment(\.studioOnAccentFill) private var onAccent

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: StudioFieldMetrics.masterStarPointSize))
            .foregroundStyle(onAccent ? Color.white : StudioColors.brand)
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
        RoundedRectangle.studio(StudioRadius.control)
            .fill(StudioRowChrome.fill(
                isSelected: isSelected,
                isHovered: isHovered,
                isWarning: isWarning
            ))
            .overlay {
                if isSelected && selectionStyle == .fillAndStroke && !isWarning {
                    RoundedRectangle.studio(StudioRadius.control)
                        .strokeBorder(StudioColors.selectionStroke, lineWidth: 0.5)
                }
            }
    }
}

// MARK: - View helpers

extension View {
    func studioPanelPadding() -> some View {
        padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioSpacing.panelVertical)
    }

    func studioRowInsets() -> some View {
        padding(.horizontal, StudioSpacing.rowHorizontal)
            .padding(.vertical, StudioSpacing.instanceRowVertical)
    }

    /// Translucent chip wash over an opaque `chipSurface` base so row
    /// selection/hover cannot show through and recolor the chip.
    func studioChipBackground(
        _ wash: Color,
        cornerRadius: CGFloat = StudioRadius.small
    ) -> some View {
        background {
            RoundedRectangle.studio(cornerRadius)
                .fill(StudioColors.chipSurface)
                .overlay {
                    RoundedRectangle.studio(cornerRadius)
                        .fill(wash)
                }
        }
    }

    func studioCompactControl() -> some View {
        font(StudioTypography.caption)
            .controlSize(.small)
    }
}


/// Simple warning caption row for lists (Save Review warnings, etc.).
/// Message uses `warningOnFillForeground` — this view sits on `warningFill` banners.
struct StudioWarningMessage: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.warningForeground)
            Text(message)
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.warningOnFillForeground)
        }
    }
}

/// Inline validation/error caption — mirrors `StudioWarningMessage`. The error hue lives
/// on the icon; message text stays `.primary` so it clears text-contrast minimums on the
/// tinted fills this typically sits over.
struct StudioErrorMessage: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            Image(systemName: "xmark.circle.fill")
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.errorForeground)
            Text(message)
                .font(StudioTypography.caption)
                .foregroundStyle(.primary)
        }
    }
}

/// Inline success caption — mirrors `StudioWarningMessage`/`StudioErrorMessage`. The success
/// hue lives on the icon only; message text stays `.primary`.
struct StudioSuccessMessage: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            Image(systemName: "checkmark.circle.fill")
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.successForeground)
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
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.warningForeground)

            Text(message)
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.warningOnFillForeground)
                .lineLimit(2)

            Spacer(minLength: 0)

            StudioFlatButton(
                title: actionTitle,
                role: .warningAction,
                size: .compact,
                action: action
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioColors.warningFill, in: RoundedRectangle.studio(StudioRadius.surface))
    }
}

