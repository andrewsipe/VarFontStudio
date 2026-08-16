import SwiftUI
import VarFontCore

// MARK: - Review (tabbed presentation)

struct CommitDiffReviewView: View {
    @EnvironmentObject private var editor: EditorViewModel
    let session: CommitPreflightSession
    var fillsAvailableHeight: Bool = false
    private let actionBar: AnyView

    init(session: CommitPreflightSession, fillsAvailableHeight: Bool = false) {
        self.session = session
        self.fillsAvailableHeight = fillsAvailableHeight
        self.actionBar = AnyView(EmptyView())
    }

    init<ActionBar: View>(
        session: CommitPreflightSession,
        fillsAvailableHeight: Bool = false,
        @ViewBuilder actionBar: () -> ActionBar
    ) {
        self.session = session
        self.fillsAvailableHeight = fillsAvailableHeight
        self.actionBar = AnyView(actionBar())
    }

    private var projectID: String { session.projectID }
    private var uiState: SaveReviewUIState { editor.saveReviewUIState(forProjectID: projectID) }

    private var selectedTab: SaveReviewTableTab {
        uiState.selectedTableTab
    }

    private var activeTab: SaveReviewTabPresentation? {
        session.presentation.tabs.first { $0.id == selectedTab }
            ?? session.presentation.tabs.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pinnedChrome
            if let activeTab, !session.presentation.tabs.isEmpty {
                headlineView(for: activeTab)
                    .padding(.horizontal, SaveReviewLayout.horizontalPadding)
                    .padding(.vertical, SaveReviewLayout.toolRowVerticalPadding)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: SaveReviewLayout.toolRowMinHeight,
                        alignment: .leading
                    )
                StudioSaveReviewColumnHeader()
                rowScrollContent(for: activeTab)
                    .layoutPriority(1)
                statusBar(for: activeTab)
            } else if session.preflight.ok {
                ContentUnavailableView(
                    "No changes",
                    systemImage: "checkmark.circle",
                    description: Text(StudioEmptyCopy.reviewNoChanges)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .top)
    }

    // MARK: - Pinned chrome

    private var pinnedChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SaveReviewLayout.chromeSectionGap) {
                HStack(alignment: .top, spacing: StudioSpace.x4) {
                    VStack(alignment: .leading, spacing: SaveReviewLayout.chromeSectionGap) {
                        header
                        fileNamingBanner
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    actionBar
                }
                if let summary = session.preflight.summary {
                    summaryMetrics(summary, tab: activeTab)
                }
                if !session.preflight.warnings.isEmpty {
                    warningsCard(session.preflight.warnings)
                }
                if !session.preflight.errors.isEmpty {
                    errorsCard(session.preflight.errors)
                }
                if !session.presentation.tabs.isEmpty {
                    filterBadges
                        .padding(.bottom, StudioSpace.x0_5)
                }
            }
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.top, StudioSpace.x4)
            .padding(.bottom, SaveReviewLayout.chromeSectionGap)

            if !session.presentation.tabs.isEmpty {
                tabChrome
            }
        }
    }

    private var header: some View {
        Text("Planned write preview — after values with change context")
            .font(StudioTypography.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var fileNamingBanner: some View {
        let font = editor.project?.fonts.first { $0.id == session.fontID }
        let psPrefix = editor.familyPSPrefix(for: session.fontID)
        let covered = font.map { RegistrationAxisSupport.clarifierCategoriesCoveredByRegistration(font: $0) } ?? []
        let clarifiers = editor.clarifierLabels(for: session.fontID)
            .filter { !covered.contains($0.category) }
        let registrationStops: [(tag: String, name: String, code: String?)] = {
            guard let font else { return [] }
            return font.axes
                .filter(\.isDesignRecordOnly)
                .compactMap { axis -> (String, String, String?)? in
                    guard let resolved = RegistrationAxisSupport.registrationStopName(
                        tag: axis.tag,
                        axes: font.axes,
                        fileStatRegistration: font.fileStatRegistration
                    ) else { return nil }
                    return (axis.tag, resolved.stop.name, resolved.stop.code)
                }
        }()
        let namingOrder: [String] = {
            guard let project = editor.project, let font else { return [] }
            return NamingPolicy.mergedOrder(
                projectOrder: project.naming.order,
                axisTags: font.axes.map(\.tag)
            )
        }()
        if !psPrefix.isEmpty || !registrationStops.isEmpty || !clarifiers.isEmpty || !namingOrder.isEmpty {
            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                if !psPrefix.isEmpty || !registrationStops.isEmpty || !clarifiers.isEmpty {
                    HStack(spacing: StudioSpacing.rowGap) {
                        if !psPrefix.isEmpty {
                            Text("PostScript prefix")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                            Text(psPrefix)
                                .font(StudioTypography.caption.monospaced())
                        }
                        if !registrationStops.isEmpty {
                            Text("Naming")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                            ForEach(registrationStops, id: \.tag) { stop in
                                HStack(spacing: StudioSpacing.tightGap) {
                                    Text(stop.tag)
                                        .font(StudioTypography.tag)
                                        .foregroundStyle(.primary)
                                    Text(stop.name)
                                        .font(StudioTypography.caption)
                                        .foregroundStyle(.primary)
                                    if let code = stop.code, !code.isEmpty {
                                        Text(code)
                                            .font(StudioTypography.monoMeta)
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(StudioColors.codeBackground, in: RoundedRectangle.studio(StudioRadius.chip))
                                    }
                                }
                                .padding(.horizontal, StudioSpacing.rowHorizontal)
                                .padding(.vertical, StudioSpace.x0_5)
                                .background(
                                    StudioColors.registrationBackground,
                                    in: RoundedRectangle.studio(StudioRadius.chip)
                                )
                            }
                        }
                        if !clarifiers.isEmpty {
                            Text("Clarifiers")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                            ForEach(clarifiers) { clarifier in
                                StudioClarifierPill(label: clarifier.label, compact: true)
                            }
                        }
                    }
                }
                if !namingOrder.isEmpty {
                    HStack(spacing: StudioSpacing.rowGap) {
                        Text("Naming order")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.secondary)
                        Text(SaveReviewRowFormatter.namingOrderAfterValue(namingOrder))
                            .font(StudioTypography.caption.monospaced())
                            .foregroundStyle(.primary)
                            .help("Same chain as the footer. [-] is the PostScript hyphen split.")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryMetrics(_ summary: CommitSummary, tab: SaveReviewTabPresentation?) -> some View {
        let removed = tab?.removedRowCount ?? 0
        let added = tab?.addedRowCount ?? 0

        HStack(spacing: SaveReviewLayout.summaryCardGap) {
            StudioMetricCard(value: "\(summary.instancesWritten)", label: "Instances", minWidth: 0, accentValue: true, fillsWidth: true, prominent: true)
            StudioMetricCard(value: "\(summary.statValuesWritten)", label: "STAT values", minWidth: 0, accentValue: true, fillsWidth: true, prominent: true)
            StudioMetricCard(value: "\(summary.nameIDsAllocated.count)", label: "New name IDs", minWidth: 0, accentValue: true, fillsWidth: true, prominent: true)
            StudioMetricCard(value: "\(removed)", label: "Removed", minWidth: 0, accentValue: true, fillsWidth: true, prominent: true)
            StudioMetricCard(value: "\(added)", label: "Added", minWidth: 0, accentValue: true, fillsWidth: true, prominent: true)
        }
    }

    @ViewBuilder
    private var filterBadges: some View {
        if let activeTab {
            let counts = categoryCounts(for: activeTab)
            HStack(spacing: SaveReviewLayout.filterBadgeGap) {
                ForEach(SaveReviewDisplayCategory.filterOrder, id: \.self) { category in
                    let count = counts[category, default: 0]
                    if count > 0 {
                        StudioFilterBadge(
                            category: category,
                            count: count,
                            isHidden: isCategoryHidden(category),
                            isIsolated: uiState.isolateCategory == category
                        ) { commandClick in
                            toggleCategory(category, commandClick: commandClick)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text("click to show/hide · ⌘-click to isolate")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var tabChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            StudioSaveReviewTabBar(
                tabs: session.presentation.tabs,
                selectedTab: Binding(
                    get: { selectedTab },
                    set: { newTab in
                        editor.updateSaveReviewUIState(forProjectID: projectID) {
                            $0.selectedTableTab = newTab
                            $0.userPickedTableTab = true
                        }
                    }
                )
            )
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.top, StudioSpace.x2_5)
            .padding(.bottom, StudioSpace.x3)
            .overlay(alignment: .bottom) {
                Rectangle().fill(StudioColors.surfaceStroke).frame(height: 0.5)
            }

            HStack(spacing: StudioSpace.x3) {
                StudioSearchField(
                    text: Binding(
                        get: { uiState.searchQuery },
                        set: { query in
                            editor.updateSaveReviewUIState(forProjectID: projectID) {
                                $0.searchQuery = query
                            }
                        }
                    ),
                    placeholder: "Search rows",
                    compact: true
                )
                .frame(maxWidth: 220)

                if let activeTab {
                    Text(rowCountLabel(for: activeTab))
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                nameidStrategyPreference
            }
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.vertical, SaveReviewLayout.toolRowVerticalPadding)
            .frame(minHeight: SaveReviewLayout.toolRowMinHeight)
            .overlay(alignment: .bottom) {
                Rectangle().fill(StudioColors.surfaceStroke).frame(height: 0.5)
            }
        }
        .background(SaveReviewLayout.toolRowBackground)
    }

    private var nameidStrategyPreference: some View {
        let current = editor.nameidStrategy(forProjectID: projectID, fontID: session.fontID)
        let isLoading = editor.isSaveReviewLoading(forProjectID: projectID, fontID: session.fontID)
        return HStack(spacing: StudioSpacing.controlGap) {
            StudioFieldLabel(
                text: "Feature labels",
                font: StudioTypography.caption,
                rowHeight: StudioFieldMetrics.captionRowHeight,
                foreground: .secondary,
                showsFieldChrome: false
            )
            .fixedSize()

            HStack(spacing: StudioSpacing.instanceRowGap) {
                StudioSegmentButton(
                    title: "Preserve",
                    isSelected: current == .preserve
                ) {
                    editor.setNameIDStrategy(
                        forProjectID: projectID,
                        fontID: session.fontID,
                        strategy: .preserve
                    )
                }
                .disabled(isLoading)
                StudioSegmentButton(
                    title: "Reflow",
                    isSelected: current == .reflow
                ) {
                    editor.setNameIDStrategy(
                        forProjectID: projectID,
                        fontID: session.fontID,
                        strategy: .reflow
                    )
                }
                .disabled(isLoading)
            }
            .padding(StudioCompactControlChrome.trayInset)
            .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
            .fixedSize()
        }
        .layoutPriority(1)
        .help(
            "Preserve keeps existing OpenType feature name IDs. "
                + "Reflow renumbers feature labels starting at 256 so they stay clear of reserved IDs. "
                + "Override for this file only — Settings sets the default."
        )
    }

    @ViewBuilder
    private func headlineView(for tab: SaveReviewTabPresentation) -> some View {
        let headline = tab.headline
        if headline.hasPrefix(tab.label) {
            let suffix = String(headline.dropFirst(tab.label.count))
                .trimmingCharacters(in: .whitespaces)
            HStack(spacing: StudioSpacing.tightGap) {
                Text(tab.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if !suffix.isEmpty {
                    Text(suffix)
                        .foregroundStyle(.secondary)
                }
            }
            .font(StudioTypography.rowName)
        } else {
            Text(headline)
                .font(StudioTypography.rowName)
                .foregroundStyle(.secondary)
        }
    }

    private func rowCountLabel(for tab: SaveReviewTabPresentation) -> String {
        let visible = visibleRowCount(in: tab)
        let total = tab.sections.reduce(0) { $0 + $1.rows.count }
        return "\(visible) of \(total) rows shown"
    }

    // MARK: - Scrollable rows

    @ViewBuilder
    private func rowScrollContent(for tab: SaveReviewTabPresentation) -> some View {
        let sections = filteredSections(for: tab)
        if sections.isEmpty {
            ContentUnavailableView(
                "No matching rows",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(StudioEmptyCopy.reviewNoFilterMatch)
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: fillsAvailableHeight ? 200 : 420, maxHeight: fillsAvailableHeight ? .infinity : 420)
        } else {
            ScrollView {
                // LazyVStack: rows size intrinsically (fixedSize). Avoid maxHeight:.infinity on
                // row content — that previously stretched a subset of rows after export refresh.
                LazyVStack(spacing: 0) {
                    ForEach(sections) { section in
                        StudioSaveReviewPhaseHeader(title: section.title)
                        ForEach(section.rows) { row in
                            StudioStreamlinedDiffRow(row: row)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.bottom, StudioSpacing.panelVertical)
            }
            .scrollContentBackground(.hidden)
            .frame(minHeight: fillsAvailableHeight ? 200 : 420, maxHeight: fillsAvailableHeight ? .infinity : 420)
        }
    }

    private func statusBar(for tab: SaveReviewTabPresentation) -> some View {
        Text(rowCountLabel(for: tab))
            .font(StudioTypography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .frame(height: SaveReviewLayout.statusBarHeight)
            .background(StudioColors.surfaceSubtle)
            .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Filtering

    private func categoryCounts(for tab: SaveReviewTabPresentation) -> [SaveReviewDisplayCategory: Int] {
        var counts: [SaveReviewDisplayCategory: Int] = [:]
        for row in tab.sections.flatMap(\.rows) {
            counts[row.category, default: 0] += 1
        }
        return counts
    }

    private func isCategoryHidden(_ category: SaveReviewDisplayCategory) -> Bool {
        if let isolate = uiState.isolateCategory {
            return category != isolate
        }
        return uiState.hiddenCategories.contains(category)
    }

    private func toggleCategory(_ category: SaveReviewDisplayCategory, commandClick: Bool) {
        editor.updateSaveReviewUIState(forProjectID: projectID) { state in
            if commandClick {
                if state.isolateCategory == category {
                    state.isolateCategory = nil
                } else {
                    state.isolateCategory = category
                    state.hiddenCategories.removeAll()
                }
                return
            }
            state.isolateCategory = nil
            if state.hiddenCategories.contains(category) {
                state.hiddenCategories.remove(category)
            } else {
                state.hiddenCategories.insert(category)
            }
        }
    }

    private func rowIsVisible(_ row: SaveReviewRowPresentation) -> Bool {
        if let isolate = uiState.isolateCategory {
            return row.category == isolate
        }
        return !uiState.hiddenCategories.contains(row.category)
    }

    private func rowMatchesSearch(_ row: SaveReviewRowPresentation) -> Bool {
        let query = uiState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return row.searchText.contains(query)
    }

    private func filteredSections(for tab: SaveReviewTabPresentation) -> [SaveReviewSectionPresentation] {
        tab.sections.compactMap { section in
            let rows = section.rows.filter { rowIsVisible($0) && rowMatchesSearch($0) }
            guard !rows.isEmpty else { return nil }
            return SaveReviewSectionPresentation(title: section.title, rows: rows)
        }
    }

    private func visibleRowCount(in tab: SaveReviewTabPresentation) -> Int {
        filteredSections(for: tab).reduce(0) { $0 + $1.rows.count }
    }

    // MARK: - Cards

    // Yellow-filled banner — mirrors StudioConflictAlert / the Axis Tree plan-warnings band
    // so every "needs attention" notice reads the same across the app.
    @ViewBuilder
    private func warningsCard(_ warnings: [PlanWarning]) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                StudioWarningMessage(message: warning.message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(StudioColors.warningFill, in: RoundedRectangle.studio(StudioRadius.surface))
    }

    @ViewBuilder
    private func errorsCard(_ errors: [CommitError]) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            Text("Cannot export")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                StudioErrorMessage(message: error.message)
            }
        }
        .padding(StudioSpacing.contentInset)
        .background(
            RoundedRectangle.studio(StudioRadius.chip)
                .strokeBorder(StudioColors.errorStroke, lineWidth: StudioStroke.regular)
        )
    }
}
