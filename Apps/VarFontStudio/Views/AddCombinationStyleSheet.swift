import SwiftUI
import VarFontCore

/// Axes that usually carry their own Format 1 names — prefer other axes when seeding a new Format 4.
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

// MARK: - Add combination sheet

struct AddCombinationStyleSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let onComplete: () -> Void

    @State private var nameText = ""
    @State private var legs: [LegDraft] = []

    private struct LegDraft: Identifiable, Equatable {
        let id: UUID
        var tag: String
        var valueText: String

        init(tag: String, valueText: String) {
            self.id = UUID()
            self.tag = tag
            self.valueText = valueText
        }
    }

    private var axes: [AxisDefinition] {
        (editor.selectedFont?.axes ?? []).filter { $0.role == .instance && $0.hasFvarScale }
    }

    private var canAdd: Bool {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, legs.count >= 2 else { return false }
        var tags = Set<String>()
        for leg in legs {
            guard axes.contains(where: { $0.tag == leg.tag }) else { return false }
            guard Double(leg.valueText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil else {
                return false
            }
            if !tags.insert(leg.tag).inserted { return false }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Add combination style")
                .font(StudioTypography.emphasis)

            Text("Format 4 — one name for a multi-axis location. Does not add an axis or grow the instance grid.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            StudioTextField(
                placeholder: "Name",
                text: $nameText,
                rowHeight: StudioFieldMetrics.bodyRowHeight
            )

            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                Text("Axes")
                    .font(StudioTypography.columnLabel)
                    .foregroundStyle(.tertiary)

                ForEach($legs) { $leg in
                    legRow($leg)
                }

                if unusedAxes(excluding: Set(legs.map(\.tag))).isEmpty == false {
                    Button {
                        addLeg()
                    } label: {
                        Label("Add axis", systemImage: "plus")
                            .font(StudioTypography.caption)
                    }
                    .buttonStyle(StudioLinkButtonStyle(linkStyle: .accent))
                }
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel") {
                    onComplete()
                    dismiss()
                }
                StudioFlatButton(title: "Add", role: .primary, isEnabled: canAdd, isDefaultAction: true) {
                    commit()
                }
            }
        }
        .padding(StudioSpacing.sheetOuterPadding)
        .frame(width: 380)
        .onAppear(perform: seedDefaults)
    }

    private func legRow(_ leg: Binding<LegDraft>) -> some View {
        let used = Set(legs.map(\.tag))
        let current = leg.wrappedValue.tag
        let options = axes.filter { $0.tag == current || !used.contains($0.tag) }

        return HStack(spacing: StudioSpacing.controlGap) {
            Menu {
                ForEach(options, id: \.tag) { axis in
                    Button(axis.displayName ?? axis.tag) {
                        leg.wrappedValue.tag = axis.tag
                        leg.wrappedValue.valueText = StudioFormatting.axisValue(
                            CombinationStyleDefaults.suggestedValue(for: axis)
                        )
                    }
                }
            } label: {
                HStack(spacing: StudioSpace.x0_5) {
                    Text(leg.wrappedValue.tag)
                        .font(StudioTypography.monoMeta)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(StudioTypography.iconGlyph)
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 72, alignment: .leading)
            }
            .menuStyle(.borderlessButton)

            Text("=")
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.tertiary)

            StudioTextField(
                placeholder: "Value",
                text: leg.valueText,
                font: StudioTypography.monoMeta,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                filledForeground: .primary
            )
            .frame(width: AxisBlockLayout.valueColumnWidth + 12)

            if legs.count > 2 {
                StudioDismissButton(scale: .chip, style: .fill, help: "Remove axis") {
                    legs.removeAll { $0.id == leg.wrappedValue.id }
                }
            } else {
                Color.clear.frame(width: AxisBlockLayout.removeSlotWidth)
            }
        }
    }

    private func unusedAxes(excluding used: Set<String>) -> [AxisDefinition] {
        axes.filter { !used.contains($0.tag) }
    }

    private func seedDefaults() {
        nameText = ""
        guard let pair = CombinationStyleDefaults.suggestedAxisPair(from: editor.selectedFont?.axes ?? []) else {
            legs = []
            return
        }
        legs = [
            LegDraft(
                tag: pair.0.tag,
                valueText: StudioFormatting.axisValue(CombinationStyleDefaults.suggestedValue(for: pair.0))
            ),
            LegDraft(
                tag: pair.1.tag,
                valueText: StudioFormatting.axisValue(CombinationStyleDefaults.suggestedValue(for: pair.1))
            ),
        ]
    }

    private func addLeg() {
        guard let next = unusedAxes(excluding: Set(legs.map(\.tag))).first else { return }
        legs.append(
            LegDraft(
                tag: next.tag,
                valueText: StudioFormatting.axisValue(CombinationStyleDefaults.suggestedValue(for: next))
            )
        )
    }

    private func commit() {
        guard canAdd else { return }
        var coords: [String: Double] = [:]
        for leg in legs {
            guard let value = Double(leg.valueText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return
            }
            coords[leg.tag] = AxisCoordinateFormat.canonical(value)
        }
        editor.addCompoundStatValue(
            name: nameText.trimmingCharacters(in: .whitespacesAndNewlines),
            coords: coords
        )
        onComplete()
        dismiss()
    }
}
