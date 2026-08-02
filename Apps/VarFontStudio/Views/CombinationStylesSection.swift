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

/// Drawer body for Format 4 combination styles (header lives on the Axis Tree drawer chrome).
struct CombinationStylesSection: View {
    @EnvironmentObject private var editor: EditorViewModel

    let compounds: [CompoundStatValue]
    let axes: [AxisDefinition]

    @State private var isBuilderOpen = false
    @State private var pickedTags: [String] = []
    @State private var pickedStops: [String: AxisValue] = [:]
    @State private var nameText = ""
    @State private var nameEdited = false
    @State private var expandedCompoundID: String?
    @State private var openPicker: LegPicker?
    @State private var hoveredCompoundID: String?

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
                    Button {
                        openBuilder()
                    } label: {
                        Label("Add combination", systemImage: "plus")
                            .font(StudioTypography.caption)
                    }
                    .buttonStyle(StudioLinkButtonStyle(linkStyle: .accent))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StudioSpacing.panelHorizontal)
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
                StudioSemanticDot(color: StudioColors.warningForeground)
                VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
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

            VStack(alignment: .leading, spacing: StudioSpace.x1_5) {
                ForEach(suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding(StudioSpacing.controlGap)
        .background(StudioColors.warningFill, in: RoundedRectangle(cornerRadius: StudioRadius.row))
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.row)
                .strokeBorder(StudioColors.warningForeground.opacity(0.35), lineWidth: 1)
        }
    }

    private func suggestionCard(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        VStack(alignment: .leading, spacing: StudioSpace.x1) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                Text(suggestion.name)
                    .font(StudioTypography.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("covers \(suggestion.coveredInstanceCount) fvar")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.secondary)
            }

            valueForwardChain(coords: suggestion.coords)

            HStack(spacing: StudioSpacing.controlGap) {
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
        .padding(.horizontal, StudioSpace.x2)
        .padding(.vertical, StudioSpace.x1_5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: StudioRadius.control))
    }

    private func valueForwardChain(coords: [String: Double]) -> some View {
        let tags = orderedTags(Set(coords.keys))
        return HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                }
                valueForwardChip(tag: tag, value: coords[tag] ?? 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueForwardChip(tag: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(StudioFormatting.axisValue(value))
                .font(StudioTypography.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(axisLabel(for: tag))
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, StudioSpace.x2)
        .padding(.vertical, StudioSpace.x1)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: StudioRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.control)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Compound cards (collapsed summary / expanded editor)

    private func compoundCard(_ compound: CompoundStatValue) -> some View {
        let isExpanded = expandedCompoundID == compound.id
        let isHovered = hoveredCompoundID == compound.id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded {
                    expandedCompoundID = nil
                    openPicker = nil
                } else {
                    expandedCompoundID = compound.id
                    openPicker = nil
                }
            } label: {
                HStack(spacing: StudioSpace.x1_5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Text(compound.name.isEmpty ? "Untitled" : compound.name)
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(StudioColors.registrationForeground)
                        .lineLimit(1)

                    if !isExpanded {
                        Text(legsSummary(for: compound))
                            .font(StudioTypography.meta)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
                    }

                    if isHovered || isExpanded {
                        StudioDismissButton(scale: .chip, style: .fill, help: "Remove combination") {
                            editor.removeCompoundStatValue(id: compound.id)
                            if expandedCompoundID == compound.id {
                                expandedCompoundID = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, StudioSpace.x2)
                .padding(.vertical, StudioSpace.x2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

                    HStack(spacing: StudioSpace.x1_5) {
                        StudioElidableSwitch(isOn: compound.elidable) {
                            editor.updateCompoundStatElidable(id: compound.id, elidable: !compound.elidable)
                        }
                        Text("Elidable")
                            .font(StudioTypography.meta)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, StudioSpace.x6)
                .padding(.trailing, StudioSpace.x2)
                .padding(.bottom, StudioSpace.x2)
            }
        }
        .background(
            Color.primary.opacity(isExpanded ? 0.035 : 0.02),
            in: RoundedRectangle(cornerRadius: StudioRadius.row)
        )
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.row)
                .strokeBorder(Color.primary.opacity(isExpanded ? 0.1 : 0.06), lineWidth: 1)
        }
    }

    private func legsSummary(for compound: CompoundStatValue) -> String {
        orderedLegTags(for: compound).map { tag in
            let value = compound.coords[tag] ?? 0
            return "\(StudioFormatting.axisValue(value)) \(axisLabel(for: tag))"
        }
        .joined(separator: " + ")
    }

    private func editLegs(_ compound: CompoundStatValue) -> some View {
        let tags = orderedLegTags(for: compound)
        return HStack(alignment: .center, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("+")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    togglePicker(LegPicker(compoundID: compound.id, tag: tag, kind: .value))
                } label: {
                    Text(StudioFormatting.axisValue(compound.coords[tag] ?? 0))
                        .font(StudioTypography.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, StudioSpace.x2)
                        .padding(.vertical, StudioSpace.x1)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: StudioRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: StudioRadius.control)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(swappableAxes(for: compound, currentTag: tag), id: \.tag) { axis in
                        Button(axis.displayName ?? axis.tag) {
                            replaceLeg(compoundID: compound.id, from: tag, to: axis.tag)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(axisLabel(for: tag))
                            .font(StudioTypography.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, StudioSpace.x1_5)
                    .padding(.vertical, StudioSpace.x1)
                    .overlay {
                        RoundedRectangle(cornerRadius: StudioRadius.control)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                if compound.coords.count > 2 {
                    StudioDismissButton(scale: .chip, style: .fill, help: "Remove axis") {
                        editor.removeCompoundStatLeg(id: compound.id, tag: tag)
                    }
                }
            }

            if !addableAxes(for: compound).isEmpty {
                Menu {
                    ForEach(addableAxes(for: compound), id: \.tag) { axis in
                        Button(axis.displayName ?? axis.tag) {
                            editor.addCompoundStatLeg(id: compound.id, tag: axis.tag)
                        }
                    }
                } label: {
                    Text("+ axis")
                        .font(StudioTypography.meta)
                        .foregroundStyle(StudioColors.brand)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlinePicker(for compound: CompoundStatValue, picker: LegPicker) -> some View {
        Group {
            if picker.kind == .value, let tag = picker.tag, let axis = axisByTag[tag] {
                VStack(alignment: .leading, spacing: StudioSpace.x1) {
                    Text("\(axisLabel(for: tag)) stops")
                        .font(StudioTypography.columnLabel)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: StudioSpace.x1) {
                        ForEach(axis.values) { stop in
                            let selected = AxisCoordinate.valuesEqual(stop.value, compound.coords[tag] ?? 0)
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
                .padding(StudioSpace.x2)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: StudioRadius.control)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
            }
        }
    }

    private func stopOptionChip(stop: AxisValue, selected: Bool) -> some View {
        let name = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: 4) {
            Text(StudioFormatting.axisValue(stop.value))
                .font(StudioTypography.caption.weight(.semibold))
                .monospacedDigit()
            if !name.isEmpty, name != StudioFormatting.axisValue(stop.value) {
                Text(name)
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(selected ? .primary : .secondary)
        .padding(.horizontal, StudioSpace.x2)
        .padding(.vertical, StudioSpace.x1)
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
            compound.coords[$0.tag] == nil && !preferredStandaloneNamingTags.contains($0.tag)
        }
    }

    private func swappableAxes(for compound: CompoundStatValue, currentTag: String) -> [AxisDefinition] {
        instanceAxes.filter {
            ($0.tag == currentTag || compound.coords[$0.tag] == nil)
                && !preferredStandaloneNamingTags.contains($0.tag)
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

    // MARK: - Inline builder (value-forward)

    private func openBuilder() {
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
            Text("Pick from stops that already exist on each axis. Doesn’t add an axis or grow the instance grid.")
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

                ForEach(pickedTags, id: \.self) { tag in
                    stopLane(for: tag)
                }
            }

            Text("Chain")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(.tertiary)

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
                Text("Covers \(coveredInstanceCount) generated instance\(coveredInstanceCount == 1 ? "" : "s") — doesn’t grow the grid.")
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
        .padding(StudioSpacing.controlGap)
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
                    guard !isStandalone || isPicked else { return }
                    toggleAxis(axis.tag)
                } label: {
                    Text(axis.displayName ?? axis.tag)
                        .font(StudioTypography.caption)
                        .padding(.horizontal, StudioSpace.x2)
                        .padding(.vertical, StudioSpace.x1)
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
                        .opacity(isStandalone && !isPicked ? 0.4 : 1)
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
            Text(axisLabel(for: tag))
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)

            if stops.isEmpty {
                Text("No stops on this axis yet")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: StudioSpace.x1) {
                    ForEach(stops) { stop in
                        let selected = pickedStops[tag].map { AxisCoordinate.valuesEqual($0.value, stop.value) } ?? false
                        Button {
                            selectStop(tag: tag, stop: stop)
                        } label: {
                            stopOptionChip(stop: stop, selected: selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var chainPreview: some View {
        let complete = pickedTags.compactMap { tag -> (String, Double)? in
            guard let stop = pickedStops[tag] else { return nil }
            return (tag, stop.value)
        }

        return Group {
            if complete.count < 2 {
                Text("Pick a stop on at least two axes")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(StudioSpace.x2)
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
                        HStack(spacing: 4) {
                            Text(StudioFormatting.axisValue(item.1))
                                .font(StudioTypography.caption.weight(.bold))
                                .monospacedDigit()
                            Text(axisLabel(for: item.0))
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, StudioSpace.x2)
                        .padding(.vertical, StudioSpace.x1)
                        .background(StudioColors.selectionFill, in: RoundedRectangle(cornerRadius: StudioRadius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: StudioRadius.control)
                                .strokeBorder(StudioColors.brand.opacity(0.45), lineWidth: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(StudioSpace.x2)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.control))
            }
        }
    }

    private func toggleAxis(_ tag: String) {
        if let index = pickedTags.firstIndex(of: tag) {
            pickedTags.remove(at: index)
            pickedStops.removeValue(forKey: tag)
        } else {
            pickedTags.append(tag)
        }
    }

    private func selectStop(tag: String, stop: AxisValue) {
        pickedStops[tag] = stop
    }

    private func commitBuilder() {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCommitBuilder, !trimmed.isEmpty else { return }
        editor.addCompoundStatValue(name: trimmed, coords: builderCoords)
        closeBuilder()
    }
}
