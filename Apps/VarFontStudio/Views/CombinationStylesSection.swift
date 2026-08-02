import SwiftUI
import VarFontCore

/// Axes that usually carry their own Format 1 names — prefer other axes for Format 4 legs.
private let preferredStandaloneNamingTags: Set<String> = [
    "wght", "wdth", "opsz", "ital", "slnt", "GRAD",
]

enum CombinationStyleDefaults {
    /// Prefer custom / secondary axes for Format 4 legs; avoid weight as a default participant.
    static func suggestedAxisPair(from axes: [AxisDefinition]) -> (AxisDefinition, AxisDefinition)? {
        let instance = axes.filter { $0.role == .instance && $0.hasFvarScale }
        guard instance.count >= 2 else { return nil }
        let preferred = instance.filter { !preferredStandaloneNamingTags.contains($0.tag) }
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

struct CombinationStylesSection: View {
    @EnvironmentObject private var editor: EditorViewModel

    let compounds: [CompoundStatValue]
    let axes: [AxisDefinition]

    @State private var isExpanded = true
    @State private var isBuilderOpen = false
    @State private var pickedTags: [String] = []
    @State private var pickedStops: [String: AxisValue] = [:]
    @State private var nameText = ""
    @State private var nameEdited = false
    @State private var editingLeg: (compoundID: String, tag: String)?
    @State private var legDraft = ""
    @State private var hoveredCompoundID: String?

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
        Dictionary(uniqueKeysWithValues: pickedStops.map { ($0.key, $0.value.value) })
    }

    private var canCommitBuilder: Bool {
        !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && pickedStops.count >= 2
            && pickedStops.count == pickedTags.count
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
            disclosureHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    if !suggestions.isEmpty {
                        suggestionsBanner
                    }

                    if compounds.isEmpty {
                        emptyState
                    } else {
                        ForEach(compounds) { compound in
                            compoundBlock(compound)
                        }
                    }

                    if canAddCombination {
                        if isBuilderOpen {
                            inlineBuilder
                                .padding(.leading, StopTableLayout.stopIndentWidth)
                        } else {
                            Button {
                                openBuilder()
                            } label: {
                                Label("Add combination", systemImage: "plus")
                                    .font(StudioTypography.caption)
                            }
                            .buttonStyle(StudioLinkButtonStyle(linkStyle: .accent))
                            .padding(.leading, StopTableLayout.stopIndentWidth)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var disclosureHeader: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: StudioSpacing.controlGap) {
                StudioNestedDisclosureChevron(isExpanded: isExpanded)
                Text("Combination styles")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                Text("\(compounds.count) preset\(compounds.count == 1 ? "" : "s") · format 4")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
            }
            .frame(height: StudioFieldMetrics.disclosureLabelRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.row))
        .help("Named multi-axis points in STAT. They do not multiply the instance grid.")
    }

    private var emptyState: some View {
        Text(canAddCombination
              ? "No combination styles yet. Add one when a name only applies at a multi-axis location."
              : "Need at least two instance axes to create a Format 4 combination.")
            .font(StudioTypography.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, StopTableLayout.stopIndentWidth)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Suggestions

    private var suggestionsBanner: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
                StudioSemanticDot(color: StudioColors.warningForeground)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestions.count == 1
                          ? "1 fvar name needs a combination"
                          : "\(suggestions.count) fvar names need combinations")
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(StudioColors.warningForeground)
                    Text("Format 4 only — accept or dismiss.")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(suggestions) { suggestion in
                suggestionCard(suggestion)
            }
        }
        .padding(StudioSpacing.controlGap)
        .background(StudioColors.warningFill, in: RoundedRectangle(cornerRadius: StudioRadius.row))
        .padding(.leading, StopTableLayout.stopIndentWidth)
    }

    /// Stacked card: name → legs chain → actions. Axis Tree is too narrow for one-row chains.
    private func suggestionCard(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        VStack(alignment: .leading, spacing: StudioSpace.x1) {
            Text(suggestion.name)
                .font(StudioTypography.bodyMedium.weight(.semibold))
                .foregroundStyle(StudioColors.registrationForeground)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            suggestionLegs(suggestion)

            HStack(spacing: StudioSpacing.controlGap) {
                Text("covers \(suggestion.coveredInstanceCount) fvar")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button("Dismiss") {
                    editor.dismissCompoundSuggestion(id: suggestion.id)
                }
                .buttonStyle(StudioLinkButtonStyle(linkStyle: .secondary))
                Button("Add") {
                    editor.acceptCompoundSuggestion(suggestion)
                }
                .buttonStyle(StudioLinkButtonStyle(linkStyle: .accent))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: StudioRadius.control))
    }

    private func suggestionLegs(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        let tags = orderedTags(Set(suggestion.coords.keys))
        return HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text(tag)
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.tertiary)
                    Text(suggestion.legLabels[tag] ?? AxisCoordinateFormat.format(suggestion.coords[tag] ?? 0))
                        .font(StudioTypography.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Existing compounds

    private func compoundBlock(_ compound: CompoundStatValue) -> some View {
        let isHovered = hoveredCompoundID == compound.id
        return VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
            HStack(spacing: 0) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                StudioElidableSwitch(isOn: compound.elidable) {
                    editor.updateCompoundStatElidable(id: compound.id, elidable: !compound.elidable)
                }
                .frame(width: StopTableLayout.elidableWidth)
                .padding(.leading, StopTableLayout.elidableGap)

                ZStack {
                    if isHovered {
                        StudioDismissButton(scale: .chip, style: .fill, help: "Remove combination") {
                            editor.removeCompoundStatValue(id: compound.id)
                        }
                    }
                }
                .frame(width: AxisBlockLayout.removeSlotWidth)
                .padding(.leading, AxisBlockLayout.removeSlotLeadingGap)
            }
            .padding(.horizontal, StopTableLayout.rowHorizontalPadding)
            .frame(minHeight: StudioFieldMetrics.listRowMinHeight)
            .background {
                StudioRowBackground(isSelected: false, isHovered: isHovered)
            }
            .onHover { hovering in
                hoveredCompoundID = hovering ? compound.id : (hoveredCompoundID == compound.id ? nil : hoveredCompoundID)
            }

            compoundLegs(compound)
                .padding(.leading, StopTableLayout.stopIndentWidth)
                .padding(.horizontal, StopTableLayout.rowHorizontalPadding)
        }
    }

    private func compoundLegs(_ compound: CompoundStatValue) -> some View {
        let tags = orderedLegTags(for: compound)
        return HStack(spacing: StudioSpacing.rowGap) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                }
                legChip(compound: compound, tag: tag)
            }

            if !addableAxes(for: compound).isEmpty {
                Menu {
                    ForEach(addableAxes(for: compound), id: \.tag) { axis in
                        Button(axis.displayName ?? axis.tag) {
                            editor.addCompoundStatLeg(id: compound.id, tag: axis.tag)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Add axis")
            }
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

    private func addableAxes(for compound: CompoundStatValue) -> [AxisDefinition] {
        instanceAxes.filter { compound.coords[$0.tag] == nil }
    }

    private func stopLabel(for tag: String, value: Double) -> String {
        if let axis = axisByTag[tag],
           let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) {
            let name = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        return StudioFormatting.axisValue(value)
    }

    @ViewBuilder
    private func legChip(compound: CompoundStatValue, tag: String) -> some View {
        let value = compound.coords[tag] ?? 0
        let missingAxis = axisByTag[tag] == nil
        let isEditing = editingLeg?.compoundID == compound.id && editingLeg?.tag == tag
        let swappable = swappableAxes(for: compound, currentTag: tag)
        let label = stopLabel(for: tag, value: value)

        if isEditing {
            HStack(spacing: StudioSpace.x0_5) {
                Text(tag)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
                Text("=")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
                StudioInlineTextField(
                    placeholder: "Value",
                    text: $legDraft,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.monoValueRowHeight,
                    alignment: .trailing,
                    onSubmit: { commitLegEdit(compoundID: compound.id, tag: tag) },
                    onCancel: { editingLeg = nil }
                )
                .frame(width: AxisBlockLayout.inlineValueEditWidth)
            }
            .onAppear { legDraft = StudioFormatting.axisValue(value) }
        } else {
            HStack(spacing: StudioSpace.x0_5) {
                Menu {
                    ForEach(swappable, id: \.tag) { axis in
                        Button(axis.displayName ?? axis.tag) {
                            replaceLeg(compoundID: compound.id, from: tag, to: axis.tag)
                        }
                    }
                } label: {
                    HStack(spacing: StudioSpace.x0_5) {
                        if missingAxis {
                            StudioSemanticDot(color: StudioColors.warningForeground)
                        }
                        Text(tag)
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(missingAxis ? .primary : .tertiary)
                            .padding(.horizontal, missingAxis ? 4 : 0)
                            .padding(.vertical, missingAxis ? 1 : 0)
                            .background {
                                if missingAxis {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(StudioColors.warningFill)
                                }
                            }
                    }
                }
                .menuStyle(.borderlessButton)
                .disabled(swappable.isEmpty)

                Button {
                    editingLeg = (compound.id, tag)
                    legDraft = StudioFormatting.axisValue(value)
                } label: {
                    Text(label)
                        .font(StudioTypography.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
                .help("Value \(StudioFormatting.axisValue(value)) — click to edit")

                if compound.coords.count > 2 {
                    StudioDismissButton(scale: .chip, style: .fill, help: "Remove axis") {
                        editor.removeCompoundStatLeg(id: compound.id, tag: tag)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: StudioRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: StudioRadius.control)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func swappableAxes(for compound: CompoundStatValue, currentTag: String) -> [AxisDefinition] {
        instanceAxes.filter { $0.tag == currentTag || compound.coords[$0.tag] == nil }
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
    }

    private func commitLegEdit(compoundID: String, tag: String) {
        guard let value = Double(legDraft.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            editingLeg = nil
            return
        }
        editor.updateCompoundStatCoordinate(id: compoundID, tag: tag, value: value)
        editingLeg = nil
    }

    // MARK: - Inline builder

    private func openBuilder() {
        isExpanded = true
        isBuilderOpen = true
        nameEdited = false
        nameText = ""
        pickedStops = [:]
        if let pair = CombinationStyleDefaults.suggestedAxisPair(from: axes) {
            pickedTags = [pair.0.tag, pair.1.tag]
        } else {
            pickedTags = Array(instanceAxes.prefix(2).map(\.tag))
        }
    }

    private func closeBuilder() {
        isBuilderOpen = false
        pickedTags = []
        pickedStops = [:]
        nameText = ""
        nameEdited = false
    }

    private var inlineBuilder: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            Text("Format 4 — one name for a multi-axis location. Pick stops that already exist on each axis; nothing here adds an axis or grows the instance grid.")
                .font(StudioTypography.meta)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Axes to combine")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(.tertiary)

            axisPills

            if !pickedTags.isEmpty {
                Text("Stops")
                    .font(StudioTypography.columnLabel)
                    .foregroundStyle(.tertiary)
                    .padding(.top, StudioSpace.x0_5)

                ForEach(pickedTags, id: \.self) { tag in
                    stopLane(for: tag)
                }
            }

            Text("Chain")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(.tertiary)
                .padding(.top, StudioSpace.x0_5)

            chainPreview

            StudioTextField(
                placeholder: "Name",
                text: Binding(
                    get: { nameText },
                    set: { newValue in
                        nameText = newValue
                        nameEdited = true
                    }
                ),
                rowHeight: StudioFieldMetrics.bodyRowHeight
            )

            if pickedStops.count >= 2 {
                Text("Applies at this exact intersection · covers \(coveredInstanceCount) generated instance\(coveredInstanceCount == 1 ? "" : "s") — doesn’t add an axis or grow the grid.")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel", size: .compact) {
                    closeBuilder()
                }
                StudioFlatButton(title: "Add", role: .primary, size: .compact, isEnabled: canCommitBuilder) {
                    commitBuilder()
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.row))
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.row)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private var axisPills: some View {
        HStack(spacing: StudioSpace.x1) {
            ForEach(instanceAxes, id: \.tag) { axis in
                let isPicked = pickedTags.contains(axis.tag)
                let isStandalone = preferredStandaloneNamingTags.contains(axis.tag)
                Button {
                    toggleAxis(axis.tag)
                } label: {
                    HStack(spacing: 4) {
                        Text(axis.displayName ?? axis.tag)
                            .font(StudioTypography.caption)
                        Text(axis.tag)
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(isPicked ? StudioColors.selectionFill : Color.clear)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                isPicked ? StudioColors.brand.opacity(0.45) : Color.primary.opacity(0.12),
                                lineWidth: 1
                            )
                    }
                    .opacity(isStandalone && !isPicked ? 0.45 : 1)
                }
                .buttonStyle(.plain)
                .help(isStandalone
                      ? "\(axis.displayName ?? axis.tag) usually carries its own Format 1 names"
                      : "Include \(axis.displayName ?? axis.tag)")
            }
        }
    }

    private func stopLane(for tag: String) -> some View {
        let axis = axisByTag[tag]
        let stops = axis?.values ?? []
        return VStack(alignment: .leading, spacing: StudioSpace.x1) {
            HStack(spacing: 6) {
                Text(axis?.displayName ?? tag)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                Text(tag)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
            }

            if stops.isEmpty {
                Text("No stops on this axis yet")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: StudioSpace.x1) {
                    ForEach(stops) { stop in
                        let selected = pickedStops[tag]?.id == stop.id
                            || (pickedStops[tag].map { AxisCoordinate.valuesEqual($0.value, stop.value) } ?? false)
                        Button {
                            selectStop(tag: tag, stop: stop)
                        } label: {
                            Text(stopDisplayName(stop))
                                .font(StudioTypography.caption.weight(selected ? .medium : .regular))
                                .foregroundStyle(selected ? .primary : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    RoundedRectangle(cornerRadius: StudioRadius.control)
                                        .fill(selected ? StudioColors.selectionFill : Color.primary.opacity(0.02))
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: StudioRadius.control)
                                        .strokeBorder(
                                            selected ? StudioColors.brand.opacity(0.45) : Color.primary.opacity(0.12),
                                            lineWidth: 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var chainPreview: some View {
        let complete = pickedTags.compactMap { tag -> (String, AxisValue)? in
            guard let stop = pickedStops[tag] else { return nil }
            return (tag, stop)
        }

        return Group {
            if complete.count < 2 {
                Text("Pick a stop on at least two axes")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: StudioRadius.control)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                    }
            } else {
                HStack(spacing: StudioSpace.x1) {
                    ForEach(Array(complete.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Text("+")
                                .font(StudioTypography.caption)
                                .foregroundStyle(StudioColors.brand.opacity(0.7))
                        }
                        HStack(spacing: StudioSpace.x0_5) {
                            Text(item.0)
                                .font(StudioTypography.monoMeta)
                                .foregroundStyle(.tertiary)
                            Text(stopDisplayName(item.1))
                                .font(StudioTypography.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(StudioColors.selectionFill, in: RoundedRectangle(cornerRadius: StudioRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: StudioRadius.control)
                                .strokeBorder(StudioColors.brand.opacity(0.45), lineWidth: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.control))
            }
        }
        .onChange(of: pickedStops.map { "\($0.key):\($0.value.id)" }.sorted().joined()) { _, _ in
            refreshSuggestedName()
        }
    }

    private func stopDisplayName(_ stop: AxisValue) -> String {
        let name = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? StudioFormatting.axisValue(stop.value) : name
    }

    private func toggleAxis(_ tag: String) {
        if let index = pickedTags.firstIndex(of: tag) {
            pickedTags.remove(at: index)
            pickedStops.removeValue(forKey: tag)
        } else {
            pickedTags.append(tag)
        }
        refreshSuggestedName()
    }

    private func selectStop(tag: String, stop: AxisValue) {
        pickedStops[tag] = stop
        refreshSuggestedName()
    }

    private func refreshSuggestedName() {
        guard !nameEdited else { return }
        let labels = pickedTags.compactMap { tag -> String? in
            guard let stop = pickedStops[tag] else { return nil }
            return stopDisplayName(stop)
        }
        nameText = labels.count >= 2 ? labels.joined(separator: " ") : ""
    }

    private func commitBuilder() {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCommitBuilder, !trimmed.isEmpty else { return }
        editor.addCompoundStatValue(name: trimmed, coords: builderCoords)
        closeBuilder()
    }
}
