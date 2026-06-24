import AppKit
import SwiftUI
import VarFontCore

struct InstanceListPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    private let toolbarColumnWidth: CGFloat = 168

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
                            StudioGroupHeader(label: group.label, count: group.instances.count)
                        }
                    }
                }
            }
            .padding(.horizontal, StudioSpacing.listInset)
            .padding(.vertical, StudioSpacing.panelVertical)
        }
        .transaction { $0.animation = nil }
    }

    private func instanceRow(_ instance: PlannedInstance) -> some View {
        InstanceRowView(
            instance: instance,
            coordsCaption: display.coordCaptions[instance.key] ?? "",
            isIncluded: display.includedByKey[instance.key] ?? true,
            isSelected: editor.activeInstanceSelection.contains(instance.key),
            onSelect: { extend in
                editor.selectInstance(key: instance.key, extend: extend)
            },
            onIncludedChange: { editor.setInstanceIncluded(instance.key, included: $0) },
            onSetSelectionIncluded: { included in
                let keys = editor.activeInstanceSelection.contains(instance.key)
                    ? editor.activeInstanceSelection
                    : [instance.key]
                editor.setInstancesIncluded(keys: keys, included: included)
            }
        )
    }

    private var filterBar: some View {
        StudioCompactToolbar {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: StudioSpacing.controlGap) {
                    if let label = display.axisStopFilterLabel {
                        StudioFilterChip(icon: nil, label: label) {
                            Button {
                                editor.clearAxisStopFilter()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(StudioTypography.meta)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear axis stop filter")
                        }
                    }

                    Spacer(minLength: 0)

                    toolbarSearchField
                        .frame(width: toolbarColumnWidth, alignment: .trailing)
                }

                HStack(alignment: .center, spacing: 0) {
                    includeAllRow
                        .frame(maxWidth: .infinity, alignment: .leading)

                    showFilterControl
                        .frame(width: toolbarColumnWidth, alignment: .trailing)

                    if editor.selectedFont?.dirty == true {
                        Text("Edited")
                            .font(StudioTypography.meta)
                            .foregroundStyle(.secondary)
                            .padding(.leading, StudioSpacing.controlGap)
                    }
                }
                .frame(minHeight: 28)
            }
        }
    }

    private var toolbarSearchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(StudioTypography.meta)
                .foregroundStyle(.tertiary)
            TextField("Search", text: $editor.searchText)
                .textFieldStyle(.plain)
                .font(StudioTypography.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: StudioRadius.chip))
    }

    private var includeAllRow: some View {
        HStack(spacing: StudioSpacing.rowGap + 1) {
            StudioIncludeCheckbox(
                isOn: editor.allVisibleInstancesIncluded,
                isIndeterminate: editor.hasMixedVisibleInclusion
            ) {
                editor.toggleAllVisibleInstancesIncluded()
            }

            Text("Include All")
                .font(StudioTypography.caption)
                .foregroundStyle(editor.filteredInstances.isEmpty ? .secondary : .primary)

            if let summary = display.summary {
                Text(summary)
                    .font(StudioTypography.meta)
                    .foregroundStyle(StudioColors.dataHighlight)
                    .lineLimit(1)
                    .layoutPriority(-1)
                    .padding(.leading, 2)
            }
        }
        .opacity(editor.filteredInstances.isEmpty ? 0.45 : 1)
        .allowsHitTesting(!editor.filteredInstances.isEmpty)
        .help("Include or exclude every instance currently shown in the list")
    }

    private var showFilterControl: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("Show")
                .font(StudioTypography.meta)
                .foregroundStyle(.tertiary)
                .fixedSize()

            Picker("Show", selection: $editor.instanceFilter) {
                ForEach(InstanceFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .labelsHidden()
            .frame(maxWidth: toolbarColumnWidth)
        }
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
    let onSelect: (Bool) -> Void
    let onIncludedChange: (Bool) -> Void
    let onSetSelectionIncluded: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: StudioSpacing.rowGap + 1) {
            StudioIncludeCheckbox(isOn: isIncluded) {
                onIncludedChange(!isIncluded)
            }

            Text(instance.composedName)
                .font(StudioTypography.bodyMedium)
                .foregroundStyle(isIncluded ? .primary : .secondary)
                .strikethrough(!isIncluded, color: .secondary)
                .lineLimit(1)

            if instance.duplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.orange)
                    .help("Duplicate composed name")
            }

            Spacer(minLength: StudioSpacing.controlGap)

            Text(coordsCaption)
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(maxWidth: 140, alignment: .trailing)
        }
        .studioRowInsets()
        .opacity(isIncluded ? 1 : 0.45)
        .background(
            StudioRowBackground(
                isSelected: isSelected,
                isHovered: isHovered,
                isWarning: instance.duplicate
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: StudioRadius.row))
        .onTapGesture {
            onSelect(NSEvent.modifierFlags.contains(.command))
        }
        .contextMenu {
            Button("Include") {
                onSetSelectionIncluded(true)
            }
            Button("Exclude") {
                onSetSelectionIncluded(false)
            }
        }
        .onHover { isHovered = $0 }
    }
}
