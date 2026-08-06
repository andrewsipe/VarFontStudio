import AppKit
import SwiftUI
import VarFontCore

/// Instances panel local track metrics (on-lattice).
enum InstanceListLayout {
    static let searchFieldWidth: CGFloat = 200
    /// ScrollView coordinate space used to detect when a section header is pinned flush to the top.
    static let scrollCoordinateSpace = "instanceListScroll"
    /// Monospace ch width at `StudioTypography.monoMeta` (10pt) — sized so a 4-char tag never wraps.
    static let pillChWidth: CGFloat = 7.5
    static let pillTagCh: CGFloat = 4
    static let pillPadX: CGFloat = 7
    static let pillInnerGap: CGFloat = 5
    static let pillStripGap: CGFloat = 4
    static let overflowChipWidth: CGFloat = 30
    /// Share of the row reserved for the pill strip when Names + Coords are both on.
    static let bothModePillTrackFraction: CGFloat = 0.48
    static let bothModePillTrackMin: CGFloat = 140

    static func pillWidth(valueCharacters: Int) -> CGFloat {
        let valueCh = CGFloat(max(1, valueCharacters))
        return pillPadX * 2 + pillTagCh * pillChWidth + pillInnerGap + valueCh * pillChWidth
    }

    static func valueColumnWidth(valueCharacters: Int) -> CGFloat {
        CGFloat(max(1, valueCharacters)) * pillChWidth
    }
}

struct InstanceListPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var layout: EditorLayoutPreferences
    @AppStorage("instanceListHideElided") private var hideElidedNames = false
    @AppStorage("instanceListShowNames") private var showNames = true
    @AppStorage("instanceListShowCoords") private var showCoords = true
    @AppStorage("instanceListDisabledAxisTags") private var disabledAxisTagsRaw = ""
    @AppStorage("namingChainHideStatOnly") private var hidePinnedAxes = true
    @FocusState private var isSearchFocused: Bool
    @State private var showFilterMenu = false
    @State private var axisDrawerOpen = false

    /// When hosted under middle-column chrome, the column owns the title header.
    var showsPanelHeader: Bool = true

    /// Matches list row checkbox column at the panel margin rail.
    private static let checkboxLeading = StudioSpacing.panelHorizontal

    private var display: InstanceListDisplay {
        editor.instanceListDisplay
    }

    private var disabledAxisTags: Set<String> {
        Set(
            disabledAxisTagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private var effectiveShowNames: Bool {
        showNames || !showCoords
    }

    private var effectiveShowCoords: Bool {
        showCoords
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsPanelHeader {
                StudioPanelHeader(title: "Instances") {
                    Self.headerCounts(editor: editor)
                }
            }

            filterBar

            if editor.selectedFont == nil {
                ContentUnavailableView(
                    "No Font Open",
                    systemImage: "textformat.size",
                    description: Text(StudioEmptyCopy.openOrDropFont)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if display.isEmpty {
                ContentUnavailableView(
                    emptyListTitle,
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(emptyListMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                instanceList
                if effectiveShowCoords {
                    axisDrawer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            syncAxisPresentation()
            focusSearchFieldIfRequested()
        }
        .onChange(of: editor.instanceSearchFocusToken) { _, token in
            guard token != nil else { return }
            focusSearchFieldIfRequested()
        }
        .onChange(of: disabledAxisTagsRaw) { _, _ in
            syncAxisPresentation()
        }
        .onChange(of: hidePinnedAxes) { _, _ in
            syncAxisPresentation()
        }
        .onChange(of: showNames) { _, _ in
            enforceContentMode()
        }
        .onChange(of: showCoords) { _, _ in
            enforceContentMode()
        }
    }

    private func syncAxisPresentation() {
        editor.setInstanceListAxisPresentation(
            disabledTags: disabledAxisTags,
            hidePinnedAxes: hidePinnedAxes
        )
    }

    private func enforceContentMode() {
        if !showNames && !showCoords {
            showNames = true
        }
    }

    private func focusSearchFieldIfRequested() {
        guard editor.instanceSearchFocusToken != nil else { return }
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private var visibleInstanceCount: Int {
        display.groups.reduce(0) { $0 + $1.instances.count }
    }

    /// Trailing header meta shared with the middle-column chrome.
    @ViewBuilder
    static func headerCounts(editor: EditorViewModel) -> some View {
        let display = editor.instanceListDisplay
        let visible = display.groups.reduce(0) { $0 + $1.instances.count }
        if !display.isEmpty {
            HStack(spacing: StudioSpacing.instanceRowVertical) {
                Text("\(visible)")
                    .foregroundStyle(StudioColors.metricForeground)
                Text("shown")
                    .foregroundStyle(.secondary)

                if let plan = editor.instancePlan {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("\(plan.formula.totalIncluded)")
                        .foregroundStyle(StudioColors.metricForeground)
                    Text("included")
                        .foregroundStyle(.secondary)

                    if display.pendingExportCount > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text("\(display.pendingExportCount)")
                            .foregroundStyle(.secondary)
                        Text("pending export")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(StudioTypography.meta)
            .lineLimit(1)
        }
    }

    private var instanceList: some View {
        ScrollView {
            LazyVStack(spacing: StudioSpacing.instanceRowGap, pinnedViews: [.sectionHeaders]) {
                ForEach(Array(display.groups.enumerated()), id: \.element.id) { index, group in
                    if group.label.isEmpty {
                        VStack(spacing: StudioSpacing.instanceRowGap) {
                            ForEach(group.instances) { instance in
                                instanceRow(instance)
                                    .id("\(instance.key)-\(instance.duplicate)-\(editor.planRevision)")
                            }
                        }
                    } else {
                        Section {
                            VStack(spacing: StudioSpacing.instanceRowGap) {
                                ForEach(group.instances) { instance in
                                    instanceRow(instance)
                                        .id("\(instance.key)-\(instance.duplicate)-\(editor.planRevision)")
                                        .zIndex(0)
                                }
                            }
                            .padding(.top, StudioSpacing.tightGap)
                            .padding(.bottom, sectionTrailingGap(after: index))
                            .zIndex(0)
                        } header: {
                            InstanceGroupHeaderBar(
                                label: group.label,
                                count: group.instances.count,
                                sharedPills: effectiveShowCoords
                                    ? (display.groupSharedPills[group.id] ?? [])
                                    : [],
                                valueMaxCharacters: display.coordValueMaxCharacters,
                                onOverflowTap: { axisDrawerOpen = true }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.bottom, StudioSpacing.panelVertical)
        }
        .coordinateSpace(name: InstanceListLayout.scrollCoordinateSpace)
        .transaction { $0.animation = nil }
    }

    /// Space after the last row, before the next section header (lives in scroll content, not the pin target).
    private func sectionTrailingGap(after index: Int) -> CGFloat {
        index < display.groups.count - 1 ? StudioSpacing.sectionGap : 0
    }

    private func instanceRow(_ instance: PlannedInstance) -> some View {
        let hasConflict = editor.instanceAffectedByUnresolvedConflict(instance)
        let isPendingExport = display.pendingExportByKey[instance.key] ?? false
        let bothModes = effectiveShowNames && effectiveShowCoords
        return InstanceRowView(
            instance: instance,
            pills: display.rowPills[instance.key] ?? [],
            valueMaxCharacters: display.coordValueMaxCharacters,
            coordsHelp: display.coordCaptions[instance.key] ?? "",
            isIncluded: display.includedByKey[instance.key] ?? true,
            isSelected: editor.activeInstanceSelection.contains(instance.key),
            hideElidedNames: hideElidedNames,
            showNames: effectiveShowNames,
            showCoords: effectiveShowCoords,
            isDuplicate: instance.duplicate,
            hasConflict: hasConflict,
            isPendingExport: isPendingExport,
            preferPendingWash: bothModes && isPendingExport,
            onSelect: { extend in
                editor.selectInstance(key: instance.key, extend: extend)
            },
            onIncludedChange: { editor.setInstanceIncluded(instance.key, included: $0) },
            onSetSelectionIncluded: { included in
                let keys = editor.activeInstanceSelection.contains(instance.key)
                    ? editor.activeInstanceSelection
                    : [instance.key]
                editor.setInstancesIncluded(keys: keys, included: included)
            },
            onHoverChange: { hovering in
                guard editor.footerPanelMode == .preview else { return }
                if hovering {
                    editor.setPreviewHoverInstanceKey(instance.key, active: true)
                } else {
                    editor.setPreviewHoverInstanceKey(nil, active: false)
                }
            },
            onWarningTap: hasConflict ? {
                if let bundle = editor.primaryConflictAxis(for: instance) {
                    editor.presentConflictResolver(bundle: bundle)
                }
            } : nil,
            onDuplicateTap: instance.duplicate ? {
                layout.showInstances = true
                editor.showDuplicateInstances(matching: instance)
            } : nil,
            onOverflowTap: { axisDrawerOpen = true }
        )
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: navigation
            HStack(alignment: .center, spacing: StudioSpacing.controlGap) {
                if let label = display.axisStopFilterLabel {
                    StudioFilterChip(icon: nil, label: label) {
                        StudioDismissButton(scale: .chip, style: .fill, help: "Clear axis stop filter") {
                            editor.clearAxisStopFilter()
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Spacer(minLength: 0)

                searchField
                    .frame(width: InstanceListLayout.searchFieldWidth)
            }
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.top, StudioSpacing.toolbarVertical)
            .padding(.bottom, StudioSpacing.rowGap - 1)
            .animation(.easeOut(duration: 0.15), value: display.axisStopFilterLabel)

            // Row 2: bulk include + content toggles
            HStack(alignment: .center, spacing: StudioSpacing.rowGap + 1) {
                StudioIncludeCheckbox(
                    isOn: editor.allVisibleInstancesIncluded,
                    isIndeterminate: editor.hasMixedVisibleInclusion
                ) {
                    editor.toggleAllVisibleInstancesIncluded()
                }
                .disabled(editor.filteredInstances.isEmpty)

                InstanceListToggleButton(
                    title: "Include all",
                    isActive: editor.allVisibleInstancesIncluded && !editor.hasMixedVisibleInclusion,
                    isEnabled: !editor.filteredInstances.isEmpty
                ) {
                    editor.toggleAllVisibleInstancesIncluded()
                }

                InstanceListToggleButton(
                    title: "Hide elided",
                    isActive: hideElidedNames,
                    isEnabled: !editor.filteredInstances.isEmpty
                ) {
                    hideElidedNames.toggle()
                }

                Spacer(minLength: StudioSpacing.controlGap)

                contentModeTray

                showFilterPicker
            }
            .padding(.leading, Self.checkboxLeading)
            .padding(.trailing, StudioSpacing.panelHorizontal)
            .padding(.bottom, StudioSpacing.toolbarVertical)
            .opacity(editor.filteredInstances.isEmpty && display.axisStopFilterLabel == nil ? 0.45 : 1)
        }
        .frame(height: StudioChromeBand.context, alignment: .top)
        .background(StudioColors.surfaceMuted)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var contentModeTray: some View {
        HStack(spacing: StudioSpacing.instanceRowGap) {
            StudioSegmentButton(
                title: "Names",
                isSelected: effectiveShowNames,
                help: "Show composed names in the instance list"
            ) {
                if showNames && !showCoords {
                    // Solo names → turning Names off would empty; flip to coords-only.
                    showNames = false
                    showCoords = true
                } else {
                    showNames.toggle()
                }
            }
            StudioSegmentButton(
                title: "Coords",
                isSelected: effectiveShowCoords,
                help: "Show axis coordinate pills in the instance list"
            ) {
                if showCoords && !showNames {
                    showCoords = false
                    showNames = true
                } else {
                    showCoords.toggle()
                }
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: StudioRadius.control))
        .fixedSize(horizontal: true, vertical: false)
    }

    private var searchField: some View {
        StudioSearchField(
            text: $editor.searchText,
            placeholder: "name, wght=400, wdth+wght…",
            isFocused: $isSearchFocused
        )
    }

    private var showFilterPicker: some View {
        Button {
            showFilterMenu = true
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Text("Show")
                    .foregroundStyle(.tertiary)
                Text(editor.instanceFilter.label)
                    .foregroundStyle(showFilterTriggerForeground)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(StudioTypography.meta)
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, StudioSpacing.instanceRowVertical)
            .background(showFilterTriggerBackground, in: RoundedRectangle(cornerRadius: StudioRadius.control))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
        .help(showFilterHelp(for: editor.instanceFilter))
        .popover(isPresented: $showFilterMenu, arrowEdge: .bottom) {
            showFilterMenuContent
        }
    }

    private var showFilterMenuContent: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x0_5) {
            ForEach(editor.visibleInstanceFilters) { filter in
                showFilterMenuRow(filter)
            }
        }
        .padding(StudioSpace.x0_5)
        .frame(width: 168)
    }

    private func showFilterMenuRow(_ filter: InstanceFilter) -> some View {
        let isSelected = editor.instanceFilter == filter
        return Button {
            editor.instanceFilter = filter
            showFilterMenu = false
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColors.brand)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12, alignment: .leading)
                Text(filter.label)
                    .font(StudioTypography.caption)
                    .foregroundStyle(showFilterForeground(
                        isSelected: true,
                        isDuplicates: filter == .duplicates,
                        isPendingExport: filter == .pendingExport
                    ))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, StudioSpace.x1_5)
            .padding(.vertical, StudioSpacing.panelVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.row))
        .help(showFilterHelp(for: filter))
    }

    private var showFilterTriggerForeground: Color {
        showFilterForeground(
            isSelected: true,
            isDuplicates: editor.instanceFilter == .duplicates,
            isPendingExport: editor.instanceFilter == .pendingExport
        )
    }

    private var showFilterTriggerBackground: Color {
        switch editor.instanceFilter {
        case .duplicates, .pendingExport:
            return showFilterBackground(
                isSelected: true,
                isDuplicates: editor.instanceFilter == .duplicates,
                isPendingExport: editor.instanceFilter == .pendingExport
            )
        default:
            return StudioColors.surfaceInset
        }
    }

    private func showFilterHelp(for filter: InstanceFilter) -> String {
        switch filter {
        case .duplicates:
            "Show instances that share a composed name"
        case .pendingExport:
            "Show included instances not yet written to the working font"
        default:
            filter.label
        }
    }

    private func showFilterForeground(isSelected: Bool, isDuplicates: Bool, isPendingExport: Bool) -> Color {
        if isDuplicates {
            return StudioColors.warningForeground
        }
        if isPendingExport {
            return isSelected ? Color.mint : Color.mint.opacity(0.7)
        }
        return isSelected ? Color.primary : Color.secondary
    }

    private func showFilterBackground(isSelected: Bool, isDuplicates: Bool, isPendingExport: Bool) -> Color {
        if isDuplicates {
            return isSelected
                ? StudioColors.warningFill
                : StudioColors.warningFill.opacity(0.45)
        }
        if isPendingExport {
            return isSelected ? Color.mint.opacity(0.16) : Color.clear
        }
        return isSelected ? StudioColors.selectionNeutralFillStrong : Color.clear
    }

    // MARK: - Axis drawer

    private var axisDrawer: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    axisDrawerOpen.toggle()
                }
            } label: {
                HStack(spacing: StudioSpacing.tightGap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(axisDrawerOpen ? 90 : 0))
                        .foregroundStyle(.tertiary)
                    Text("Axes")
                        .font(StudioTypography.meta.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Text(hidePinnedAxes ? "Pinned hidden" : "All roles")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .padding(.vertical, StudioSpacing.panelVertical)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .studioHoverFill(shape: .rect)

            if axisDrawerOpen {
                axisDrawerChipGrid
                    .padding(.horizontal, StudioSpacing.panelHorizontal)
                    .padding(.bottom, StudioSpacing.panelVertical)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(StudioColors.surfaceMuted)
    }

    private var axisDrawerChipGrid: some View {
        let tags = editor.namingChainTags.filter { tag in
            editor.selectedFont?.axes.contains(where: { $0.tag == tag }) == true
        }
        return FlowAxisChipGrid(
            tags: tags,
            enabledTags: Set(display.enabledAxisTags),
            hidePinned: hidePinnedAxes,
            isPinned: { tag in
                editor.selectedFont?.axes.first(where: { $0.tag == tag })?.isDesignRecordOnly == true
            },
            onToggle: toggleDrawerAxis
        )
    }

    private func toggleDrawerAxis(_ tag: String) {
        guard let axis = editor.selectedFont?.axes.first(where: { $0.tag == tag }) else { return }
        if hidePinnedAxes, axis.isDesignRecordOnly {
            return
        }
        var next = disabledAxisTags
        if next.contains(tag) {
            next.remove(tag)
        } else {
            next.insert(tag)
        }
        disabledAxisTagsRaw = next.sorted().joined(separator: ",")
    }

    private var emptyListTitle: String {
        if editor.instanceFilter == .duplicates && editor.searchText.isEmpty && display.axisStopFilterLabel == nil {
            return "No Duplicate Instances"
        }
        if editor.instanceFilter == .pendingExport && editor.searchText.isEmpty && display.axisStopFilterLabel == nil {
            return "No Pending Export Instances"
        }
        if editor.instanceFilter == .excluded && editor.searchText.isEmpty && display.axisStopFilterLabel == nil {
            return "No Excluded Instances"
        }
        return "No Matching Instances"
    }

    private var emptyListMessage: String {
        if display.axisStopFilterLabel != nil {
            return "No instances match the selected axis stop. Click the stop again to clear the filter."
        }
        if editor.instanceFilter == .duplicates && editor.searchText.isEmpty {
            return "No instances share a composed name in this plan."
        }
        if editor.instanceFilter == .pendingExport && editor.searchText.isEmpty {
            return "Every included instance is already in the working font's fvar table."
        }
        if editor.instanceFilter == .excluded && editor.searchText.isEmpty {
            return "No excluded instances — all are included in this export."
        }
        if !editor.searchText.isEmpty || editor.instanceFilter != .all {
            return "Try clearing the search or switching the inclusion filter."
        }
        return "This font has no generated instances."
    }
}

// MARK: - Filter toggle chrome

private struct InstanceListToggleButton: View {
    let title: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(StudioTypography.meta.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isEnabled
                    ? (isActive ? Color.primary : Color.secondary)
                    : Color.secondary.opacity(0.45))
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .padding(.vertical, StudioSpacing.tightGap)
                .background(
                    isActive ? StudioColors.surfaceInset : Color.clear,
                    in: RoundedRectangle(cornerRadius: StudioRadius.control)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
    }
}

// MARK: - Axis drawer chips

private struct FlowAxisChipGrid: View {
    let tags: [String]
    let enabledTags: Set<String>
    let hidePinned: Bool
    let isPinned: (String) -> Bool
    let onToggle: (String) -> Void

    var body: some View {
        // Simple wrapping via LazyVGrid with adaptive columns keeps layout light.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44), spacing: StudioSpacing.tightGap)],
            alignment: .leading,
            spacing: StudioSpacing.tightGap
        ) {
            ForEach(tags, id: \.self) { tag in
                let pinned = isPinned(tag)
                let dimmed = hidePinned && pinned
                let on = enabledTags.contains(tag)
                Button {
                    onToggle(tag)
                } label: {
                    Text(tag)
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(dimmed ? Color.secondary.opacity(0.35) : Color.secondary)
                        .strikethrough(dimmed)
                        .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                        .padding(.vertical, StudioSpacing.instanceRowGap)
                        .background(
                            on && !dimmed ? StudioColors.surfaceInset : Color.clear,
                            in: RoundedRectangle(cornerRadius: StudioRadius.small)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: StudioRadius.small)
                                .strokeBorder(
                                    on && !dimmed ? Color.primary.opacity(0.25) : Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(dimmed)
                .help(dimmed
                    ? "Pinned axis hidden by Naming Order — turn off Hide pinned to enable"
                    : (on ? "Hide \(tag) from coordinate pills" : "Show \(tag) on coordinate pills"))
            }
        }
    }
}

// MARK: - Group header

/// Sticky group chrome for the Instances list.
///
/// When LazyVStack pins the header flush to the scroll top, top corners go square so the
/// bar reads as docked to the panel edge; floating (in-flow) headers keep a full radius.
private struct InstanceGroupHeaderBar: View {
    let label: String
    let count: Int
    var sharedPills: [InstanceCoordPill] = []
    var valueMaxCharacters: Int = 3
    var onOverflowTap: (() -> Void)?

    @State private var isStuckToTop = false

    private var cornerRadii: RectangleCornerRadii {
        let r = StudioRadius.row
        if isStuckToTop {
            return RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: r,
                bottomTrailing: r,
                topTrailing: 0
            )
        }
        return RectangleCornerRadii(
            topLeading: r,
            bottomLeading: r,
            bottomTrailing: r,
            topTrailing: r
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .fill(.background)
            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .fill(StudioColors.surfaceMuted)

            HStack(spacing: StudioSpacing.tightGap) {
                HStack(spacing: StudioSpacing.tightGap) {
                    Text(label)
                        .font(StudioTypography.meta.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("· \(count)")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                if !sharedPills.isEmpty {
                    InstanceCoordPillStrip(
                        pills: sharedPills,
                        valueMaxCharacters: valueMaxCharacters,
                        muted: true,
                        fillsWidth: true,
                        alignment: .trailing,
                        onOverflowTap: onOverflowTap
                    )
                    .layoutPriority(0)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, StudioSpacing.panelVertical)
            .padding(.horizontal, StudioSpacing.rowHorizontal)
        }
        .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .leading)
        .compositingGroup()
        .zIndex(1)
        .background(alignment: .top) {
            GeometryReader { geo in
                let minY = geo.frame(in: .named(InstanceListLayout.scrollCoordinateSpace)).minY
                Color.clear
                    .onAppear { updateStuckState(minY: minY) }
                    .onChange(of: minY) { _, y in updateStuckState(minY: y) }
            }
        }
    }

    private func updateStuckState(minY: CGFloat) {
        let stuck = minY <= 0.5
        if stuck != isStuckToTop {
            isStuckToTop = stuck
        }
    }
}

// MARK: - Row

private struct InstanceRowView: View {
    let instance: PlannedInstance
    let pills: [InstanceCoordPill]
    let valueMaxCharacters: Int
    let coordsHelp: String
    let isIncluded: Bool
    let isSelected: Bool
    var hideElidedNames: Bool = false
    var showNames: Bool = true
    var showCoords: Bool = true
    var isDuplicate: Bool = false
    var hasConflict: Bool = false
    var isPendingExport: Bool = false
    /// When names+coords are both on, prefer a mint wash over the Pending badge.
    var preferPendingWash: Bool = false
    let onSelect: (Bool) -> Void
    let onIncludedChange: (Bool) -> Void
    let onSetSelectionIncluded: (Bool) -> Void
    var onHoverChange: ((Bool) -> Void)?
    var onWarningTap: (() -> Void)?
    var onDuplicateTap: (() -> Void)?
    var onOverflowTap: (() -> Void)?

    @State private var isHovered = false
    @State private var rowWidth: CGFloat = 0

    private var bothModes: Bool { showNames && showCoords }
    private var showPendingBadge: Bool { isPendingExport && !preferPendingWash }

    private var pillTrackWidth: CGFloat {
        max(
            InstanceListLayout.bothModePillTrackMin,
            rowWidth * InstanceListLayout.bothModePillTrackFraction
        )
    }

    var body: some View {
        rowContent
            .opacity(isIncluded ? 1 : 0.45)
            .background {
                ZStack {
                    StudioRowBackground(
                        isSelected: isSelected,
                        isHovered: isHovered,
                        isWarning: isDuplicate
                    )
                    if preferPendingWash {
                        RoundedRectangle(cornerRadius: StudioRadius.row)
                            .fill(Color.mint.opacity(0.16))
                    }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: StudioRadius.row))
            .onTapGesture {
                onSelect(NSEvent.modifierFlags.contains(.command))
            }
            .contextMenu {
                InstanceSelectionContextMenu(
                    includeAction: { onSetSelectionIncluded(true) },
                    excludeAction: { onSetSelectionIncluded(false) }
                )
            }
            .onHover { hovering in
                isHovered = hovering
                onHoverChange?(hovering)
            }
            .help(coordsHelp.isEmpty ? "" : coordsHelp)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { rowWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, w in rowWidth = w }
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: StudioSpacing.rowGap + 1) {
            StudioIncludeCheckbox(isOn: isIncluded) {
                onIncludedChange(!isIncluded)
            }

            if bothModes {
                namesColumn
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                InstanceCoordPillStrip(
                    pills: pills,
                    valueMaxCharacters: valueMaxCharacters,
                    muted: false,
                    fillsWidth: true,
                    alignment: .trailing,
                    onOverflowTap: onOverflowTap
                )
                .frame(width: pillTrackWidth, alignment: .trailing)
            } else if showNames {
                namesColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if showCoords {
                InstanceCoordPillStrip(
                    pills: pills,
                    valueMaxCharacters: valueMaxCharacters,
                    muted: false,
                    fillsWidth: true,
                    alignment: .leading,
                    onOverflowTap: onOverflowTap
                )
                statusAccessory
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .leading)
        .padding(.vertical, StudioSpacing.instanceRowVertical)
    }

    private var namesColumn: some View {
        HStack(spacing: StudioSpacing.tightGap) {
            StudioInstanceComposedName(
                links: instance.namingChain,
                fallback: instance.composedName,
                included: isIncluded,
                hideElided: hideElidedNames
            )
            .strikethrough(!isIncluded, color: .secondary)
            .lineLimit(1)

            if showPendingBadge {
                Text("Pending")
                    .font(StudioTypography.meta.weight(.medium))
                    .foregroundStyle(Color.mint)
                    .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                    .padding(.vertical, StudioSpacing.instanceRowGap)
                    .background(Color.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: StudioRadius.small))
                    .help("Included in the plan but not yet written to the working font")
                    .fixedSize()
            }

            statusAccessory
        }
    }

    @ViewBuilder
    private var statusAccessory: some View {
        Color.clear
            .frame(width: StudioWarningBadge.slotSize, height: StudioWarningBadge.slotSize)
            .overlay {
                if hasConflict {
                    StudioWarningBadge(help: "Naming conflict — show in inspector") {
                        onWarningTap?()
                    }
                } else if isDuplicate {
                    StudioWarningBadge(help: "Duplicate composed name — show matching instances") {
                        onDuplicateTap?()
                    }
                }
            }
            .fixedSize()

        if showPendingBadge && !showNames {
            Text("Pending")
                .font(StudioTypography.meta.weight(.medium))
                .foregroundStyle(Color.mint)
                .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                .padding(.vertical, StudioSpacing.instanceRowGap)
                .background(Color.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: StudioRadius.small))
                .fixedSize()
        }
    }
}

// MARK: - Coordinate pills

private struct InstanceCoordPillView: View {
    let pill: InstanceCoordPill
    let valueMaxCharacters: Int
    var muted: Bool = false

    var body: some View {
        HStack(spacing: InstanceListLayout.pillInnerGap) {
            Text(pill.tag)
                .foregroundStyle(.tertiary)
                .frame(
                    width: InstanceListLayout.pillTagCh * InstanceListLayout.pillChWidth,
                    alignment: .leading
                )
            Text(pill.formatted)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(
                    width: InstanceListLayout.valueColumnWidth(valueCharacters: valueMaxCharacters),
                    alignment: .trailing
                )
        }
        .font(StudioTypography.monoMeta)
        .lineLimit(1)
        .padding(.horizontal, InstanceListLayout.pillPadX)
        .padding(.vertical, 3)
        .frame(
            width: InstanceListLayout.pillWidth(valueCharacters: valueMaxCharacters),
            alignment: .leading
        )
        .background(
            muted ? Color.primary.opacity(0.06) : StudioColors.surfaceInset,
            in: RoundedRectangle(cornerRadius: StudioRadius.small)
        )
        .opacity(muted ? 0.9 : 1)
        // Resist parent compression — narrow tracks were wrapping tags into "ins"/"d".
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityLabel("\(pill.tag) \(pill.formatted)")
    }
}

private struct InstanceCoordPillStrip: View {
    let pills: [InstanceCoordPill]
    let valueMaxCharacters: Int
    var muted: Bool = false
    /// When true, the strip claims flexible width so overflow budgeting can measure it.
    var fillsWidth: Bool = true
    var alignment: HorizontalAlignment = .trailing
    var onOverflowTap: (() -> Void)?

    @State private var isHovered = false
    @State private var availableWidth: CGFloat = 0

    private var frameAlignment: Alignment {
        Alignment(
            horizontal: alignment == .leading ? .leading : .trailing,
            vertical: .center
        )
    }

    private var pillWidth: CGFloat {
        InstanceListLayout.pillWidth(valueCharacters: valueMaxCharacters)
    }

    /// How many pills fit — only reserve `+N` space when not everything fits.
    private var fittedCount: Int {
        guard availableWidth > 0, !pills.isEmpty else {
            return availableWidth > 0 ? 0 : pills.count
        }
        let fullFit = InstanceCoordPresentation.pillBudget(
            availableWidth: Double(availableWidth),
            pillWidth: Double(pillWidth),
            gap: Double(InstanceListLayout.pillStripGap)
        )
        if fullFit >= pills.count { return pills.count }
        let reserved = InstanceListLayout.overflowChipWidth + InstanceListLayout.pillStripGap
        return InstanceCoordPresentation.pillBudget(
            availableWidth: Double(max(0, availableWidth - reserved)),
            pillWidth: Double(pillWidth),
            gap: Double(InstanceListLayout.pillStripGap)
        )
    }

    private var visibleCount: Int {
        guard !pills.isEmpty else { return 0 }
        if isHovered { return pills.count }
        return min(pills.count, max(fittedCount, 0))
    }

    private var overflowCount: Int {
        max(0, pills.count - visibleCount)
    }

    var body: some View {
        Group {
            if isHovered && pills.count > fittedCount {
                ScrollView(.horizontal, showsIndicators: false) {
                    pillRow(showAll: true)
                }
            } else {
                pillRow(showAll: false)
            }
        }
        .frame(
            maxWidth: fillsWidth ? .infinity : nil,
            alignment: frameAlignment
        )
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { availableWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, w in availableWidth = w }
            }
        }
        .onHover { isHovered = $0 }
    }

    private func pillRow(showAll: Bool) -> some View {
        let count = showAll ? pills.count : visibleCount
        let shown = Array(pills.prefix(max(count, 0)))
        let hidden = showAll ? 0 : overflowCount
        return HStack(spacing: InstanceListLayout.pillStripGap) {
            ForEach(shown) { pill in
                InstanceCoordPillView(pill: pill, valueMaxCharacters: valueMaxCharacters, muted: muted)
            }
            if hidden > 0 {
                Button {
                    onOverflowTap?()
                } label: {
                    Text("+\(hidden)")
                        .font(StudioTypography.monoMeta.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                        .padding(.vertical, 3)
                        .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: StudioRadius.small))
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Show \(hidden) more axes")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
