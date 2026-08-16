import SwiftUI
import VarFontCore

/// Instances filter chrome — shared compact control tokens.
private typealias InstanceListFilterChrome = StudioCompactControlChrome


/// Instances panel local track metrics (on-lattice).
enum InstanceListLayout {
    static let searchFieldWidth: CGFloat = 200
    /// ScrollView coordinate space used to detect when a section header is pinned flush to the top.
    static let scrollCoordinateSpace = "instanceListScroll"
    /// Monospace ch width at `StudioTypography.monoMeta` (10pt) — sized so a 4-char tag never wraps.
    /// This is a font-metric measurement, not a spacing value, so it's intentionally not on the 4pt grid.
    static let pillChWidth: CGFloat = 7.5
    static let pillTagCh: CGFloat = 4
    static let pillPadX: CGFloat = 8
    static let pillPadY: CGFloat = 4
    static let pillInnerGap: CGFloat = 4
    static let pillStripGap: CGFloat = 4
    static let overflowChipWidth: CGFloat = 40
    /// Share of the row reserved for the pill strip when Names + Coords are both on.
    static let bothModePillTrackFraction: CGFloat = 0.48
    static let bothModePillTrackMin: CGFloat = 140
    /// Checkbox + status-accessory slot + inter-item gaps, held back from coords-only
    /// rows so the pill strip's own width constraint is real rather than .infinity.
    /// Does *not* include the row's horizontal content inset — that is subtracted
    /// separately via `rowContentWidth` so it stays in sync with header padding.
    static let coordsOnlyChromeReserve: CGFloat = 64
    /// Matches `InstanceGroupHeaderBar` content inset so checkboxes line up with
    /// section titles and selection/hover washes don't kiss the panel edge.
    static let rowContentInset: CGFloat = StudioSpacing.rowHorizontal

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
    @State private var showIncludeMenu = false
    @State private var axisDrawerOpen = false

    /// When hosted under middle-column chrome, the column owns the title header.
    var showsPanelHeader: Bool = true

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

                    if editor.isTrimmedToOriginals {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text("trimmed")
                            .foregroundStyle(.secondary)
                    }

                    if display.pendingExportCount > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text("\(display.pendingExportCount)")
                            .foregroundStyle(StudioColors.pendingForeground)
                        Text("pending export")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(StudioTypography.caption)
            .lineLimit(1)
        }
    }

    private var instanceList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: StudioSpacing.instanceRowGap, pinnedViews: [.sectionHeaders]) {
                    ForEach(Array(display.groups.enumerated()), id: \.element.id) { index, group in
                        if group.label.isEmpty {
                            VStack(spacing: StudioSpacing.instanceRowGap) {
                                ForEach(group.instances) { instance in
                                    instanceRow(instance)
                                        .id(instanceScrollID(instance.key))
                                }
                            }
                        } else {
                            Section {
                                VStack(spacing: StudioSpacing.instanceRowGap) {
                                    ForEach(group.instances) { instance in
                                        instanceRow(instance)
                                            .id(instanceScrollID(instance.key))
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
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.bottom, StudioSpacing.panelVertical)
            }
            .coordinateSpace(name: InstanceListLayout.scrollCoordinateSpace)
            .transaction { $0.animation = nil }
            .onChange(of: editor.selectedInstanceKey) { _, key in
                guard let key else { return }
                // Fast slideshow: selection highlight moves, but animated scrollTo
                // stacks and stutters when advances are faster than the animation.
                if editor.previewSlideshowSuppressListScroll { return }
                if editor.isPreviewSlideshowPlaying {
                    proxy.scrollTo(instanceScrollID(key), anchor: .center)
                    return
                }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(instanceScrollID(key), anchor: .center)
                }
            }
        }
    }

    private func instanceScrollID(_ key: String) -> String {
        "instance-\(key)"
    }

    /// Space after the last row, before the next section header (lives in scroll content, not the pin target).
    private func sectionTrailingGap(after index: Int) -> CGFloat {
        index < display.groups.count - 1 ? StudioSpacing.sectionGap : 0
    }

    private func instanceRow(_ instance: PlannedInstance) -> some View {
        let hasConflict = display.conflictedInstanceKeys.contains(instance.key)
        let isPendingExport = display.pendingExportByKey[instance.key] ?? false
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
                    instanceListFilterChip(label: label) {
                        editor.clearAxisStopFilter()
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                Spacer(minLength: 0)

                searchField
                    .frame(width: InstanceListLayout.searchFieldWidth)
            }
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.top, StudioSpacing.toolbarVertical)
            .padding(.bottom, StudioSpacing.rowGap - 1)
            .animation(.easeOut(duration: 0.15), value: display.axisStopFilterLabel)

            // Row 2: bulk include + content toggles.
            // Prefer full Labels for Names|Coords; if the panel is too narrow for
            // those two words, fall back to icon segments only. Include all / Hide
            // elided / Show stay labeled in both fits — collapsing everything at
            // once was the extreme jump that made the bar feel empty.
            ViewThatFits(in: .horizontal) {
                filterBarRow2(contentModeIcons: false)
                filterBarRow2(contentModeIcons: true)
            }
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.bottom, StudioSpacing.toolbarVertical)
            .opacity(editor.filteredInstances.isEmpty && display.axisStopFilterLabel == nil ? 0.45 : 1)
        }
        .frame(height: StudioChromeBand.context, alignment: .top)
        .background(StudioColors.surfaceMuted)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func filterBarRow2(contentModeIcons: Bool) -> some View {
        HStack(alignment: .center, spacing: StudioSpacing.rowGap + 1) {
            includePicker

            StudioCompactToggleButton(
                title: "Hide Elided",
                isActive: hideElidedNames,
                isEnabled: !editor.filteredInstances.isEmpty
            ) {
                hideElidedNames.toggle()
            }

            Spacer(minLength: StudioSpacing.controlGap)

            contentModeTray(iconsOnly: contentModeIcons)

            showFilterPicker
        }
    }

    private var includePicker: some View {
        StudioBulkSelectMenu(
            mark: includePickerMark,
            help: includePickerHelp,
            isEnabled: !(editor.filteredInstances.isEmpty && !editor.isTrimmedToOriginals),
            isPresented: $showIncludeMenu
        ) {
            StudioBulkSelectMenuRow(
                title: InstanceInclusionCommands.includeAllTitle,
                mark: .all,
                isSelected: editor.allVisibleInstancesIncluded
                    && !editor.hasMixedVisibleInclusion
                    && !editor.isTrimmedToOriginals
            ) {
                editor.includeAllVisibleInstances()
                showIncludeMenu = false
            }
            StudioBulkSelectMenuRow(
                title: InstanceInclusionCommands.excludeAllTitle,
                mark: .none,
                isSelected: !editor.allVisibleInstancesIncluded
                    && !editor.hasMixedVisibleInclusion
                    && !editor.isTrimmedToOriginals
                    && !editor.filteredInstances.isEmpty == false
            ) {
                editor.excludeAllVisibleInstances()
                showIncludeMenu = false
            }
            if editor.showsTrimNonOriginalsAction {
                Divider().padding(.vertical, StudioSpace.x0_5)
                StudioBulkSelectMenuRow(
                    title: InstanceInclusionCommands.trimNonOriginalsTitle,
                    mark: .mixed,
                    isSelected: editor.isTrimmedToOriginals
                ) {
                    editor.trimNonOriginalInstances()
                    showIncludeMenu = false
                }
            }
        }
    }

    private var includePickerMark: StudioBulkSelectMark {
        if editor.isTrimmedToOriginals || editor.hasMixedVisibleInclusion {
            return .mixed
        }
        if editor.allVisibleInstancesIncluded {
            return .all
        }
        return .none
    }

    private var includePickerHelp: String {
        if editor.isTrimmedToOriginals {
            return "Export includes only styles that match the original font"
        }
        return "Include or exclude visible instances for export"
    }

    private func contentModeTray(iconsOnly: Bool) -> some View {
        HStack(spacing: StudioSpace.x0_5) {
            if iconsOnly {
                contentModeSegment(
                    systemImage: "textformat.characters",
                    isSelected: effectiveShowNames,
                    help: "Show composed names in the instance list",
                    action: toggleShowNames
                )
                contentModeSegment(
                    systemImage: "numbers",
                    isSelected: effectiveShowCoords,
                    help: "Show axis coordinate pills in the instance list",
                    action: toggleShowCoords
                )
            } else {
                contentModeSegment(
                    title: "Names",
                    isSelected: effectiveShowNames,
                    help: "Show composed names in the instance list",
                    action: toggleShowNames
                )
                contentModeSegment(
                    title: "Coords",
                    isSelected: effectiveShowCoords,
                    help: "Show axis coordinate pills in the instance list",
                    action: toggleShowCoords
                )
            }
        }
        .padding(InstanceListFilterChrome.trayInset)
        .background(
            InstanceListFilterChrome.idleFill,
            in: RoundedRectangle.studio(InstanceListFilterChrome.cornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private func toggleShowNames() {
        if showNames && !showCoords {
            // Solo names → turning Names off would empty; flip to coords-only.
            showNames = false
            showCoords = true
        } else {
            showNames.toggle()
        }
    }

    private func toggleShowCoords() {
        if showCoords && !showNames {
            showCoords = false
            showNames = true
        } else {
            showCoords.toggle()
        }
    }

    /// One segment inside the Names|Coords tray — icon or text.
    /// Text uses resolved SF Rounded Medium; symbols keep SF Symbol metrics
    /// (`design: .rounded` on an `Image(systemName:)` doesn't change the glyph and
    /// was hiding whether the text path actually resolved to Rounded).
    private func contentModeSegment(
        title: String? = nil,
        systemImage: String? = nil,
        isSelected: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(InstanceListFilterChrome.symbolFont)
                } else if let title {
                    Text(title)
                        .font(InstanceListFilterChrome.labelFont)
                }
            }
            .foregroundStyle(InstanceListFilterChrome.foreground(isActive: isSelected))
            .padding(.horizontal, InstanceListFilterChrome.horizontalPadding)
            .frame(height: InstanceListFilterChrome.segmentHeight)
            .background(
                isSelected ? InstanceListFilterChrome.activeFill : Color.clear,
                in: RoundedRectangle.studio(InstanceListFilterChrome.segmentcornerRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: InstanceListFilterChrome.segmentcornerRadius),
            isEnabled: !isSelected
        )
        .help(help)
    }

    private var searchField: some View {
        HStack(spacing: StudioSpacing.tightGap) {
            Image(systemName: "magnifyingglass")
                .font(InstanceListFilterChrome.symbolFont)
                .foregroundStyle(StudioColors.textPlaceholder)

            StudioTextField(
                placeholder: "name, wght=400, wdth+wght…",
                text: $editor.searchText,
                font: InstanceListFilterChrome.labelFont,
                rowHeight: InstanceListFilterChrome.searchHeight - 4,
                showsFieldChrome: false,
                focusBinding: $isSearchFocused
            )

            if !editor.searchText.isEmpty {
                StudioDismissButton(scale: .chip, style: .fill) {
                    editor.searchText = ""
                }
            }
        }
        .padding(.horizontal, InstanceListFilterChrome.horizontalPadding)
        .frame(height: InstanceListFilterChrome.searchHeight)
        .background(
            isSearchFocused ? StudioColors.fieldFillFocused : InstanceListFilterChrome.idleFill,
            in: RoundedRectangle.studio(InstanceListFilterChrome.cornerRadius)
        )
    }

    /// Axis-stop selection pill — inverted vs idle buttons (light fill / dark label).
    private func instanceListFilterChip(label: String, onClear: @escaping () -> Void) -> some View {
        HStack(spacing: StudioSpacing.tightGap) {
            Text(label)
                .font(InstanceListFilterChrome.labelFont)
                .foregroundStyle(InstanceListFilterChrome.chipForeground)
                .lineLimit(1)
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: StudioChromeScale.chip.pointSize, weight: StudioChromeScale.symbolWeight))
                    .foregroundStyle(InstanceListFilterChrome.chipForeground.opacity(0.55))
                    .frame(
                        width: StudioChromeScale.chip.hitSize,
                        height: StudioChromeScale.chip.hitSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clear axis stop filter")
        }
        .padding(.leading, InstanceListFilterChrome.horizontalPadding)
        .padding(.trailing, StudioSpacing.tightGap)
        .frame(height: InstanceListFilterChrome.controlHeight)
        .background(
            InstanceListFilterChrome.chipFill,
            in: RoundedRectangle.studio(StudioRadius.chip)
        )
    }

    private var showFilterPicker: some View {
        Button {
            showFilterMenu = true
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Text("Show")
                    .font(InstanceListFilterChrome.labelFont)
                    .foregroundStyle(.secondary)
                // Compact trigger: keep "All" as text; every other filter is its menu symbol
                // so the control width stays stable when switching.
                if let symbol = editor.instanceFilter.menuSymbol {
                    Image(systemName: symbol)
                        .font(InstanceListFilterChrome.symbolFont)
                        .foregroundStyle(showFilterSymbolForeground(for: editor.instanceFilter))
                } else {
                    Text(editor.instanceFilter.label)
                        .font(InstanceListFilterChrome.labelFont)
                        .foregroundStyle(showFilterTriggerForeground)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, InstanceListFilterChrome.horizontalPadding)
            .frame(height: InstanceListFilterChrome.controlHeight)
            .background(
                showFilterTriggerBackground,
                in: RoundedRectangle.studio(InstanceListFilterChrome.cornerRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: InstanceListFilterChrome.cornerRadius))
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
        .presentationBackground(StudioColors.chipSurface)
    }

    private func showFilterMenuRow(_ filter: InstanceFilter) -> some View {
        let isSelected = editor.instanceFilter == filter
        let isConflicts = filter == .duplicates
        let isPending = filter == .pendingExport
        return Button {
            editor.instanceFilter = filter
            showFilterMenu = false
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioColors.metricForeground)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12, alignment: .leading)
                Text(filter.label)
                    .font(InstanceListFilterChrome.labelFont)
                    .foregroundStyle(showFilterForeground(
                        isSelected: true,
                        isConflicts: isConflicts,
                        isPendingExport: isPending
                    ))
                Spacer(minLength: 0)
                if let symbol = filter.menuSymbol {
                    Image(systemName: symbol)
                        .font(InstanceListFilterChrome.symbolFont)
                        .foregroundStyle(showFilterSymbolForeground(for: filter))
                }
            }
            .padding(.horizontal, StudioSpace.x1_5)
            .padding(.vertical, StudioSpacing.panelVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
        .help(showFilterHelp(for: filter))
    }

    private var showFilterTriggerForeground: Color {
        showFilterForeground(
            isSelected: true,
            isConflicts: editor.instanceFilter == .duplicates,
            isPendingExport: editor.instanceFilter == .pendingExport
        )
    }

    private var showFilterTriggerBackground: Color {
        switch editor.instanceFilter {
        case .duplicates, .pendingExport:
            return showFilterBackground(
                isSelected: true,
                isConflicts: editor.instanceFilter == .duplicates,
                isPendingExport: editor.instanceFilter == .pendingExport
            )
        default:
            return InstanceListFilterChrome.idleFill
        }
    }

    private func showFilterHelp(for filter: InstanceFilter) -> String {
        switch filter {
        case .duplicates:
            "Show instances with naming conflicts (duplicate composed names)"
        case .pendingExport:
            "Show included instances not yet written to the working font"
        case .included:
            "Show included instances"
        case .excluded:
            "Show excluded instances"
        case .all:
            "Show all instances"
        }
    }

    private func showFilterForeground(isSelected: Bool, isConflicts: Bool, isPendingExport: Bool) -> Color {
        if isConflicts {
            return StudioColors.warningForeground
        }
        if isPendingExport {
            // Match the row's pending mark (`p.square.fill` + pendingForeground).
            return StudioColors.pendingForeground
        }
        return isSelected ? Color.primary : Color.secondary
    }

    /// Menu/trigger trailing marks — Included/Excluded use checkbox blue; Conflicts /
    /// Pending keep their semantic hues; All has no mark.
    private func showFilterSymbolForeground(for filter: InstanceFilter) -> Color {
        switch filter {
        case .included, .excluded:
            return StudioColors.metricForeground
        case .duplicates:
            return StudioColors.warningForeground
        case .pendingExport:
            return StudioColors.pendingForeground
        case .all:
            return Color.primary
        }
    }

    private func showFilterBackground(isSelected: Bool, isConflicts: Bool, isPendingExport: Bool) -> Color {
        if isConflicts {
            return isSelected
                ? StudioColors.warningFill
                : StudioColors.warningFillSoft
        }
        if isPendingExport {
            return isSelected ? StudioColors.pendingFill : Color.clear
        }
        return isSelected ? StudioColors.selectionNeutralFillStrong : Color.clear
    }

    // MARK: - Axis drawer

    private var axisDrawer: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                // Instant open/close — same as Combination styles drawer.
                // Height animation on the chip grid reads as a genie resize.
                axisDrawerOpen.toggle()
            } label: {
                // Match Combination styles drawer rail in Axis Tree
                // (`StudioChromeBand.header` + emphasis title) so the two
                // bottom drawers share a baseline when both panels are open.
                HStack(spacing: StudioSpacing.controlGap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(axisDrawerOpen ? 90 : 0))
                        .frame(width: 12)
                    Text("Axes")
                        .font(StudioTypography.emphasis)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Text(hidePinnedAxes ? "Pinned hidden" : "All roles")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, StudioSpacing.contentInset)
                .frame(height: StudioChromeBand.header)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .studioHoverFill(shape: .rect)

            if axisDrawerOpen {
                axisDrawerChipGrid
                    .padding(.horizontal, StudioSpacing.contentInset)
                    .padding(.top, StudioSpacing.rowGap)
                    .padding(.bottom, StudioSpacing.panelVertical)
            }
        }
        .background(StudioColors.surfaceMuted)
    }

    private var axisDrawerChipGrid: some View {
        let font = editor.selectedFont
        let tags = editor.namingChainTags.filter { tag in
            guard let axis = font?.axes.first(where: { $0.tag == tag }) else { return false }
            // Pinned axes are omitted entirely when Hide pinned is on — no struck chip.
            if hidePinnedAxes, axis.isDesignRecordOnly { return false }
            return true
        }
        return FlowAxisChipGrid(
            tags: tags,
            enabledTags: Set(display.enabledAxisTags),
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
            return "No Conflicts"
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

// MARK: - Axis drawer chips

/// Packs chips leading with a constant edge-to-edge gap. `LazyVGrid(.adaptive)`
/// used equal-width columns, so narrower tags (e.g. `ital` vs `ousd`) left uneven
/// residual space inside their cells and the visual gaps looked uneven.
private struct AxisChipFlowLayout: Layout {
    var spacing: CGFloat = StudioSpacing.rowGap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for index in subviews.indices {
            let size = result.sizes[index]
            let origin = result.positions[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowMaxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            rowMaxX = max(rowMaxX, x - spacing)
        }

        return (
            CGSize(width: rowMaxX, height: y + rowHeight),
            positions,
            sizes
        )
    }
}

private struct FlowAxisChipGrid: View {
    let tags: [String]
    let enabledTags: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        // Same chrome as the Instances filter buttons; flow layout keeps a
        // constant 6pt gap between chip edges regardless of tag glyph width.
        AxisChipFlowLayout(spacing: StudioSpacing.rowGap) {
            ForEach(tags, id: \.self) { tag in
                let on = enabledTags.contains(tag)
                Button {
                    onToggle(tag)
                } label: {
                    Text(tag)
                        .font(InstanceListFilterChrome.labelFont)
                        .foregroundStyle(InstanceListFilterChrome.foreground(isActive: on))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, InstanceListFilterChrome.horizontalPadding)
                        .frame(height: InstanceListFilterChrome.controlHeight)
                        .background(
                            InstanceListFilterChrome.fill(isActive: on),
                            in: RoundedRectangle.studio(InstanceListFilterChrome.cornerRadius)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(
                    shape: .roundedRect(cornerRadius: InstanceListFilterChrome.cornerRadius),
                    isEnabled: !on
                )
                .help(on ? "Hide \(tag) from coordinate pills" : "Show \(tag) on coordinate pills")
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
    @State private var headerWidth: CGFloat = 0

    private var cornerRadii: RectangleCornerRadii {
        let r = StudioRadius.control
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

    /// Inner content width after horizontal padding.
    private var headerContentWidth: CGFloat {
        max(0, headerWidth - StudioSpacing.rowHorizontal * 2)
    }

    /// Title's hard cap — a *fraction of the one measured `headerWidth`*, not a second
    /// measured quantity. Long group labels ("Compressed Extra Light" vs "8PT") used to
    /// render at `.fixedSize`, i.e. always their full intrinsic width, while the pill
    /// track claimed a fixed fraction with no idea how wide the title actually was. The
    /// two demands could sum to more than the header itself — and since the pill track
    /// is trailing-aligned, the overflow bled *left*, painting over the title's leading
    /// characters (the "ESSED EXTRA LIGHT" — missing "Compr" — bug). Capping the title
    /// here and handing the pill track the exact remainder below means the two can
    /// never sum to more than `headerContentWidth`, by construction.
    private var titleMaxWidth: CGFloat {
        max(50, headerContentWidth * 0.4)
    }

    /// The exact remainder after the title's cap — not a guess, not a second
    /// GeometryReader, just `headerContentWidth - titleMaxWidth`. Still only one live
    /// measurement (`headerWidth`); `titleMaxWidth` is derived from that same value,
    /// not independently measured, so there's nothing left to race.
    private var sharedPillMaxWidth: CGFloat {
        guard headerWidth > 0 else { return InstanceListLayout.bothModePillTrackMin }
        return max(
            InstanceListLayout.bothModePillTrackMin,
            headerContentWidth - titleMaxWidth - StudioSpacing.tightGap
        )
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Opaque base so sticky pins don't let rows show through.
            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .fill(.background)
            // surfaceInset (not surfaceMuted): muted was ~4% wash and read as the same
            // color as the scroll well. Inset matches filter-bar / pill chrome and is
            // dark enough to mark a section boundary at a glance.
            UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .fill(StudioColors.surfaceInset)

            HStack(spacing: StudioSpacing.tightGap) {
                HStack(spacing: StudioSpacing.tightGap) {
                    // Uppercase + tracked, matching the app's own convention for section/group
                    // chrome (the "INSTANCES" panel title, the Add ID popover's "CREDITS"/"OTHER"
                    // headers) instead of just a bolder version of row text.
                    Text(label.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.3)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("· \(count)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                // Bounded, not fixedSize — a title that would blow the cap now
                // truncates with an ellipsis instead of forcing the pill track to
                // overflow. See `titleMaxWidth`.
                .frame(maxWidth: titleMaxWidth, alignment: .leading)

                if !sharedPills.isEmpty {
                    InstanceCoordPillStrip(
                        pills: sharedPills,
                        valueMaxCharacters: valueMaxCharacters,
                        muted: true,
                        maxWidth: sharedPillMaxWidth,
                        alignment: .trailing,
                        onOverflowTap: onOverflowTap
                    )
                    // Occupy the rest of the header so the strip's trailing alignment
                    // lands at the panel edge — not clustered against the title.
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                let frame = geo.frame(in: .named(InstanceListLayout.scrollCoordinateSpace))
                Color.clear
                    .onAppear {
                        updateStuckState(minY: frame.minY)
                        headerWidth = geo.size.width
                    }
                    .onChange(of: frame.minY) { _, y in updateStuckState(minY: y) }
                    .onChange(of: geo.size.width) { _, w in headerWidth = w }
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

    private var pillTrackWidth: CGFloat {
        max(
            InstanceListLayout.bothModePillTrackMin,
            rowContentWidth * InstanceListLayout.bothModePillTrackFraction
        )
    }

    /// Inner width after the same horizontal inset the section headers use —
    /// pill budgets must be driven from this, not the outer measured `rowWidth`,
    /// or the strip will over-claim and reintroduce the left-bleed overflow.
    private var rowContentWidth: CGFloat {
        max(0, rowWidth - InstanceListLayout.rowContentInset * 2)
    }

    /// Coords-only mode has no sibling column competing for space, so the strip can
    /// use nearly the whole row — just needs enough held back for the checkbox,
    /// status accessory, and gaps so the GeometryReader inside the strip gets a real,
    /// bounded number instead of .infinity (see rowContent for why that matters).
    /// Falls back to a conservative default before rowWidth's first measurement lands,
    /// so there's no one-frame flash of unclipped pills.
    private var coordsOnlyPillMaxWidth: CGFloat {
        guard rowContentWidth > 0 else { return InstanceListLayout.bothModePillTrackMin }
        return max(0, rowContentWidth - InstanceListLayout.coordsOnlyChromeReserve)
    }

    var body: some View {
        rowContent
            .opacity(isIncluded ? 1 : 0.45)
            .background {
                StudioRowBackground(
                    isSelected: isSelected,
                    isHovered: isHovered
                )
            }
            .contentShape(RoundedRectangle.studio(StudioRadius.control))
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
            // Guarantee this can never be squeezed toward zero by a sibling's width
            // math — the checkbox's slot must never depend on how the pill strip's
            // budget resolves.
            .fixedSize()
            .layoutPriority(2)

            if bothModes {
                namesColumn
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                InstanceCoordPillStrip(
                    pills: pills,
                    valueMaxCharacters: valueMaxCharacters,
                    muted: false,
                    // Width is now a plain input, not self-measured — see
                    // InstanceCoordPillStrip's doc comment. This also turned out to be
                    // the actual overlap bug: a caller's .frame(width:) around a
                    // .fixedSize child was only ever a layout proposal, never a clip.
                    maxWidth: pillTrackWidth,
                    alignment: .trailing,
                    onOverflowTap: onOverflowTap
                )
            } else if showNames {
                namesColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if showCoords {
                InstanceCoordPillStrip(
                    pills: pills,
                    valueMaxCharacters: valueMaxCharacters,
                    muted: false,
                    maxWidth: coordsOnlyPillMaxWidth,
                    alignment: .leading,
                    onOverflowTap: onOverflowTap
                )
                statusAccessory
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .leading)
        // Same inset as `InstanceGroupHeaderBar` content — lines checkboxes up with
        // section titles and keeps the trailing pill from kissing the highlight edge.
        .padding(.horizontal, InstanceListLayout.rowContentInset)
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

            if isPendingExport {
                if bothModes {
                    // Compact mark — the full "Pending" badge eats too much of the
                    // name column when coords already claim the trailing track.
                    Image(systemName: "p.square.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioColors.pendingForeground)
                        .help("Included in the plan but not yet written to the working font")
                        .fixedSize()
                } else {
                    Text("Pending")
                        .font(StudioTypography.caption.weight(.medium))
                        .foregroundStyle(StudioColors.pendingForeground)
                        .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                        .padding(.vertical, StudioSpacing.instanceRowGap)
                        .background((StudioColors.pendingFill), in: RoundedRectangle.studio(StudioRadius.small))
                        .help("Included in the plan but not yet written to the working font")
                        .fixedSize()
                }
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

        if isPendingExport && !showNames {
            Text("Pending")
                .font(StudioTypography.caption.weight(.medium))
                .foregroundStyle(StudioColors.pendingForeground)
                .padding(.horizontal, StudioSpacing.tagHorizontalInset)
                .padding(.vertical, StudioSpacing.instanceRowGap)
                .background(StudioColors.pendingFill, in: RoundedRectangle.studio(StudioRadius.small))
                .help("Included in the plan but not yet written to the working font")
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
                .foregroundStyle(StudioColors.tagForeground)
                .frame(
                    width: InstanceListLayout.pillTagCh * InstanceListLayout.pillChWidth,
                    alignment: .leading
                )
            Text(pill.formatted)
                .fontWeight(.semibold)
                .foregroundStyle(StudioColors.tagForeground)
                .monospacedDigit()
                .frame(
                    width: InstanceListLayout.valueColumnWidth(valueCharacters: valueMaxCharacters),
                    alignment: .trailing
                )
        }
        .font(StudioTypography.monoMeta)
        .lineLimit(1)
        .padding(.horizontal, InstanceListLayout.pillPadX)
        .padding(.vertical, InstanceListLayout.pillPadY)
        .frame(
            width: InstanceListLayout.pillWidth(valueCharacters: valueMaxCharacters),
            alignment: .leading
        )
        .background {
            // Canonical token: StudioColors.tagBackground is documented as
            // "Instance axis tag pills — neutral text on neutral wash." Row pills
            // were using surfaceInset and header pills a bespoke
            // Color.primary.opacity(0.12) — two unrelated formulas that read as
            // two different pill colors sitting right next to each other. One
            // token everywhere now; `muted` only dims its opacity, never its hue,
            // so header and row pills read as the same family at different volumes.
            //
            // Opaque `chipSurface` under the wash so row selection/hover cannot
            // tint through the translucent tag fill.
            RoundedRectangle.studio(StudioRadius.small)
                .fill(StudioColors.chipSurface)
                .overlay {
                    RoundedRectangle.studio(StudioRadius.small)
                        .fill(StudioColors.tagBackground.opacity(muted ? 0.6 : 1))
                }
        }
        // Resist parent compression — narrow tracks were wrapping tags into "ins"/"d".
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityLabel("\(pill.tag) \(pill.formatted)")
    }
}

private struct InstanceCoordPillStrip: View {
    let pills: [InstanceCoordPill]
    let valueMaxCharacters: Int
    var muted: Bool = false
    /// The bug: this used to be a `fillsWidth: Bool` flag, with the strip self-measuring
    /// its own available width via a GeometryReader in `.background`. That's circular —
    /// the GeometryReader measures the strip's *rendered* size, but `pillRow` forces
    /// `.fixedSize(horizontal: true)` so the strip's rendered size is whatever fits ALL
    /// currently-"shown" pills, which itself depends on the width the GeometryReader
    /// reports. On the first frame (before any measurement exists) the fallback is
    /// "show every pill," which renders at full intrinsic width, which the
    /// GeometryReader then dutifully reports back as the "available" width — poisoning
    /// every calculation after it. Separately, `.fixedSize` on the child means the
    /// caller's `.frame(width:)` was only ever a layout *proposal*, not a clip — content
    /// bigger than that gets rendered anyway, which is the actual overlap you saw.
    /// Fix: the caller already knows its own true available width independent of pill
    /// count (row width, header width) — take it as a plain input instead of guessing.
    let maxWidth: CGFloat
    var alignment: HorizontalAlignment = .trailing
    var onOverflowTap: (() -> Void)?

    @State private var isHovered = false

    private var frameAlignment: Alignment {
        Alignment(
            horizontal: alignment == .leading ? .leading : .trailing,
            vertical: .center
        )
    }

    private var pillWidth: CGFloat {
        InstanceListLayout.pillWidth(valueCharacters: valueMaxCharacters)
    }

    private var stripGap: CGFloat { InstanceListLayout.pillStripGap }

    /// How many pills fit — only reserve `+N` space when not everything fits.
    private var fittedCount: Int {
        guard maxWidth > 0, !pills.isEmpty else { return 0 }
        let fullFit = InstanceCoordPresentation.pillBudget(
            availableWidth: Double(maxWidth),
            pillWidth: Double(pillWidth),
            gap: Double(stripGap)
        )
        if fullFit >= pills.count { return pills.count }
        let reserved = InstanceListLayout.overflowChipWidth + stripGap
        return InstanceCoordPresentation.pillBudget(
            availableWidth: Double(max(0, maxWidth - reserved)),
            pillWidth: Double(pillWidth),
            gap: Double(stripGap)
        )
    }

    private var overflowAtRest: Int {
        max(0, pills.count - fittedCount)
    }

    /// Intrinsic width of the resting (budgeted) cluster, including `+N` when present.
    /// Hover uses this to keep the first pill parked where trailing-alignment left it —
    /// otherwise swapping `pills+N` for the full strip reflows from the leading edge and
    /// the title→pill gap collapses with a jump.
    private var restingClusterWidth: CGFloat {
        clusterWidth(pillCount: fittedCount, includeOverflowChip: overflowAtRest > 0)
    }

    private func clusterWidth(pillCount: Int, includeOverflowChip: Bool) -> CGFloat {
        guard pillCount > 0 else {
            return includeOverflowChip ? InstanceListLayout.overflowChipWidth : 0
        }
        var width = CGFloat(pillCount) * pillWidth + CGFloat(pillCount - 1) * stripGap
        if includeOverflowChip {
            width += stripGap + InstanceListLayout.overflowChipWidth
        }
        return width
    }

    private var showsHoverScroll: Bool {
        isHovered && overflowAtRest > 0
    }

    var body: some View {
        Group {
            if showsHoverScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    pillRow(showAll: true)
                        // Keep the resting cluster's leading edge fixed when expanding.
                        // Trailing strips: pad so pill[0] stays where it was. Leading strips:
                        // no pad — content already starts at the track origin.
                        .padding(
                            .leading,
                            alignment == .trailing
                                ? max(0, maxWidth - restingClusterWidth)
                                : 0
                        )
                }
            } else {
                pillRow(showAll: false)
            }
        }
        // `maxWidth:`, not `width:` — `width:` is a hard demand: if a caller's budget
        // math is ever even slightly wrong (a long header title, a stale row
        // measurement), the strip still insists on rendering at that exact size
        // regardless of what's actually left, and `.clipped()` only clips *its own*
        // box — it does nothing to stop that box from being bigger than the real
        // container. That mismatch is the "pushed outside the left edge" bug: a
        // trailing-aligned box wider than its slot keeps its right edge docked and
        // bleeds left, painting over whatever's next to it. `maxWidth:` makes this a
        // cap instead of a demand, so the strip can only ever shrink to fit what it's
        // actually offered — worst case it silently shows fewer pills, never overflow.
        .frame(maxWidth: max(0, maxWidth), alignment: frameAlignment)
        .clipped()
        .onHover { isHovered = $0 }
    }

    private func pillRow(showAll: Bool) -> some View {
        let count = showAll ? pills.count : min(pills.count, max(fittedCount, 0))
        let shown = Array(pills.prefix(max(count, 0)))
        let hidden = showAll ? 0 : overflowAtRest
        return HStack(spacing: stripGap) {
            ForEach(shown) { pill in
                InstanceCoordPillView(
                    pill: pill,
                    valueMaxCharacters: valueMaxCharacters,
                    muted: muted
                )
            }
            if hidden > 0 {
                Button {
                    onOverflowTap?()
                } label: {
                    Text("+\(hidden)")
                        .font(StudioTypography.monoMeta.weight(.semibold))
                        .foregroundStyle(StudioColors.tagForeground)
                        .lineLimit(1)
                        .padding(.horizontal, InstanceListLayout.pillPadX)
                        .padding(.vertical, InstanceListLayout.pillPadY)
                        .background {
                            // Same tagBackground family as the pills it summarizes —
                            // opaque-backed so selection/hover cannot tint through.
                            RoundedRectangle.studio(StudioRadius.small)
                                .fill(StudioColors.chipSurface)
                                .overlay {
                                    RoundedRectangle.studio(StudioRadius.small)
                                        .fill(StudioColors.tagBackground)
                                }
                        }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Show \(hidden) more axes")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
