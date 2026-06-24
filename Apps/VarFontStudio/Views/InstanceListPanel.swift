import SwiftUI
import VarFontCore

struct InstanceListPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    private var display: InstanceListDisplay {
        editor.instanceListDisplay
    }

    var body: some View {
        VStack(spacing: 0) {
            FontFileTabs()
            filterBar

            if editor.selectedFont == nil {
                ContentUnavailableView(
                    "No Font Open",
                    systemImage: "textformat.size",
                    description: Text("Open or drop a variable font to generate instances.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if display.isEmpty {
                ContentUnavailableView(
                    "No Matching Instances",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(emptyListMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                instanceList
            }
        }
        .navigationTitle("Instances")
    }

    private var instanceList: some View {
        ScrollView {
            LazyVStack(spacing: 1, pinnedViews: [.sectionHeaders]) {
                ForEach(display.groups) { group in
                    if group.label.isEmpty {
                        ForEach(group.instances) { instance in
                            instanceRow(instance)
                        }
                    } else {
                        Section {
                            ForEach(group.instances) { instance in
                                instanceRow(instance)
                            }
                        } header: {
                            sectionHeader(group)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .transaction { $0.animation = nil }
    }

    private func instanceRow(_ instance: PlannedInstance) -> some View {
        InstanceRowView(
            instance: instance,
            coordsCaption: display.coordCaptions[instance.key] ?? "",
            isIncluded: display.includedByKey[instance.key] ?? true,
            isSelected: editor.selectedInstanceKey == instance.key,
            onSelect: { editor.selectedInstanceKey = instance.key },
            onIncludedChange: { editor.setInstanceIncluded(instance.key, included: $0) }
        )
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("Search names or coordinates", text: $editor.searchText)
                    .textFieldStyle(.roundedBorder)

                Picker("Show", selection: $editor.instanceFilter) {
                    ForEach(InstanceFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Button("All") {
                    editor.setFilteredInstancesIncluded(true)
                }
                .disabled(editor.filteredInstances.isEmpty)

                Button("None") {
                    editor.setFilteredInstancesIncluded(false)
                }
                .disabled(editor.filteredInstances.isEmpty)
            }

            HStack(spacing: 8) {
                if let label = display.axisStopFilterLabel {
                    HStack(spacing: 4) {
                        Label(label, systemImage: "line.3.horizontal.decrease")
                            .font(.caption)
                        Button {
                            editor.clearAxisStopFilter()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear axis stop filter")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
                }

                if let summary = display.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if editor.selectedFont?.dirty == true {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ group: InstanceGroup) -> some View {
        HStack(spacing: 6) {
            Text(group.label)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(group.instances.count)")
                .foregroundStyle(.secondary)
        }
        .font(.caption.weight(.semibold))
        .textCase(nil)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(.background)
                .padding(.horizontal, -8)
        }
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary.opacity(0.5))
                .padding(.horizontal, -8)
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .zIndex(1)
    }

    private var emptyListMessage: String {
        if display.axisStopFilterLabel != nil {
            return "No instances match the selected axis stop. Click the stop again to clear the filter."
        }
        if !editor.searchText.isEmpty || editor.instanceFilter != .all {
            return "Try clearing the search or switching the inclusion filter."
        }
        return "This font has no generated instances."
    }
}

private struct InstanceRowView: View {
    let instance: PlannedInstance
    let coordsCaption: String
    let isIncluded: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onIncludedChange: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 7) {
            InstanceIncludeCheckbox(isOn: isIncluded) {
                onIncludedChange(!isIncluded)
            }

            Text(instance.composedName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isIncluded ? .primary : .secondary)
                .strikethrough(!isIncluded, color: .secondary)
                .lineLimit(1)

            if instance.duplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("Duplicate composed name")
            }

            Spacer(minLength: 8)

            Text(coordsCaption)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .trailing)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .opacity(isIncluded ? 1 : 0.45)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 4))
        .onTapGesture(perform: onSelect)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(rowFill)
            .overlay {
                if isSelected && !instance.duplicate {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
    }

    private var rowFill: Color {
        if instance.duplicate {
            return Color.orange.opacity(isHovered ? 0.18 : 0.12)
        }
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return Color.clear
    }
}

private struct InstanceIncludeCheckbox: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.secondary.opacity(isOn ? 0.55 : 0.35), lineWidth: 1)
                    .frame(width: 13, height: 13)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Exclude from export" : "Include in export")
    }
}
