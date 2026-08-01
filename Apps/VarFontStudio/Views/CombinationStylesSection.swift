import SwiftUI
import VarFontCore

struct CombinationStylesSection: View {
    @EnvironmentObject private var editor: EditorViewModel

    let compounds: [CompoundStatValue]
    let axes: [AxisDefinition]
    var onAdd: () -> Void

    @State private var isExpanded = true
    @State private var editingLeg: (compoundID: String, tag: String)?
    @State private var legDraft = ""
    @State private var hoveredCompoundID: String?

    private var axisByTag: [String: AxisDefinition] {
        Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
    }

    private var canAddCombination: Bool {
        axes.filter { $0.role == .instance && $0.hasFvarScale }.count >= 2
    }

    private var instanceAxes: [AxisDefinition] {
        axes.filter { $0.role == .instance && $0.hasFvarScale }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            disclosureHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    if compounds.isEmpty {
                        emptyState
                    } else {
                        ForEach(compounds) { compound in
                            compoundBlock(compound)
                        }
                    }

                    if canAddCombination {
                        StudioFlatButton(title: "Add combination", size: .compact) {
                            onAdd()
                            isExpanded = true
                        }
                        .padding(.leading, StopTableLayout.stopIndentWidth)
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

    /// Prefer naming-order / axis-tree order over alphabetical.
    private func orderedLegTags(for compound: CompoundStatValue) -> [String] {
        let present = Set(compound.coords.keys)
        let treeOrder = axes.map(\.tag).filter { present.contains($0) }
        let leftovers = present.subtracting(treeOrder).sorted()
        return treeOrder + leftovers
    }

    private func addableAxes(for compound: CompoundStatValue) -> [AxisDefinition] {
        instanceAxes.filter { compound.coords[$0.tag] == nil }
    }

    @ViewBuilder
    private func legChip(compound: CompoundStatValue, tag: String) -> some View {
        let value = compound.coords[tag] ?? 0
        let missingAxis = axisByTag[tag] == nil
        let isEditing = editingLeg?.compoundID == compound.id && editingLeg?.tag == tag
        let swappable = swappableAxes(for: compound, currentTag: tag)

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

                Text("=")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)

                Button {
                    editingLeg = (compound.id, tag)
                    legDraft = StudioFormatting.axisValue(value)
                } label: {
                    Text(StudioFormatting.axisValue(value))
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))

                if compound.coords.count > 2 {
                    StudioDismissButton(scale: .chip, style: .fill, help: "Remove axis") {
                        editor.removeCompoundStatLeg(id: compound.id, tag: tag)
                    }
                }
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
}
