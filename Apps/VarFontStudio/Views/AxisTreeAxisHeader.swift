import SwiftUI
import VarFontCore

// MARK: - Axis header

struct AxisTreeAxisHeader: View {
    let axis: AxisDefinition
    let isExpanded: Bool
    var hasConflict: Bool = false
    var axisWarnings: [PlanWarning] = []
    var resolvablePlanWarnings: [PlanWarning] = []
    var fileRegistrationLabel: String?
    var registrationStops: [AxisValue] = []
    var selectedRegistrationStopID: String?
    var onSelectRegistrationStop: ((String) -> Void)?
    /// Passive slope sibling: kept in STAT / export, excluded from composed names.
    var outOfNamingCaption: String? = nil
    @Binding var isInstanceAxis: Bool
    let onToggleExpansion: () -> Void
    var onResolveConflict: (() -> Void)?
    var onReviewPlanIssue: (() -> Void)?
    /// When set, shows an edit affordance to rename the STAT/fvar axis display name (not the 4-char tag).
    var onUpdateDisplayName: ((String) -> Void)? = nil

    @State private var isEditingDisplayName = false
    @State private var editedDisplayName = ""
    @FocusState private var displayNameFieldFocused: Bool

    private var lane: AxisLane { axis.lane }
    private var isOutOfNaming: Bool { outOfNamingCaption != nil }

    private var currentDisplayName: String {
        axis.displayName ?? axis.tag
    }

    private var hasAxisAttention: Bool {
        hasConflict || !axisWarnings.isEmpty
    }

    private var subtitleText: String? {
        var parts: [String] = []
        switch lane {
        case .variation:
            if let range = axisRangeText { parts.append(range) }
        case .pinned:
            if let range = axisRangeText, let pin = axis.pinCoordinate {
                parts.append("\(range) · Pinned at \(StudioFormatting.axisValue(pin))")
            } else if let pin = axis.pinCoordinate {
                parts.append("Pinned at \(StudioFormatting.axisValue(pin))")
            } else if let range = axisRangeText {
                parts.append(range)
            }
        case .registration:
            return nil
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var selectedRegistrationName: String {
        if let selectedRegistrationStopID,
           let stop = registrationStops.first(where: { $0.id == selectedRegistrationStopID }) {
            return stop.name
        }
        return fileRegistrationLabel ?? "—"
    }

    private var attentionHelp: String {
        if hasConflict {
            return "Naming conflict on this axis"
        }
        return axisWarnings.map { warning in
            if let hint = warning.hint, !hint.isEmpty {
                return "\(warning.message)\n\(hint)"
            }
            return warning.message
        }.joined(separator: "\n\n")
    }

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            if hasAxisAttention {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.warningForeground)
                    .help(attentionHelp)
            }

            StudioTagPill(
                text: axis.tag,
                role: axis.isDesignRecordOnly ? .registration : .instance
            )
            .frame(width: AxisBlockLayout.tagColumnWidth, alignment: .leading)
            .opacity(isOutOfNaming ? 0.55 : 1)

            if axis.fvarHidden {
                Text("hidden")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, StudioSpacing.tightGap)
                    .padding(.vertical, StudioSpacing.instanceRowGap)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle.studio(StudioRadius.chip))
                    .help("Hide this axis from user-facing controls (fvar HIDDEN_AXIS flag).")
            }

            if isOutOfNaming {
                Text("out of naming")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, StudioSpacing.tightGap)
                    .padding(.vertical, StudioSpacing.instanceRowGap)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle.studio(StudioRadius.chip))
                    .help(outOfNamingHelp)
            }

            VStack(alignment: .leading, spacing: StudioSpacing.instanceRowGap) {
                HStack(spacing: StudioSpacing.tightGap) {
                    if isEditingDisplayName {
                        StudioTextField(
                            placeholder: "Axis name",
                            text: $editedDisplayName,
                            font: StudioTypography.body,
                            rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                            onSubmit: commitDisplayName,
                            onCancel: cancelDisplayName,
                            focusBinding: $displayNameFieldFocused
                        )
                        .frame(maxWidth: 220, alignment: .leading)
                    } else {
                        Text(currentDisplayName)
                            .font(StudioTypography.body)
                            .lineLimit(1)
                            .opacity(isOutOfNaming ? 0.72 : 1)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onToggleExpansion)
                            .studioHoverLink(isOutOfNaming ? .secondary : .primary)
                            .studioInteractiveCursor()
                            .help(displayNameHelp)
                    }

                    if onUpdateDisplayName != nil, !isEditingDisplayName {
                        StudioToolbarIconButton(
                            systemName: StudioSymbols.edit,
                            help: "Rename axis (STAT and fvar label). The 4-character tag and interpolation are unchanged."
                        ) {
                            editedDisplayName = currentDisplayName
                            isEditingDisplayName = true
                        }
                    }

                    StudioDisclosureChevron(isExpanded: isExpanded)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onToggleExpansion)
                        .studioHoverIcon()
                        .studioInteractiveCursor()
                        // Static string: flipping help while hovered restarts AppKit
                        // tooltip tracking and can crash AttributeGraph on expand/collapse.
                        .help("Expand or collapse axis stops")

                    Spacer(minLength: 0)
                }
                .onChange(of: isEditingDisplayName) { _, editing in
                    if editing {
                        DispatchQueue.main.async {
                            displayNameFieldFocused = true
                        }
                    }
                }
                .onChange(of: axis.displayName) { _, _ in
                    if !isEditingDisplayName {
                        editedDisplayName = currentDisplayName
                    }
                }

                // File-axis stop menu must stay outside the expand button.
                if lane == .registration {
                    registrationSubtitle
                } else if let subtitleText {
                    Text(subtitleText)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .help("The lowest and highest values this axis supports, and its default (fvar min/default/max). D icon = default coordinate.")
                }
            }
            .opacity(isOutOfNaming ? 0.78 : 1)

            Spacer(minLength: 0)

            if hasConflict, let onResolveConflict {
                StudioFlatButton(
                    title: "Resolve",
                    size: .compact,
                    help: "Open conflict resolver for this axis"
                ) {
                    onResolveConflict()
                }
            } else if !resolvablePlanWarnings.isEmpty, let onReviewPlanIssue {
                StudioFlatButton(
                    title: "Review…",
                    role: .warningAction,
                    size: .compact,
                    help: resolvablePlanWarnings.first?.hint ?? "Review plan issues on this axis"
                ) {
                    onReviewPlanIssue()
                }
            }

            HStack(spacing: StudioSpacing.rowGap) {
                stopCountBadge
                    .fixedSize(horizontal: true, vertical: false)

                if axis.showsPinToggle {
                    StudioCompactToggleButton(
                        title: "Pin",
                        isActive: !isInstanceAxis,
                        help: pinToggleHelp
                    ) {
                        isInstanceAxis.toggle()
                    }
                    .accessibilityLabel(pinToggleAccessibilityLabel)
                    .studioInteractiveCursor()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    @ViewBuilder
    private var registrationSubtitle: some View {
        HStack(spacing: StudioSpacing.tightGap) {
            if let outOfNamingCaption {
                Text(outOfNamingCaption)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .help(outOfNamingHelp)
            } else if let axisRangeText {
                Text(axisRangeText)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .help("This naming axis still has an fvar entry (often a pinned coordinate). Interpolation is unchanged; the stop is for naming/STAT.")
            } else {
                Text("No fvar scale")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if !registrationStops.isEmpty {
                Text("·")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)

                // Single stop: static label (no menu chrome). Multiple: one chevron only.
                if registrationStops.count == 1 || onSelectRegistrationStop == nil {
                    Text(selectedRegistrationName)
                        .font(StudioTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isOutOfNaming ? .secondary : .primary)
                        .help(registrationStopHelp)
                } else if let onSelectRegistrationStop {
                    Menu {
                        ForEach(registrationStops) { stop in
                            Button {
                                onSelectRegistrationStop(stop.id)
                            } label: {
                                if stop.id == selectedRegistrationStopID {
                                    Label(stop.name, systemImage: "checkmark")
                                } else {
                                    Text(stop.name)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: StudioSpace.x0_5) {
                            Text(selectedRegistrationName)
                                .font(StudioTypography.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(isOutOfNaming ? .secondary : .primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(StudioTypography.iconGlyph)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .studioHoverLink(.accent)
                    .studioInteractiveCursor()
                    .help(registrationStopHelp)
                }
            }
        }
    }

    private var displayNameHelp: String {
        if isOutOfNaming {
            return outOfNamingHelp
        }
        if lane == .registration {
            return "Registration axis — no instance-grid scale; this file’s STAT stop is shown beside the label."
        }
        return "Expand or collapse axis stops"
    }

    private var outOfNamingHelp: String {
        "This axis stays in the font on export. It doesn’t feed style names — for `ital`, that usually means a whole-file Roman/Italic label for apps, while `slnt` (or another slope axis) owns the words in names."
    }

    private var registrationStopHelp: String {
        if isOutOfNaming {
            return "Whole-file label on this axis (e.g. this file is Italic). Kept in the font for apps; not added into composed style names."
        }
        return "This file’s shared value on this axis — used in every instance name, not as a per-style slider on the instance grid."
    }

    private var pinToggleHelp: String {
        if axis.isDesignRecordOnly {
            return "This naming axis still has an fvar entry. Unpin to return it to the instance grid; Pin keeps it off-grid as STAT-only."
        }
        return isInstanceAxis
            ? "Pin this axis at its default for every instance. Stops leave the instance grid."
            : "Unpin so stops on this axis generate named instances again."
    }

    private var pinToggleAccessibilityLabel: String {
        if axis.isDesignRecordOnly {
            return isInstanceAxis ? "Pin naming axis" : "Demote naming axis to instance grid"
        }
        return isInstanceAxis ? "Pin axis" : "Unpin axis"
    }

    private var stopCountBadge: some View {
        let count: Int
        let help: String
        let highlighted: Bool
        switch lane {
        case .registration:
            count = axis.values.count
            help = "\(count) STAT axis value\(count == 1 ? "" : "s") on this design axis"
            highlighted = count > 0
        case .variation:
            count = isInstanceAxis ? axis.values.count : 0
            help = isInstanceAxis
                ? "\(axis.values.count) stops in the instance grid formula"
                : "Not in the instance grid (contributes ×0)"
            highlighted = isInstanceAxis
        case .pinned:
            count = isInstanceAxis ? axis.values.count : 0
            help = isInstanceAxis
                ? "\(axis.values.count) stops in the instance grid formula"
                : "Pinned — fixed coordinate for all instances"
            highlighted = isInstanceAxis
        }
        return StudioCountBadge(
            text: "\(count)",
            highlighted: highlighted,
            fixedWidth: AxisBlockLayout.stopCountBadgeWidth,
            help: help
        )
    }

    private var axisRangeText: String? {
        guard let min = axis.min, let max = axis.max else { return nil }
        let minText = StudioFormatting.axisValue(min)
        let maxText = StudioFormatting.axisValue(max)
        if let defaultValue = axis.default {
            return "fvar \(minText) – \(StudioFormatting.axisValue(defaultValue)) – \(maxText)"
        }
        return "fvar \(minText) – \(maxText)"
    }

    private func commitDisplayName() {
        onUpdateDisplayName?(editedDisplayName)
        isEditingDisplayName = false
        displayNameFieldFocused = false
    }

    private func cancelDisplayName() {
        isEditingDisplayName = false
        displayNameFieldFocused = false
        editedDisplayName = currentDisplayName
    }
}

