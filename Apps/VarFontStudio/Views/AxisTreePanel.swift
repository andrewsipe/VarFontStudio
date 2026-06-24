import SwiftUI
import VarFontCore

struct AxisTreePanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var expandedAxes: Set<String> = []

    var body: some View {
        List {
            if editor.selectedFont != nil {
                gridSummarySection
                if !editor.axisPlanWarnings.isEmpty {
                    warningsSection
                }
                axesSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Axis Tree")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if let font = editor.selectedFont {
                    Text("\(font.axes.count) axes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: editor.selectedFontID) { _ in
            resetExpansion()
        }
        .onAppear {
            if expandedAxes.isEmpty {
                resetExpansion()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var gridSummarySection: some View {
        if let plan = editor.instancePlan, !plan.formula.parts.isEmpty {
            Section {
                LabeledContent("Instance grid") {
                    Text(gridFormulaText(plan))
                        .font(.body.monospacedDigit())
                }
                LabeledContent("Generated") {
                    Text("\(plan.formula.totalGenerated)")
                        .monospacedDigit()
                }
            }
        }
    }

    private var warningsSection: some View {
        Section {
            ForEach(Array(editor.axisPlanWarnings.enumerated()), id: \.offset) { _, warning in
                Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Warnings")
        }
    }

    private var axesSection: some View {
        Section {
            if let font = editor.selectedFont {
                ForEach(font.axes) { axis in
                    let pinned = axis.role != .instance
                    DisclosureGroup(
                        isExpanded: expansionBinding(for: axis.tag),
                        content: {
                            axisDetail(axis)
                        },
                        label: {
                            AxisTreeAxisHeader(axis: axis)
                        }
                    )
                    .foregroundStyle(pinned ? .secondary : .primary)
                    .opacity(pinned ? 0.72 : 1)
                }
            }
        }
    }

    // MARK: - Axis detail

    @ViewBuilder
    private func axisDetail(_ axis: AxisDefinition) -> some View {
        let pinned = axis.role != .instance
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: statOnlyBinding(for: axis.tag)) {
                Text("STAT only")
            }
            .toggleStyle(.checkbox)
            .help(
                "Exclude this axis from the instance grid. STAT stop names remain editable; "
                    + "every generated instance uses this axis's default value."
            )

            if axis.values.isEmpty {
                Text("No STAT stops on this axis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(axis.values) { stop in
                    AxisTreeStopRow(
                        axis: axis,
                        stop: stop,
                        dimmed: pinned,
                        isSelected: editor.selectedAxisStopID == stop.id,
                        onSelect: { editor.selectedAxisStopID = stop.id },
                        name: stopNameBinding(axisTag: axis.tag, stopID: stop.id),
                        elidable: stopElidableBinding(axisTag: axis.tag, stopID: stop.id)
                    )
                }
            }

            if axis.role == .instance {
                Button {
                    editor.addAxisStop(axisTag: axis.tag)
                } label: {
                    Label("Add Stop", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .foregroundStyle(pinned ? .secondary : .primary)
    }

    // MARK: - Bindings

    private func expansionBinding(for tag: String) -> Binding<Bool> {
        Binding(
            get: { expandedAxes.contains(tag) },
            set: { expanded in
                if expanded {
                    expandedAxes.insert(tag)
                } else {
                    expandedAxes.remove(tag)
                }
            }
        )
    }

    private func statOnlyBinding(for tag: String) -> Binding<Bool> {
        Binding(
            get: {
                editor.selectedFont?.axes.first(where: { $0.tag == tag })?.role != .instance
            },
            set: { editor.setAxisStatOnly(tag: tag, statOnly: $0) }
        )
    }

    private func stopNameBinding(axisTag: String, stopID: String) -> Binding<String> {
        Binding(
            get: {
                editor.selectedFont?
                    .axes.first(where: { $0.tag == axisTag })?
                    .values.first(where: { $0.id == stopID })?
                    .name ?? ""
            },
            set: { editor.updateAxisStopName(axisTag: axisTag, stopID: stopID, name: $0) }
        )
    }

    private func stopElidableBinding(axisTag: String, stopID: String) -> Binding<Bool> {
        Binding(
            get: {
                editor.selectedFont?
                    .axes.first(where: { $0.tag == axisTag })?
                    .values.first(where: { $0.id == stopID })?
                    .elidable ?? false
            },
            set: { editor.updateAxisStopElidable(axisTag: axisTag, stopID: stopID, elidable: $0) }
        )
    }

    private func resetExpansion() {
        guard let font = editor.selectedFont else {
            expandedAxes = []
            return
        }
        expandedAxes = Set(
            font.axes.filter { $0.role == .instance || !$0.values.isEmpty }.map(\.tag)
        )
    }

    private func gridFormulaText(_ plan: InstancePlan) -> String {
        let parts = plan.formula.parts.map(String.init).joined(separator: " × ")
        return "\(parts) = \(plan.formula.totalGenerated)"
    }
}

// MARK: - Axis header

private struct AxisTreeAxisHeader: View {
    let axis: AxisDefinition

    var body: some View {
        HStack(spacing: 8) {
            Text(axis.tag)
                .font(.caption.monospaced())
                .foregroundStyle(roleColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(roleColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 1) {
                Text(axis.displayName ?? axis.tag)
                    .font(.body)
                if let range = axisRangeText {
                    Text(range)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 4)

            if axis.role != .instance {
                Text("Pinned")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text("\(axis.values.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
    }

    private var roleColor: Color {
        axis.role == .instance ? .accentColor : .secondary
    }

    private var axisRangeText: String? {
        guard let min = axis.min, let max = axis.max else { return nil }
        let minText = AxisTreeFormatting.value(min)
        let maxText = AxisTreeFormatting.value(max)
        if let defaultValue = axis.default {
            return "\(minText) – \(AxisTreeFormatting.value(defaultValue)) – \(maxText)"
        }
        return "\(minText) – \(maxText)"
    }
}

// MARK: - Stop row

private struct AxisTreeStopRow: View {
    let axis: AxisDefinition
    let stop: AxisValue
    var dimmed: Bool = false
    let isSelected: Bool
    let onSelect: () -> Void
    @Binding var name: String
    @Binding var elidable: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(AxisTreeFormatting.value(stop.value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            TextField("Name", text: $name)
                .textFieldStyle(.plain)
                .font(.body)

            if stop.statFormat == 3 {
                Text("Linked")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Toggle("Elide", isOn: $elidable)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .help("Omit this stop from the composed style name when it is the default choice")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .opacity(dimmed ? 0.85 : 1)
    }
}

private enum AxisTreeFormatting {
    static func value(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        var text = String(value)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        return text
    }
}
