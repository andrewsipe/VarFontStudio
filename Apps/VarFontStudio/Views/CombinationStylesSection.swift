import SwiftUI
import VarFontCore

enum CombinationStyleDefaults {
    /// Prefer custom / secondary axes for Format 4 legs; avoid weight as a default participant.
    static func suggestedAxisPair(from axes: [AxisDefinition]) -> (AxisDefinition, AxisDefinition)? {
        let instance = axes.filter { $0.role == .instance && $0.hasFvarScale }
        guard instance.count >= 2 else { return nil }
        let preferred = instance.filter { !CompoundStatNaming.standaloneNamingTags.contains($0.tag) }
        if preferred.count >= 2 {
            return (preferred[0], preferred[1])
        }
        if preferred.count == 1,
           let other = instance.first(where: { $0.tag != preferred[0].tag && $0.tag != "wght" })
            ?? instance.first(where: { $0.tag != preferred[0].tag }) {
            return (preferred[0], other)
        }
        let withoutWeight = instance.filter { $0.tag != "wght" }
        if withoutWeight.count >= 2 {
            return (withoutWeight[0], withoutWeight[1])
        }
        return (instance[0], instance[1])
    }

    static func suggestedValue(for axis: AxisDefinition) -> Double {
        if let max = axis.max, let def = axis.default, !AxisCoordinate.valuesEqual(max, def) {
            return max
        }
        if let min = axis.min, let def = axis.default, !AxisCoordinate.valuesEqual(min, def) {
            return min
        }
        return axis.default ?? axis.max ?? axis.min ?? 0
    }
}

/// Drawer body for Format 4 combination styles (header lives on the Axis Tree drawer chrome).
struct CombinationStylesSection: View {
    @EnvironmentObject private var editor: EditorViewModel

    let compounds: [CompoundStatValue]
    let axes: [AxisDefinition]

    @State private var isBuilderOpen = false
    @State private var builderLegs: [BuilderLeg] = []
    @State private var chainLocked = false
    @State private var nameText = ""
    @State private var nameEdited = false
    @State private var expandedCompoundID: String?
    @State private var openPicker: LegPicker?
    @State private var hoveredCompoundID: String?
    /// Draft custom value while editing an existing compound leg.
    @State private var editCustomDraft: Double = 0

    private struct BuilderLeg: Identifiable, Equatable {
        var id: UUID = UUID()
        var tag: String
        var value: Double
    }

    private struct LegPicker: Equatable {
        enum Kind: Equatable {
            case value
            case axis
            case addAxis
        }

        var compoundID: String
        var tag: String?
        var kind: Kind
    }

    private var axisByTag: [String: AxisDefinition] {
        Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
    }

    private var canAddCombination: Bool {
        instanceAxes.count >= 2
    }

    private var instanceAxes: [AxisDefinition] {
        axes.filter { $0.role == .instance && $0.hasFvarScale }
    }

    private var suggestions: [FvarStopSeeder.CompoundSuggestion] {
        editor.compoundSuggestionsForSelectedFont
    }

    private var builderCoords: [String: Double] {
        Dictionary(uniqueKeysWithValues: builderLegs.map { ($0.tag, $0.value) })
    }

    private var legsComplete: Bool {
        builderLegs.count >= 2
            && Set(builderLegs.map(\.tag)).count == builderLegs.count
            && builderLegs.allSatisfy { axisByTag[$0.tag] != nil }
    }

    private var canCommitBuilder: Bool {
        chainLocked
            && legsComplete
            && !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var availableAxesForNewLeg: [AxisDefinition] {
        let used = Set(builderLegs.map(\.tag))
        return instanceAxes.filter {
            !used.contains($0.tag) && !CompoundStatNaming.standaloneNamingTags.contains($0.tag)
        }
    }

    private var canAddLeg: Bool {
        !chainLocked && legsComplete && !availableAxesForNewLeg.isEmpty
    }

    private var coveredInstanceCount: Int {
        guard builderCoords.count >= 2,
              let plan = editor.instancePlan,
              plan.fontID == editor.selectedFontID
        else { return 0 }
        let probe = CompoundStatValue(
            id: "probe",
            coords: builderCoords,
            axisIndices: [],
            axisValues: [],
            name: "",
            elidable: false
        )
        return plan.instances.filter { CompoundStatNaming.matches(probe, coords: $0.coords) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            if !suggestions.isEmpty {
                suggestionsBanner
            }

            if compounds.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    ForEach(compounds) { compound in
                        compoundCard(compound)
                    }
                }
            }

            if canAddCombination {
                if isBuilderOpen {
                    inlineBuilder
                } else {
                    StudioFlatButton(
                        title: "Add combination",
                        systemImage: "plus",
                        size: .row,
                        help: "Create a Format 4 name at a multi-axis location"
                    ) {
                        openBuilder()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.top, StudioSpacing.controlGap)
        .padding(.bottom, StudioSpacing.panelVertical)
    }

    private var emptyState: some View {
        Text(canAddCombination
              ? "No combination styles yet. Add one when a name only applies at a multi-axis location."
              : "Need at least two instance axes to create a Format 4 combination.")
            .font(StudioTypography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Suggestions (value-forward)

    private var suggestionsBanner: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
                StudioSemanticDot(color: Color.secondary)
                VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
                    Text(suggestions.count == 1
                          ? "1 fvar name needs a combination"
                          : "\(suggestions.count) fvar names need combinations")
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Format 4 only — accept or dismiss.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding(StudioSpacing.controlGap)
        // Optional suggestions — neutral chrome only. Amber/yellow reserved for real issues.
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.surface))
    }

    private func suggestionCard(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        VStack(alignment: .leading, spacing: StudioSpace.x1_5) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                Text(suggestion.name)
                    .font(StudioTypography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text(suggestion.coveredInstanceCount == 1
                      ? "covers 1 of the original instances"
                      : "covers \(suggestion.coveredInstanceCount) of the original instances")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }

            valueForwardChain(coords: suggestion.coords, legLabels: suggestion.legLabels)

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer(minLength: 0)
                StudioFlatButton(
                    title: "Dismiss",
                    size: .compact,
                    help: "Dismiss this Format 4 suggestion"
                ) {
                    editor.dismissCompoundSuggestion(id: suggestion.id)
                }
                StudioFlatButton(
                    title: "Add",
                    role: .primary,
                    size: .compact,
                    help: "Add this combination style"
                ) {
                    editor.acceptCompoundSuggestion(suggestion)
                }
            }
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpacing.controlGap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.control))
    }

    private func valueForwardChain(
        coords: [String: Double],
        legLabels: [String: String] = [:]
    ) -> some View {
        let tags = orderedTags(Set(coords.keys))
        return HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                }
                valueForwardChip(
                    tag: tag,
                    value: coords[tag] ?? 0,
                    stopName: legLabels[tag]
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueForwardChip(tag: String, value: Double, stopName: String? = nil) -> some View {
        let formatted = StudioFormatting.axisValue(value)
        let helpText: String = {
            guard let stopName else { return "\(formatted) on \(axisLabel(for: tag))" }
            let trimmed = stopName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == formatted {
                return "\(formatted) on \(axisLabel(for: tag))"
            }
            return "\(formatted) on \(axisLabel(for: tag)) · \(trimmed)"
        }()

        return HStack(spacing: StudioSpacing.tightGap) {
            Text(formatted)
                .font(StudioTypography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(axisLabel(for: tag))
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
        .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.chip))
        .overlay {
            RoundedRectangle.studio(StudioRadius.chip)
                .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(helpText)
    }

    // MARK: - Compound cards (collapsed summary / expanded editor)

    private func compoundCard(_ compound: CompoundStatValue) -> some View {
        let isExpanded = expandedCompoundID == compound.id
        let isHovered = hoveredCompoundID == compound.id

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: StudioSpacing.controlGap) {
                Button {
                    if isExpanded {
                        expandedCompoundID = nil
                        openPicker = nil
                    } else {
                        expandedCompoundID = compound.id
                        openPicker = nil
                    }
                } label: {
                    HStack(spacing: StudioSpacing.tightGap) {
                        StudioDisclosureChevron(isExpanded: isExpanded)

                        StudioStatFormatBadge(format: 4)

                        Text(compound.name.isEmpty ? "Untitled" : compound.name)
                            .font(StudioTypography.caption.weight(.semibold))
                            .foregroundStyle(StudioColors.statFormat1)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: StudioSpace.x0_5) {
                    Text("Elided")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)

                    StudioElidableRadio(
                        isOn: compound.elidable,
                        helpText: compound.elidable
                            ? "Clear elided — include this combination name when composing"
                            : "Mark elided — omit this combination name when it is the default choice"
                    ) {
                        editor.updateCompoundStatElidable(id: compound.id, elidable: !compound.elidable)
                    }
                    .frame(width: 16, height: StudioFieldMetrics.toolbarIconHitSize)
                }

                // Always reserve the remove slot so Elided doesn't shift on hover.
                ZStack {
                    if isHovered || isExpanded {
                        StudioDismissButton(scale: .chip, style: .fill, help: "Remove combination") {
                            editor.removeCompoundStatValue(id: compound.id)
                            if expandedCompoundID == compound.id {
                                expandedCompoundID = nil
                            }
                        }
                    }
                }
                .frame(width: StudioChromeScale.chip.hitSize, height: StudioChromeScale.chip.hitSize)
            }
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioSpacing.controlGap)
            .onHover { hovering in
                hoveredCompoundID = hovering ? compound.id : (hoveredCompoundID == compound.id ? nil : hoveredCompoundID)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    StudioTextField(
                        placeholder: "Name",
                        text: Binding(
                            get: { compound.name },
                            set: { editor.updateCompoundStatName(id: compound.id, name: $0) }
                        ),
                        font: StudioTypography.bodyMedium,
                        rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                        filledForeground: .primary
                    )

                    editLegs(compound)

                    if let picker = openPicker, picker.compoundID == compound.id {
                        inlinePicker(for: compound, picker: picker)
                    }
                }
                .padding(.leading, StudioSpace.x6)
                .padding(.trailing, StudioSpacing.contentInset)
                .padding(.bottom, StudioSpacing.controlGap)
            }
        }
        .background(
            isExpanded ? StudioColors.surfaceInset : StudioColors.surfaceSubtle,
            in: RoundedRectangle.studio(StudioRadius.surface)
        )
        .overlay {
            RoundedRectangle.studio(StudioRadius.surface)
                .strokeBorder(
                    isExpanded ? StudioColors.surfaceStrokeStrong : StudioColors.surfaceStroke,
                    lineWidth: StudioStroke.hairline
                )
        }
    }

    private func editLegs(_ compound: CompoundStatValue) -> some View {
        let tags = orderedLegTags(for: compound)
        return HStack(alignment: .center, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    togglePicker(LegPicker(compoundID: compound.id, tag: tag, kind: .value))
                } label: {
                    Text(StudioFormatting.axisValue(compound.coords[tag] ?? 0))
                        .font(StudioTypography.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, StudioSpacing.contentInset)
                        .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                        .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.chip))
                        .overlay {
                            RoundedRectangle.studio(StudioRadius.chip)
                                .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
                        }
                }
                .buttonStyle(.plain)

                Button {
                    togglePicker(LegPicker(compoundID: compound.id, tag: tag, kind: .axis))
                } label: {
                    HStack(spacing: StudioSpace.x0_5) {
                        Text(axisLabel(for: tag))
                            .font(StudioTypography.caption)
                        Image(systemName: "chevron.down")
                            .font(StudioTypography.iconGlyph)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, StudioSpacing.tightGap)
                    .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                    .overlay {
                        RoundedRectangle.studio(StudioRadius.chip)
                            .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: StudioStroke.hairline)
                    }
                }
                .buttonStyle(.plain)

                if compound.coords.count > 2 {
                    StudioDismissButton(scale: .chip, style: .fill, help: "Remove axis") {
                        editor.removeCompoundStatLeg(id: compound.id, tag: tag)
                    }
                }
            }

            if !addableAxes(for: compound).isEmpty {
                StudioFlatButton(
                    title: "Add axis",
                    systemImage: "plus",
                    size: .compact,
                    help: "Add another axis leg to this combination"
                ) {
                    togglePicker(LegPicker(compoundID: compound.id, tag: nil, kind: .addAxis))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlinePicker(for compound: CompoundStatValue, picker: LegPicker) -> some View {
        Group {
            switch picker.kind {
            case .value:
                if let tag = picker.tag, let axis = axisByTag[tag] {
                    valueStopPicker(compound: compound, tag: tag, axis: axis)
                }
            case .axis:
                if let tag = picker.tag {
                    axisSwapPicker(compound: compound, currentTag: tag)
                }
            case .addAxis:
                addAxisPicker(compound: compound)
            }
        }
    }

    private func valueStopPicker(compound: CompoundStatValue, tag: String, axis: AxisDefinition) -> some View {
        let current = compound.coords[tag] ?? 0
        return inlinePickerChrome(title: "\(axisLabel(for: tag)) value") {
            VStack(alignment: .leading, spacing: StudioSpace.x1_5) {
                if !axis.values.isEmpty {
                    HStack(spacing: StudioSpace.x1) {
                        ForEach(axis.values) { stop in
                            let selected = AxisCoordinate.valuesEqual(stop.value, current)
                            Button {
                                editor.updateCompoundStatCoordinate(id: compound.id, tag: tag, value: stop.value)
                                openPicker = nil
                            } label: {
                                stopOptionChip(stop: stop, selected: selected)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: StudioSpacing.controlGap) {
                    Text("Custom")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                    StudioBoundNumberField(
                        value: $editCustomDraft,
                        rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                        alignment: .leading,
                        onSubmit: {
                            let clamped = clampedValue(editCustomDraft, for: axis)
                            editor.updateCompoundStatCoordinate(id: compound.id, tag: tag, value: clamped)
                            openPicker = nil
                        }
                    )
                    .frame(width: 88)
                    if let min = axis.min, let max = axis.max {
                        Text("\(StudioFormatting.axisValue(min))–\(StudioFormatting.axisValue(max))")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    StudioFlatButton(title: "Set", size: .compact, help: "Use this custom value") {
                        let clamped = clampedValue(editCustomDraft, for: axis)
                        editor.updateCompoundStatCoordinate(id: compound.id, tag: tag, value: clamped)
                        openPicker = nil
                    }
                }
            }
            .onAppear { editCustomDraft = current }
        }
    }

    private func axisSwapPicker(compound: CompoundStatValue, currentTag: String) -> some View {
        inlinePickerChrome(title: "Swap axis") {
            HStack(spacing: StudioSpace.x1) {
                ForEach(swappableAxes(for: compound, currentTag: currentTag), id: \.tag) { axis in
                    Button {
                        replaceLeg(compoundID: compound.id, from: currentTag, to: axis.tag)
                    } label: {
                        axisOptionChip(axis: axis, isCurrent: axis.tag == currentTag)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addAxisPicker(compound: CompoundStatValue) -> some View {
        inlinePickerChrome(title: "Add axis") {
            HStack(spacing: StudioSpace.x1) {
                ForEach(addableAxes(for: compound), id: \.tag) { axis in
                    Button {
                        editor.addCompoundStatLeg(id: compound.id, tag: axis.tag)
                        openPicker = nil
                    } label: {
                        axisOptionChip(axis: axis, isCurrent: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func inlinePickerChrome<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: StudioSpace.x1) {
            Text(title)
                .font(StudioTypography.columnLabel)
                .foregroundStyle(.tertiary)
            content()
        }
        .padding(StudioSpacing.contentInset)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.surface))
        .overlay {
            RoundedRectangle.studio(StudioRadius.surface)
                .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
        }
    }

    private func stopOptionChip(stop: AxisValue, selected: Bool) -> some View {
        let name = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: StudioSpacing.tightGap) {
            Text(StudioFormatting.axisValue(stop.value))
                .font(StudioTypography.caption.weight(.semibold))
                .monospacedDigit()
            if !name.isEmpty, name != StudioFormatting.axisValue(stop.value) {
                Text(name)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(selected ? .primary : .secondary)
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
        .background {
            RoundedRectangle.studio(StudioRadius.chip)
                .fill(selected ? StudioColors.surfaceInset : StudioColors.surfaceMuted)
        }
        .overlay {
            RoundedRectangle.studio(StudioRadius.chip)
                .strokeBorder(
                    selected ? StudioColors.surfaceStrokeStrong : StudioColors.surfaceStroke,
                    lineWidth: StudioStroke.hairline
                )
        }
    }

    private func axisOptionChip(axis: AxisDefinition, isCurrent: Bool) -> some View {
        Text(axis.displayName ?? axis.tag)
            .font(StudioTypography.caption.weight(isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? .primary : .secondary)
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
            .background {
                RoundedRectangle.studio(StudioRadius.chip)
                    .fill(isCurrent ? StudioColors.surfaceInset : StudioColors.surfaceMuted)
            }
            .overlay {
                RoundedRectangle.studio(StudioRadius.chip)
                    .strokeBorder(
                        isCurrent ? StudioColors.surfaceStrokeStrong : StudioColors.surfaceStroke,
                        lineWidth: StudioStroke.hairline
                    )
            }
    }

    private func togglePicker(_ picker: LegPicker) {
        if openPicker == picker {
            openPicker = nil
        } else {
            openPicker = picker
            expandedCompoundID = picker.compoundID
        }
    }

    private func orderedLegTags(for compound: CompoundStatValue) -> [String] {
        orderedTags(Set(compound.coords.keys))
    }

    private func orderedTags(_ present: Set<String>) -> [String] {
        let treeOrder = axes.map(\.tag).filter { present.contains($0) }
        let leftovers = present.subtracting(treeOrder).sorted()
        return treeOrder + leftovers
    }

    private func axisLabel(for tag: String) -> String {
        axisByTag[tag]?.displayName ?? tag
    }

    private func addableAxes(for compound: CompoundStatValue) -> [AxisDefinition] {
        instanceAxes.filter {
            compound.coords[$0.tag] == nil
                && !CompoundStatNaming.standaloneNamingTags.contains($0.tag)
        }
    }

    private func swappableAxes(for compound: CompoundStatValue, currentTag: String) -> [AxisDefinition] {
        instanceAxes.filter {
            ($0.tag == currentTag || compound.coords[$0.tag] == nil)
                && !CompoundStatNaming.standaloneNamingTags.contains($0.tag)
        }
    }

    private func replaceLeg(compoundID: String, from oldTag: String, to newTag: String) {
        guard oldTag != newTag,
              let axis = axisByTag[newTag] else { return }
        editor.replaceCompoundStatLeg(
            id: compoundID,
            oldTag: oldTag,
            newTag: newTag,
            value: CombinationStyleDefaults.suggestedValue(for: axis)
        )
        openPicker = nil
    }

    // MARK: - Inline builder (leg chain)

    private func openBuilder() {
        isBuilderOpen = true
        chainLocked = false
        nameEdited = false
        nameText = ""
        builderLegs = seedInitialLegs()
    }

    private func closeBuilder() {
        isBuilderOpen = false
        builderLegs = []
        chainLocked = false
        nameText = ""
        nameEdited = false
    }

    private func seedInitialLegs() -> [BuilderLeg] {
        let pair: (AxisDefinition, AxisDefinition)?
        if let suggested = CombinationStyleDefaults.suggestedAxisPair(from: axes) {
            pair = suggested
        } else if instanceAxes.count >= 2 {
            pair = (instanceAxes[0], instanceAxes[1])
        } else {
            pair = nil
        }
        guard let pair else { return [] }
        return [
            BuilderLeg(tag: pair.0.tag, value: CombinationStyleDefaults.suggestedValue(for: pair.0)),
            BuilderLeg(tag: pair.1.tag, value: CombinationStyleDefaults.suggestedValue(for: pair.1)),
        ]
    }

    private var inlineBuilder: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            Text("Name a multi-axis location. Use existing stops or any value in range — combo-only values don’t need a Format 1 stop and don’t grow the instance grid.")
                .font(StudioTypography.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Chain")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(.tertiary)

            if chainLocked {
                lockedChainSummary
            } else {
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    ForEach(Array(builderLegs.enumerated()), id: \.element.id) { index, leg in
                        builderLegRow(leg, index: index)
                    }
                }

                HStack(spacing: StudioSpacing.controlGap) {
                    Button {
                        addBuilderLeg()
                    } label: {
                        Image(systemName: "plus")
                            .font(StudioTypography.iconGlyph)
                            .foregroundStyle(canAddLeg ? .primary : .tertiary)
                            .frame(width: StudioChromeScale.chip.hitSize, height: StudioChromeScale.chip.hitSize)
                            .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.chip))
                            .overlay {
                                RoundedRectangle.studio(StudioRadius.chip)
                                    .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddLeg)
                    .help(canAddLeg ? "Add another axis + value" : "Need two complete legs and another unused axis")

                    Button {
                        chainLocked = true
                    } label: {
                        Image(systemName: "lock.open")
                            .font(StudioTypography.iconGlyph)
                            .foregroundStyle(legsComplete ? .primary : .tertiary)
                            .frame(width: StudioChromeScale.chip.hitSize, height: StudioChromeScale.chip.hitSize)
                            .background(
                                legsComplete ? StudioColors.surfaceInset : StudioColors.surfaceMuted,
                                in: RoundedRectangle.studio(StudioRadius.chip)
                            )
                            .overlay {
                                RoundedRectangle.studio(StudioRadius.chip)
                                    .strokeBorder(
                                        legsComplete ? StudioColors.surfaceStrokeStrong : StudioColors.surfaceStroke,
                                        lineWidth: StudioStroke.hairline
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!legsComplete)
                    .help(legsComplete ? "Lock chain and name this Format 4 stop" : "Set at least two axis + value legs first")

                    Spacer(minLength: 0)
                }
            }

            if chainLocked {
                StudioTextField(
                    placeholder: "Name this Format 4 stop",
                    text: Binding(
                        get: { nameText },
                        set: { newValue in
                            nameText = newValue
                            nameEdited = true
                        }
                    ),
                    rowHeight: StudioFieldMetrics.bodyRowHeight
                )

                Text(coveredInstanceCount == 1
                      ? "Would cover 1 instance in the current grid — doesn’t grow the grid."
                      : "Would cover \(coveredInstanceCount) instances in the current grid — doesn’t grow the grid.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel", size: .compact) {
                    closeBuilder()
                }
                if chainLocked {
                    StudioFlatButton(title: "Add", role: .primary, size: .compact, isEnabled: canCommitBuilder) {
                        commitBuilder()
                    }
                }
            }
        }
        .padding(StudioSpacing.controlGap)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.surface))
        .overlay {
            RoundedRectangle.studio(StudioRadius.surface)
                .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
        }
    }

    private var lockedChainSummary: some View {
        HStack(alignment: .center, spacing: StudioSpace.x1) {
            Image(systemName: "lock.fill")
                .font(StudioTypography.iconGlyph)
                .foregroundStyle(.secondary)
                .help("Chain locked — unlock to edit legs")

            ForEach(Array(builderLegs.enumerated()), id: \.element.id) { index, leg in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: StudioSpacing.tightGap) {
                    Text(StudioFormatting.axisValue(leg.value))
                        .font(StudioTypography.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(axisLabel(for: leg.tag))
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.chip))
                .overlay {
                    RoundedRectangle.studio(StudioRadius.chip)
                        .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: StudioStroke.hairline)
                }
            }

            Spacer(minLength: 0)

            Button {
                chainLocked = false
            } label: {
                Text("Unlock")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit axis + value legs")
        }
        .padding(StudioSpacing.contentInset)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.surface))
        .overlay {
            RoundedRectangle.studio(StudioRadius.surface)
                .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
        }
    }

    private func builderLegRow(_ leg: BuilderLeg, index: Int) -> some View {
        let axis = axisByTag[leg.tag]
        let stops = axis?.values ?? []
        return VStack(alignment: .leading, spacing: StudioSpace.x1) {
            HStack(spacing: StudioSpacing.controlGap) {
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, alignment: .center)
                } else {
                    Color.clear.frame(width: 12)
                }

                StudioBoundNumberField(
                    value: Binding(
                        get: { builderLegs[safe: index]?.value ?? leg.value },
                        set: { setBuilderValue(at: index, value: $0) }
                    ),
                    rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                    alignment: .leading
                )
                .frame(width: 72)

                axisMenu(for: index, currentTag: leg.tag)

                if let axis, let min = axis.min, let max = axis.max {
                    Text("\(StudioFormatting.axisValue(min))–\(StudioFormatting.axisValue(max))")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                if builderLegs.count > 2 {
                    StudioDismissButton(scale: .chip, style: .fill, help: "Remove this leg") {
                        removeBuilderLeg(at: index)
                    }
                }
            }

            if !stops.isEmpty {
                HStack(spacing: StudioSpace.x1) {
                    ForEach(stops) { stop in
                        let selected = AxisCoordinate.valuesEqual(stop.value, leg.value)
                        Button {
                            setBuilderValue(at: index, value: stop.value)
                        } label: {
                            stopOptionChip(stop: stop, selected: selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12 + StudioSpacing.controlGap)
            }
        }
    }

    private func axisMenu(for index: Int, currentTag: String) -> some View {
        let options = axisOptions(for: currentTag)
        return Menu {
            ForEach(options, id: \.tag) { axis in
                Button {
                    setBuilderAxis(at: index, tag: axis.tag)
                } label: {
                    if axis.tag == currentTag {
                        Label(axis.displayName ?? axis.tag, systemImage: "checkmark")
                    } else {
                        Text(axis.displayName ?? axis.tag)
                    }
                }
            }
        } label: {
            HStack(spacing: StudioSpace.x0_5) {
                Text(axisLabel(for: currentTag))
                    .font(StudioTypography.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(StudioTypography.iconGlyph)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
            .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.chip))
            .overlay {
                RoundedRectangle.studio(StudioRadius.chip)
                    .strokeBorder(StudioColors.surfaceStroke, lineWidth: StudioStroke.hairline)
            }
        }
        .menuStyle(.borderlessButton)
        .help("Choose axis for this leg")
    }

    private func axisOptions(for currentTag: String) -> [AxisDefinition] {
        let used = Set(builderLegs.map(\.tag))
        return instanceAxes.filter { axis in
            if axis.tag == currentTag { return true }
            if used.contains(axis.tag) { return false }
            return !CompoundStatNaming.standaloneNamingTags.contains(axis.tag)
        }
    }

    private func addBuilderLeg() {
        guard canAddLeg, let next = availableAxesForNewLeg.first else { return }
        builderLegs.append(
            BuilderLeg(tag: next.tag, value: CombinationStyleDefaults.suggestedValue(for: next))
        )
    }

    private func removeBuilderLeg(at index: Int) {
        guard builderLegs.count > 2, builderLegs.indices.contains(index) else { return }
        builderLegs.remove(at: index)
    }

    private func setBuilderValue(at index: Int, value: Double) {
        guard builderLegs.indices.contains(index) else { return }
        let tag = builderLegs[index].tag
        if let axis = axisByTag[tag] {
            builderLegs[index].value = clampedValue(value, for: axis)
        } else {
            builderLegs[index].value = AxisCoordinateFormat.canonical(value)
        }
    }

    private func setBuilderAxis(at index: Int, tag: String) {
        guard builderLegs.indices.contains(index),
              let axis = axisByTag[tag],
              builderLegs[index].tag != tag else { return }
        guard !builderLegs.contains(where: { $0.tag == tag }) else { return }
        builderLegs[index].tag = tag
        builderLegs[index].value = CombinationStyleDefaults.suggestedValue(for: axis)
    }

    private func clampedValue(_ value: Double, for axis: AxisDefinition) -> Double {
        var result = AxisCoordinateFormat.canonical(value)
        if let min = axis.min {
            result = max(result, min)
        }
        if let max = axis.max {
            result = min(result, max)
        }
        return AxisCoordinateFormat.canonical(result)
    }

    private func commitBuilder() {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCommitBuilder, !trimmed.isEmpty else { return }
        editor.addCompoundStatValue(name: trimmed, coords: builderCoords)
        closeBuilder()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
