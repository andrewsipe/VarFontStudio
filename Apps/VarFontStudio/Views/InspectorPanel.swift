import SwiftUI
import VarFontCore

/// Instance-scoped inspector content (composed name, chain, coordinates, name table).
struct InstanceInspectorContent: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var layout: EditorLayoutPreferences
    @State private var showPlannedWrites = true

    var body: some View {
        Group {
            if let instance = resolvedInspectorInstance {
                instanceInspector(instance)
            } else {
                emptyInspector
            }
        }
        .id(editor.planRevision)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedInspectorInstance: PlannedInstance? {
        guard let key = editor.inspectorInspectableInstance?.key,
              let live = editor.instancePlan?.instances.first(where: { $0.key == key }) else {
            return editor.inspectorInspectableInstance
        }
        return live
    }

    private var emptyInspector: some View {
        ContentUnavailableView(
            editor.activeInstanceSelection.isEmpty ? "No Instance Selected" : "Select One Instance",
            systemImage: "sidebar.right",
            description: Text(
                editor.activeInstanceSelection.count > 1
                    ? "The inspector shows details for a single instance. Select one row in the instance list."
                    : "Select a row in the instance list to inspect naming, coordinates, and export status."
            )
        )
    }

    private func instanceInspector(_ instance: PlannedInstance) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StudioSpacing.sheetSectionSpacing) {
                StudioComposedNameCallout(
                    name: instance.composedName,
                    isDuplicate: instance.duplicate
                )

                // Primary amber CTA + locus marks on chain/coords — no sparse header badge.
                if let bundle = editor.primaryConflictAxis(for: instance) {
                    StudioConflictAlert(
                        message: "Naming conflict on \(bundle.axisLabel) affects this instance.",
                        actionTitle: "Resolve…"
                    ) {
                        editor.presentConflictResolver(bundle: bundle)
                    }
                } else if instance.duplicate {
                    StudioConflictAlert(
                        message: "This composed name is shared by other instances.",
                        actionTitle: "Show duplicates…"
                    ) {
                        layout.showInstances = true
                        editor.showDuplicateInstances(matching: instance)
                    }
                }

                inclusionSection(instance)
                namingChainSection(instance)
                axisCoordinatesSection(instance)
                nameTableSection(instance)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.top, StudioSpacing.panelContentTop)
            .padding(.bottom, StudioSpacing.panelVertical)
        }
    }

    // MARK: - Sections

    private func inclusionSection(_ instance: PlannedInstance) -> some View {
        StudioInspectorBlock(title: "Export inclusion") {
            let included = editor.isInstanceIncluded(instance.key)
            HStack(alignment: .center, spacing: StudioSpacing.controlGap) {
                StudioIncludeCheckbox(isOn: included) {
                    editor.setInstanceIncluded(instance.key, included: !included)
                }

                VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
                    Text(included ? "Included" : "Excluded")
                        .font(StudioTypography.filterBadgeLabel)
                        .tracking(0.3)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                        .padding(.vertical, StudioSpace.x0_5)
                        .background(
                            included ? StudioColors.successFill : StudioColors.warningFill,
                            in: RoundedRectangle.studio(StudioRadius.chip)
                        )
                        .overlay {
                            RoundedRectangle.studio(StudioRadius.chip)
                                .strokeBorder(
                                    (included
                                        ? StudioColors.successForeground
                                        : StudioColors.warningForeground
                                    ).opacity(0.45),
                                    lineWidth: StudioStroke.hairline
                                )
                        }

                    if !included {
                        Text("This instance will not be written to output.")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: StudioFieldMetrics.listRowMinHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                editor.setInstanceIncluded(instance.key, included: !included)
            }
        }
    }

    private func namingChainSection(_ instance: PlannedInstance) -> some View {
        StudioInspectorBlock(title: "Naming chain") {
            InspectorInstanceNamingChain(
                links: instance.namingChain,
                conflictTag: editor.primaryConflictAxis(for: instance)?.axisTag
            ) { tag in
                editor.focusInspectorAxis(for: instance, tag: tag)
            }
        }
    }

    private func axisCoordinatesSection(_ instance: PlannedInstance) -> some View {
        let rows = editor.inspectorAxisCoordRows(for: instance)
        let showsElidedColumn = rows.contains(where: \.showsElisionToggle)
        let conflictBundle = editor.primaryConflictAxis(for: instance)

        return StudioInspectorBlock(title: "Axis coordinates") {
            // Nest under the section label like Axis Tree stop tables under an axis header.
            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                if showsElidedColumn {
                    HStack(spacing: StudioSpacing.controlGap) {
                        Spacer(minLength: 0)
                        Text("Elided")
                            .font(StudioTypography.columnLabel)
                            .foregroundStyle(StudioColors.sectionHeading)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: InspectorAxisCoordLayout.elisionWidth, alignment: .center)
                    }
                }

                InspectorAxisCoordinatesView(
                    rows: rows,
                    selectedStopID: editor.selectedAxisStopID,
                    conflictAxisTag: conflictBundle?.axisTag,
                    onRowTap: { row in
                        guard let stopID = row.stopID else { return }
                        editor.focusInspectorAxisStop(tag: row.tag, stopID: stopID)
                    },
                    onElisionToggle: { row in
                        guard let stopID = row.stopID else { return }
                        editor.toggleAxisStopElidable(axisTag: row.tag, stopID: stopID)
                    },
                    onConflictTap: {
                        if let conflictBundle {
                            editor.presentConflictResolver(bundle: conflictBundle)
                        }
                    }
                )
            }
            .padding(.leading, AxisBlockLayout.stopIndentWidth)
        }
    }

    private func nameTableSection(_ instance: PlannedInstance) -> some View {
        let rows = editor.openTypePreviewRows(for: instance)
        return VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            tableWritesHeader(rowCount: rows.count)

            if showPlannedWrites {
                VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    if rows.isEmpty {
                        Text("Nothing to write for this instance yet.")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, StudioSpacing.rowHorizontal)
                            .padding(.vertical, StudioSpacing.panelVertical)
                    } else {
                        InspectorOpenTypeTable(rows: rows)
                            .padding(.horizontal, StudioSpacing.rowHorizontal)
                            .padding(.vertical, StudioSpacing.panelVertical)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.control))
            }
        }
    }

    private func tableWritesHeader(rowCount: Int) -> some View {
        // Count sits next to the title (Fonts-section pattern) — not trailing across the panel.
        Button {
            withAnimation(.easeOut(duration: 0.12)) {
                showPlannedWrites.toggle()
            }
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                StudioDisclosureChevron(isExpanded: showPlannedWrites)
                StudioSectionLabel(title: "Table writes")
                Text("\(rowCount)")
                    .font(StudioTypography.filterBadgeLabel)
                    .tracking(0.3)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                    .padding(.vertical, StudioSpace.x0_5)
                    .background(StudioColors.pendingFill, in: RoundedRectangle.studio(StudioRadius.chip))
                    .overlay {
                        RoundedRectangle.studio(StudioRadius.chip)
                            .strokeBorder(
                                StudioColors.pendingForeground.opacity(0.45),
                                lineWidth: StudioStroke.hairline
                            )
                    }
                    .opacity(rowCount == 0 ? 0.45 : 1)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .studioHoverLink(.primary)
        .accessibilityLabel("Table writes, \(rowCount) planned")
    }
}
