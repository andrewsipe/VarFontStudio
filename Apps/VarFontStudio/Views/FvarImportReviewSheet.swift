import SwiftUI
import VarFontCore

struct FvarImportReviewSession: Identifiable, Equatable {
    /// Stable per font so the sheet can switch files without remount thrash.
    var id: String { fontID }
    var report: FvarStopSeeder.Report
    var fontID: String
}

/// Import Review for non-orthogonal / sparse fvar seeding decisions.
///
/// The sheet is built around one live number — how many styles the project will
/// generate — with the two kinds of decision that move it split into tabs:
/// Stops (promote / combo-only / ignore, plus name conflicts) and Styles
/// (Format 4 named combinations). Everything opens on its recommendation, so
/// Apply without touching anything is the "accept recommendations" path.
///
/// When several files need review (multi-drop / add), a File row switches between
/// pending sessions. Apply / Cancel finish the active file and advance.
struct FvarImportReviewSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    /// Draft decisions keyed by font so switching File chips keeps in-progress edits.
    @State private var draftsByFontID: [String: FvarImportReviewDraft] = [:]

    private var queue: [FvarImportReviewSession] {
        editor.issueResolvers.fvarImportReviewQueue
    }

    private var session: FvarImportReviewSession? {
        editor.issueResolvers.fvarImportReviewRequest
    }

    var body: some View {
        Group {
            if let session {
                FvarImportReviewContent(
                    session: session,
                    pendingSessions: queue,
                    draft: draftBinding(for: session.fontID),
                    onSelectFont: { editor.issueResolvers.selectFvarImportReviewFont(fontID: $0) },
                    onFinished: { hasMore in
                        if !hasMore {
                            draftsByFontID = [:]
                            dismiss()
                        } else {
                            draftsByFontID.removeValue(forKey: session.fontID)
                        }
                    }
                )
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }

    private func draftBinding(for fontID: String) -> Binding<FvarImportReviewDraft> {
        Binding(
            get: { draftsByFontID[fontID] ?? FvarImportReviewDraft() },
            set: { draftsByFontID[fontID] = $0 }
        )
    }
}

private struct FvarImportReviewDraft {
    var stopDispositions: [String: FvarStopSeeder.StopDisposition] = [:]
    var conflictResolutions: [String: FvarStopSeeder.Resolution] = [:]
    var dismissedCompoundIDs: Set<String> = []
    var promotedStopNames: [String: String] = [:]
    var compoundNames: [String: String] = [:]
    var keepOriginalInstancesOnly = false
    var selectedTabIsStops = true
    var didSeed = false
}

private struct FvarImportReviewContent: View {
    @EnvironmentObject private var editor: EditorViewModel

    private enum ReviewTab {
        case stops
        case styles
    }

    let session: FvarImportReviewSession
    let pendingSessions: [FvarImportReviewSession]
    @Binding var draft: FvarImportReviewDraft
    let onSelectFont: (String) -> Void
    let onFinished: (Bool) -> Void

    /// Scroll-to-focus target while tabbing Style name / Stop name fields.
    @State private var focusedScrollID: String? = nil

    private var stopDispositions: [String: FvarStopSeeder.StopDisposition] {
        get { draft.stopDispositions }
        nonmutating set { draft.stopDispositions = newValue }
    }

    private var conflictResolutions: [String: FvarStopSeeder.Resolution] {
        get { draft.conflictResolutions }
        nonmutating set { draft.conflictResolutions = newValue }
    }

    private var dismissedCompoundIDs: Set<String> {
        get { draft.dismissedCompoundIDs }
        nonmutating set { draft.dismissedCompoundIDs = newValue }
    }

    private var promotedStopNames: [String: String] {
        get { draft.promotedStopNames }
        nonmutating set { draft.promotedStopNames = newValue }
    }

    private var compoundNames: [String: String] {
        get { draft.compoundNames }
        nonmutating set { draft.compoundNames = newValue }
    }

    private var keepOriginalInstancesOnly: Bool {
        get { draft.keepOriginalInstancesOnly }
        nonmutating set { draft.keepOriginalInstancesOnly = newValue }
    }

    private var selectedTab: ReviewTab {
        get { draft.selectedTabIsStops ? .stops : .styles }
        nonmutating set { draft.selectedTabIsStops = (newValue == .stops) }
    }

    private var report: FvarStopSeeder.Report { session.report }

    private var openProjectForFont: OpenProject? {
        editor.openProjects.first { project in
            project.document.fonts.contains { $0.id == session.fontID }
        }
    }

    private var font: FontDocument? {
        openProjectForFont?.document.fonts.first { $0.id == session.fontID }
    }

    private var fileDisplayName: String {
        guard let font else { return "Font" }
        return editor.fontBasename(for: font)
    }

    private var namingOrder: [String] {
        openProjectForFont?.document.naming.order ?? font?.axes.map(\.tag) ?? []
    }

    private var reviewAxes: [AxisDefinition] {
        font?.axes ?? []
    }

    private var sortedCompoundSuggestions: [FvarStopSeeder.CompoundSuggestion] {
        CompoundStatNaming.sortedByAxisOrder(
            report.compoundSuggestions,
            coords: { $0.coords },
            name: { $0.name },
            axes: reviewAxes,
            namingOrder: namingOrder
        )
    }

    private var sortedHeldStopCandidates: [FvarStopSeeder.StopCandidate] {
        let axisRank = Dictionary(uniqueKeysWithValues: namingOrder.enumerated().map { ($0.element, $0.offset) })
        return report.heldStopCandidates.sorted { lhs, rhs in
            let leftRank = axisRank[lhs.axisTag] ?? Int.max
            let rightRank = axisRank[rhs.axisTag] ?? Int.max
            if leftRank != rightRank { return leftRank < rightRank }
            if lhs.axisTag != rhs.axisTag {
                return lhs.axisTag.localizedCaseInsensitiveCompare(rhs.axisTag) == .orderedAscending
            }
            if let axis = reviewAxes.first(where: { $0.tag == lhs.axisTag }) {
                let comparison = CompoundStatNaming.compareCoords(
                    [lhs.axisTag: lhs.value],
                    [rhs.axisTag: rhs.value],
                    axes: [axis],
                    namingOrder: namingOrder
                )
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            } else if !AxisCoordinate.valuesEqual(lhs.value, rhs.value) {
                return lhs.value < rhs.value
            }
            return lhs.proposedName.localizedCaseInsensitiveCompare(rhs.proposedName) == .orderedAscending
        }
    }

    private var axisLabelByTag: [String: String] {
        Dictionary(
            uniqueKeysWithValues: (font?.axes ?? []).map { ($0.tag, $0.displayName ?? $0.tag) }
        )
    }

    // MARK: - Derived state

    private var hasStopsTab: Bool {
        !report.heldStopCandidates.isEmpty
            || !report.conflicts.isEmpty
            || !(report.namingSparsity?.isEmpty ?? true)
            || report.codedNaming != nil
    }

    private var hasStylesTab: Bool { !report.compoundSuggestions.isEmpty }

    private var hasDecisionSections: Bool { hasStopsTab || hasStylesTab }

    private var recommendedStopDispositions: [String: FvarStopSeeder.StopDisposition] {
        Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
            ($0.id, $0.recommendedDisposition)
        })
    }

    private func disposition(for candidate: FvarStopSeeder.StopCandidate) -> FvarStopSeeder.StopDisposition {
        stopDispositions[candidate.id] ?? candidate.recommendedDisposition
    }

    /// Live style-grid size. Falls back to the report's static projection when the font
    /// is somehow unavailable (project closed out from under the sheet).
    private var projectedStyleCount: Int? {
        guard let font else { return report.orthogonality?.projectedAnalyticCount }
        let acceptedCoords = report.compoundSuggestions
            .filter { !dismissedCompoundIDs.contains($0.id) }
            .map(\.coords)
        return FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: report.heldStopCandidates,
            decisions: stopDispositions,
            acceptedCompoundCoords: acceptedCoords
        )
    }

    private var liveExpansion: FvarStopSeeder.ExpansionCallout? {
        guard let context = report.expansionPreview else { return report.expansionCallouts.first }
        return FvarStopSeeder.previewExpansion(
            context: context,
            decisions: stopDispositions,
            recommended: recommendedStopDispositions,
            promotedNames: promotedStopNames
        )
    }

    private var inventedCombinationCount: Int {
        liveExpansion?.inventedCombinationCount ?? 0
    }

    private var isDeviatingFromRecommendations: Bool {
        report.heldStopCandidates.contains { disposition(for: $0) != $0.recommendedDisposition }
            || report.conflicts.contains {
                (conflictResolutions[$0.id] ?? $0.recommendedResolution) != $0.recommendedResolution
            }
            || !dismissedCompoundIDs.isEmpty
            || report.compoundSuggestions.contains {
                let override = compoundNames[$0.id] ?? $0.name
                return override != $0.name
            }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x5) {
            header
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StudioSpace.x5) {
                        outcomeSection
                        if hasStopsTab, hasStylesTab {
                            tabBar
                        }
                        if hasDecisionSections {
                            if selectedTab == .stops, hasStopsTab {
                                stopsTabContent
                            } else if hasStylesTab {
                                stylesTabContent
                            }
                        }
                    }
                    // Keep cards clear of the overlay scrollbar (sheet padding alone is not enough).
                    .padding(.trailing, StudioSpacing.contentInset)
                }
                .frame(maxHeight: 500)
                .onChange(of: focusedScrollID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        scrollProxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            actionBar
        }
        .padding(StudioSpace.x5)
        .frame(minWidth: 580, idealWidth: 620)
        .onAppear { seedDefaultsIfNeeded() }
        .onChange(of: session.fontID) { _, _ in
            focusedScrollID = nil
            seedDefaultsIfNeeded()
        }
    }

    private func seedDefaultsIfNeeded() {
        guard !draft.didSeed else { return }
        resetToRecommendations()
        selectedTab = hasStopsTab ? .stops : .styles
        draft.didSeed = true
    }

    private func resetToRecommendations() {
        for candidate in report.heldStopCandidates {
            stopDispositions[candidate.id] = candidate.recommendedDisposition
            promotedStopNames[candidate.id] = candidate.proposedName
        }
        for conflict in report.conflicts {
            conflictResolutions[conflict.id] = conflict.recommendedResolution
        }
        for suggestion in report.compoundSuggestions {
            compoundNames[suggestion.id] = suggestion.name
        }
        dismissedCompoundIDs = []
        // Default: export all projected instances (checked). Uncheck to keep origin-only.
        keepOriginalInstancesOnly = false
    }

    // MARK: - Header / outcome

    private var header: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x4) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                HStack(alignment: .center, spacing: StudioSpacing.controlGap) {
                    Text("Import Review")
                        .font(StudioTypography.projectTitle)
                    fileNamePill
                }
                Text(headerSubtitle)
                    .font(StudioTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if pendingSessions.count > 1 {
                fileTabBar
            }
        }
    }

    /// Mirrors File-chip chrome with secondary type so the name doesn’t compete with the title.
    private var fileNamePill: some View {
        Text(fileDisplayName)
            .font(StudioTypography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, StudioFieldMetrics.tabChipHorizontalPadding)
            .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
            .frame(minHeight: StudioFieldMetrics.tabChipRowHeight)
            .background(Color.primary.opacity(0.04), in: Capsule())
            .help(fileDisplayName)
            .accessibilityLabel("File \(fileDisplayName)")
    }

    private var headerSubtitle: String {
        if !hasDecisionSections {
            return "Stops seeded normally — a few instance names are just thin or repeated."
        }
        return "Some of this font’s values don’t map cleanly to a style of their own."
    }

    private var fileTabBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioSectionLabel(title: "File")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StudioSpacing.tightGap) {
                    ForEach(pendingSessions) { pending in
                        fileChip(pending)
                    }
                }
            }
        }
    }

    private func fileChip(_ pending: FvarImportReviewSession) -> some View {
        let isSelected = pending.fontID == session.fontID
        let title = displayName(for: pending.fontID)
        return Button {
            onSelectFont(pending.fontID)
        } label: {
            StudioTabChip(isSelected: isSelected) {
                Text(title)
                    .font(StudioTypography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            } trailing: {
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .capsule)
        .help(title)
    }

    private func displayName(for fontID: String) -> String {
        for project in editor.openProjects {
            if let font = project.document.fonts.first(where: { $0.id == fontID }) {
                return editor.fontBasename(for: font)
            }
        }
        return "Font"
    }

    /// The one number the whole sheet is about: how many styles the project will make.
    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x4) {
                if let original = report.orthogonality?.originalInstanceCount {
                    metricBlock(
                        value: "\(original)",
                        label: "in the font",
                        tint: .primary
                    )
                    Image(systemName: "arrowshape.right.fill")
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, StudioSpace.x1)
                }
                if let projected = projectedStyleCount {
                    projectedBlock(projected)
                }
                Spacer(minLength: 0)
            }

            if inventedCombinationCount > 0 {
                keepOriginalToggle
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.surface))
    }

    private func projectedBlock(_ projected: Int) -> some View {
        let delta = (report.orthogonality?.originalInstanceCount).map { projected - $0 } ?? 0
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text("\(projected)")
                .font(StudioTypography.statValue)
                .monospacedDigit()
                .foregroundStyle(StudioColors.metricForeground)
            HStack(spacing: StudioSpace.x1) {
                Text("in the project")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                if delta > 0 {
                    Text("+\(delta)")
                        .font(StudioTypography.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(StudioColors.metricForeground)
                }
            }
        }
    }

    private func metricBlock(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text(value)
                .font(StudioTypography.statValue)
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var keepOriginalToggle: some View {
        let exportAllInstances = !keepOriginalInstancesOnly
        let original = report.orthogonality?.originalInstanceCount
        let projected = projectedStyleCount
        let title: String = {
            if exportAllInstances {
                if let projected {
                    return "Activate Export for all \(projected) instances."
                }
                return "Activate Export for all instances."
            }
            if let original {
                return "Activate Export for origin file’s \(original) instances only."
            }
            return "Activate Export for origin file’s instances only."
        }()
        return Button {
            keepOriginalInstancesOnly.toggle()
        } label: {
            HStack(spacing: StudioSpacing.controlGap) {
                StudioIncludeCheckbox(isOn: exportAllInstances) {
                    keepOriginalInstancesOnly.toggle()
                }
                Text(title)
                    .font(StudioTypography.body)
                    .foregroundStyle(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(
            exportAllInstances
                ? "Exports every projected style, including combinations the font didn’t have."
                : "New combinations stay in the plan so you can name them, but won’t export unless you include them later."
        )
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: StudioSpace.x1) {
            tabButton(
                .stops,
                title: "Stops",
                count: report.heldStopCandidates.count + report.conflicts.count
            )
            tabButton(.styles, title: "Styles", count: report.compoundSuggestions.count)
            Spacer(minLength: 0)
        }
    }

    private func tabButton(_ tab: ReviewTab, title: String, count: Int) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Text(title)
                    .font(StudioTypography.bodyMedium.weight(isSelected ? .semibold : .regular))
                if count > 0 {
                    StudioCountBadge(text: "\(count)", highlighted: isSelected)
                }
            }
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .background(
                isSelected ? StudioColors.surfaceInset : Color.clear,
                in: RoundedRectangle.studio(StudioRadius.chip)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stops tab

    private var stopsTabContent: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x5) {
            if !report.conflicts.isEmpty {
                conflictsSection
            }
            if !report.heldStopCandidates.isEmpty {
                stopsSection
            }
            if let sparsity = report.namingSparsity, !sparsity.isEmpty {
                sparsitySection(sparsity)
            }
            if let coded = report.codedNaming {
                codedNamingSection(coded)
            }
        }
    }

    private var stopsToDecideTitle: String {
        "Stops to decide (\(report.heldStopCandidates.count))"
    }

    private var stopsToDecideCaption: String {
        let grouped = Dictionary(grouping: sortedHeldStopCandidates, by: \.axisTag)
        if grouped.count > 1 {
            let parts = namingOrder.filter { grouped[$0] != nil }.map { tag in
                "\(grouped[tag]?.count ?? 0) \(tag)"
            } + grouped.keys.filter { !namingOrder.contains($0) }.sorted().map { tag in
                "\(grouped[tag]?.count ?? 0) \(tag)"
            }
            return "\(parts.joined(separator: " · ")). Each one opens on our recommendation — change any of them."
        }
        return "Each one opens on our recommendation — change any of them."
    }

    private var stopsSection: some View {
        reviewSection(
            title: stopsToDecideTitle,
            caption: stopsToDecideCaption
        ) {
            rowStack(sortedHeldStopCandidates) { candidate in
                stopRow(candidate)
                    .id(stopScrollID(candidate.id))
            }
            if inventedCombinationCount > 0, let expansion = liveExpansion {
                inventedCombinations(expansion)
            } else if report.expansionPreview != nil {
                Text("No styles beyond the ones already in the font.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stopRow(_ candidate: FvarStopSeeder.StopCandidate) -> some View {
        let current = disposition(for: candidate)
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                StudioTagPill(text: candidate.axisTag, compact: true)
                Text(candidate.proposedName)
                    .font(StudioTypography.bodyMedium)
                    .lineLimit(1)
                Text(AxisCoordinateFormat.format(candidate.value))
                    .font(StudioTypography.monoValue)
                    .foregroundStyle(.secondary)
                Spacer(minLength: StudioSpace.x4)
                HStack(spacing: StudioSpacing.tightGap) {
                    stopToggle(candidate, title: "Stop", kind: .stop)
                    stopToggle(candidate, title: "Combo", kind: .combo)
                    stopToggle(candidate, title: "Neither", kind: .neither)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                Text(classificationLabel(candidate.classification))
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: StudioSpace.x4)
                if current != candidate.recommendedDisposition {
                    Button("Reset to \(dispositionTitle(candidate.recommendedDisposition))") {
                        stopDispositions[candidate.id] = candidate.recommendedDisposition
                    }
                    .buttonStyle(.plain)
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.metricForeground)
                }
            }
            if current.asStop {
                HStack(spacing: StudioSpacing.controlGap) {
                    Text("Stop name")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                    StudioTextField(
                        placeholder: "Name",
                        text: promotedNameBinding(for: candidate),
                        font: StudioTypography.body,
                        rowHeight: StudioFieldMetrics.bodyRowHeight,
                        onFocused: { focusedScrollID = stopScrollID(candidate.id) }
                    )
                    .frame(maxWidth: 220)
                }
                .padding(.top, StudioSpacing.tightGap)
            }
        }
    }

    private func classificationLabel(_ classification: FvarStopSeeder.StopClassification) -> String {
        switch classification {
        case .safeUnivariate:
            return "Safe to add on its own."
        case .comboOnly:
            return "Only ever appears paired with another axis."
        case .ambiguous:
            return "No clear style of its own in the instance names."
        }
    }

    private func dispositionTitle(_ disposition: FvarStopSeeder.StopDisposition) -> String {
        switch (disposition.asStop, disposition.asCombo) {
        case (true, true): return "Stop + Combo"
        case (true, false): return "Stop"
        case (false, true): return "Combo"
        case (false, false): return "Neither"
        }
    }

    private enum StopToggleKind {
        case stop
        case combo
        case neither
    }

    private func stopToggle(
        _ candidate: FvarStopSeeder.StopCandidate,
        title: String,
        kind: StopToggleKind
    ) -> some View {
        let current = disposition(for: candidate)
        let selected: Bool = {
            switch kind {
            case .stop: return current.asStop
            case .combo: return current.asCombo
            case .neither: return current.isNeither
            }
        }()
        return choiceChip(
            title: title,
            selected: selected,
            selectedFill: {
                switch kind {
                case .stop: return StudioColors.surfaceInset
                case .combo: return StudioColors.statFormat4Background
                case .neither: return StudioColors.surfaceInset
                }
            }(),
            selectedForeground: {
                switch kind {
                case .combo: return StudioColors.statFormat4
                case .stop, .neither: return Color.primary
                }
            }(),
            selectedStroke: {
                switch kind {
                case .combo: return StudioColors.statFormat4Stroke
                case .stop, .neither: return StudioColors.surfaceStrokeStrong
                }
            }(),
            help: {
                switch kind {
                case .stop:
                    return "Add as a stop on the axis — every existing style gets a version at this value."
                case .combo:
                    return "Keep this value available inside named combinations (Format 4)."
                case .neither:
                    return "Leave this value out of both stops and combinations."
                }
            }()
        ) {
            switch kind {
            case .stop:
                var next = current
                next.asStop.toggle()
                stopDispositions[candidate.id] = next
            case .combo:
                var next = current
                next.asCombo.toggle()
                stopDispositions[candidate.id] = next
            case .neither:
                stopDispositions[candidate.id] = .neither
            }
        }
    }

    private func promotedNameBinding(for candidate: FvarStopSeeder.StopCandidate) -> Binding<String> {
        Binding(
            get: { promotedStopNames[candidate.id] ?? candidate.proposedName },
            set: { promotedStopNames[candidate.id] = $0 }
        )
    }

    private func inventedCombinations(_ callout: FvarStopSeeder.ExpansionCallout) -> some View {
        let count = callout.inventedCombinationCount
        let samples = callout.samples
        return VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(count) combination\(count == 1 ? "" : "s") the font didn’t have")
                    .font(StudioTypography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Shown at one weight — each repeats across every weight.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                        HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                            Text(sample.composedName.isEmpty ? sample.coordLabel : sample.composedName)
                                .font(StudioTypography.body)
                            Spacer(minLength: StudioSpace.x4)
                            if !sample.composedName.isEmpty {
                                Text(sample.coordLabel)
                                    .font(StudioTypography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: samples.count > 4 ? 140 : nil)
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.control))
    }

    private var conflictsSection: some View {
        reviewSection(
            title: "Name conflicts",
            caption: "STAT and the font disagree on these labels."
        ) {
            rowStack(report.conflicts) { conflict in
                VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                    HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                        Text(conflict.axisLabel)
                            .font(StudioTypography.bodyMedium)
                        Text(AxisCoordinateFormat.format(conflict.value))
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: StudioSpace.x4)
                        HStack(spacing: StudioSpacing.tightGap) {
                            conflictChoice(conflict, title: conflict.existingName, resolution: .keepSTAT)
                            conflictChoice(conflict, title: conflict.fvarName, resolution: .takeFvar)
                        }
                    }
                    Text(conflictStatus(conflict))
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func conflictStatus(_ conflict: FvarStopSeeder.NameConflict) -> String {
        switch conflictResolutions[conflict.id] ?? conflict.recommendedResolution {
        case .keepSTAT:
            return "Keeping “\(conflict.existingName)”"
        case .takeFvar:
            return "Using “\(conflict.fvarName)” from the font"
        case .custom(let name):
            return "Using “\(name)”"
        }
    }

    private func conflictChoice(
        _ conflict: FvarStopSeeder.NameConflict,
        title: String,
        resolution: FvarStopSeeder.Resolution
    ) -> some View {
        choiceChip(
            title: title,
            selected: (conflictResolutions[conflict.id] ?? conflict.recommendedResolution) == resolution,
            help: resolution == .keepSTAT ? "Keep the STAT label" : "Use the name from the font"
        ) {
            conflictResolutions[conflict.id] = resolution
        }
    }

    private func sparsitySection(_ sparsity: FvarStopSeeder.NamingSparsityCallout) -> some View {
        reviewSection(
            title: "Instance names",
            caption: "Nothing to decide — just worth cleaning up in the Axis Tree later."
        ) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                Text(sparsity.message)
                    .font(StudioTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(sparsity.sharedNameSamples, id: \.self) { sample in
                    Text(sample)
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(StudioSpacing.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.control))
        }
    }

    private func codedNamingSection(_ coded: InstanceCodedNaming.Detection) -> some View {
        reviewSection(
            title: "Coded instance names",
            caption: "Nothing to decide here. The Code tool can recreate this after import."
        ) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                Text(coded.message)
                    .font(StudioTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text(coded.prefixes.joined(separator: " · "))
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
            }
            .padding(StudioSpacing.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.control))
        }
    }

    // MARK: - Styles tab

    private var stylesTabContent: some View {
        reviewSection(
            title: "Named combinations",
            caption: "Format 4 styles for entangled coordinates — rename any of them."
        ) {
            rowStack(sortedCompoundSuggestions) { suggestion in
                compoundRow(suggestion)
                    .id(compoundScrollID(suggestion.id))
            }
        }
    }

    private func compoundRow(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        let included = !dismissedCompoundIDs.contains(suggestion.id)
        let tags = orderedCoordTags(for: suggestion.coords)
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Button {
                toggleCompound(suggestion)
            } label: {
                HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                    StudioIncludeCheckbox(isOn: included) {
                        toggleCompound(suggestion)
                    }
                    .padding(.top, 1)
                    VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                        HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                            HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
                                Text("=")
                                    .font(StudioTypography.caption)
                                    .foregroundStyle(.tertiary)
                                compoundCoordTokens(tags: tags, suggestion: suggestion)
                            }
                            Spacer(minLength: StudioSpace.x4)
                            Text(coverageLabel(suggestion))
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(compoundLegSummary(suggestion))
                            .font(StudioTypography.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .opacity(included ? 1 : 0.5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: StudioSpacing.controlGap) {
                Text("Style name")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                StudioTextField(
                    placeholder: "Name",
                    text: compoundNameBinding(for: suggestion),
                    font: StudioTypography.bodyMedium,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    onFocused: { focusedScrollID = compoundScrollID(suggestion.id) }
                )
                .frame(maxWidth: 280)
                .disabled(!included)
            }
            .padding(.leading, StudioSpace.x5)
            .opacity(included ? 1 : 0.5)
        }
    }

    private func compoundNameBinding(for suggestion: FvarStopSeeder.CompoundSuggestion) -> Binding<String> {
        Binding(
            get: { compoundNames[suggestion.id] ?? suggestion.name },
            set: { compoundNames[suggestion.id] = $0 }
        )
    }

    @ViewBuilder
    private func compoundCoordTokens(
        tags: [String],
        suggestion: FvarStopSeeder.CompoundSuggestion
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text("×")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                }
                Text(AxisCoordinateFormat.format(suggestion.coords[tag] ?? 0))
                    .font(StudioTypography.monoValue)
                    .foregroundStyle(.secondary)
                StudioTagPill(text: tag, compact: true)
            }
        }
    }

    private func toggleCompound(_ suggestion: FvarStopSeeder.CompoundSuggestion) {
        if dismissedCompoundIDs.contains(suggestion.id) {
            dismissedCompoundIDs.remove(suggestion.id)
        } else {
            dismissedCompoundIDs.insert(suggestion.id)
        }
    }

    private func coverageLabel(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> String {
        guard let original = report.orthogonality?.originalInstanceCount, original > 0 else {
            return "covers \(suggestion.coveredInstanceCount) styles"
        }
        return "covers \(suggestion.coveredInstanceCount) of \(original)"
    }

    /// Axis-label line. Quoted stop names update live when a matching held stop is promoted.
    private func compoundLegSummary(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> String {
        let axisLabels = axisLabelByTag
        return orderedCoordTags(for: suggestion.coords).map { tag in
            let axisLabel = axisLabels[tag] ?? tag
            let value = suggestion.coords[tag] ?? 0
            let stopName = resolvedStopName(tag: tag, value: value, suggestion: suggestion)
            return "\(axisLabel) “\(stopName)”"
        }.joined(separator: " × ")
    }

    private func orderedCoordTags(for coords: [String: Double]) -> [String] {
        let present = Set(coords.keys)
        var ordered: [String] = []
        var seen = Set<String>()
        for tag in namingOrder where present.contains(tag) {
            ordered.append(tag)
            seen.insert(tag)
        }
        for axis in reviewAxes where present.contains(axis.tag) && !seen.contains(axis.tag) {
            ordered.append(axis.tag)
            seen.insert(axis.tag)
        }
        for tag in present.subtracting(seen).sorted() {
            ordered.append(tag)
        }
        return ordered
    }

    private func compoundScrollID(_ id: String) -> String { "import-compound-\(id)" }
    private func stopScrollID(_ id: String) -> String { "import-stop-\(id)" }

    private func resolvedStopName(
        tag: String,
        value: Double,
        suggestion: FvarStopSeeder.CompoundSuggestion
    ) -> String {
        if let held = report.heldStopCandidates.first(where: {
            $0.axisTag == tag && AxisCoordinate.valuesEqual($0.value, value)
        }), disposition(for: held).asStop {
            let override = (promotedStopNames[held.id] ?? held.proposedName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !override.isEmpty { return override }
        }
        if let label = suggestion.legLabels[tag]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !label.isEmpty {
            return label
        }
        return AxisCoordinateFormat.format(value)
    }

    // MARK: - Shared chrome

    private func reviewSection<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(StudioTypography.emphasis)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }

    /// One surface for a set of decisions, hairline-separated — avoids a stack of
    /// competing card boxes when several rows sit under the same heading.
    private func rowStack<Item: Identifiable, Row: View>(
        _ items: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(StudioColors.surfaceStroke)
                        .frame(height: StudioStroke.hairline)
                }
                row(item)
                    .padding(StudioSpacing.contentInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.control))
    }

    private func choiceChip(
        title: String,
        selected: Bool,
        selectedFill: Color = StudioColors.surfaceInset,
        selectedForeground: Color = .primary,
        selectedStroke: Color = StudioColors.surfaceStrokeStrong,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(StudioTypography.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? selectedForeground : Color.secondary)
                .lineLimit(1)
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                .background(
                    selected ? selectedFill : StudioColors.surfaceSubtle,
                    in: RoundedRectangle.studio(StudioRadius.chip)
                )
                .overlay {
                    RoundedRectangle.studio(StudioRadius.chip)
                        .strokeBorder(
                            selected ? selectedStroke : StudioColors.surfaceStroke,
                            lineWidth: StudioStroke.hairline
                        )
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var actionBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioFlatButton(title: cancelTitle, role: .destructiveAction, size: .compact) {
                onFinished(editor.cancelFvarImportReview())
            }
            if isDeviatingFromRecommendations {
                StudioFlatButton(title: "Reset to recommendations", size: .compact) {
                    resetToRecommendations()
                }
            }
            Spacer()
            StudioFlatButton(title: applyTitle, role: .primary, size: .compact) {
                applyCurrentDecisions()
            }
        }
    }

    private var cancelTitle: String {
        pendingSessions.count > 1 ? "Cancel this file" : "Cancel import"
    }

    private var applyTitle: String {
        pendingSessions.count > 1 ? "Apply & continue" : "Apply"
    }

    private func applyCurrentDecisions() {
        let accepted = Set(report.compoundSuggestions.map(\.id)).subtracting(dismissedCompoundIDs)
        let hasMore = editor.applyFvarImportReview(
            FvarStopSeeder.ReviewDecisions(
                stopDispositions: stopDispositions,
                conflictResolutions: conflictResolutions,
                acceptedCompoundIDs: accepted,
                dismissedCompoundIDs: dismissedCompoundIDs,
                promotedStopNames: promotedStopNames,
                compoundNames: compoundNames,
                keepOriginalInstancesOnly: inventedCombinationCount > 0 && keepOriginalInstancesOnly
            )
        )
        onFinished(hasMore)
    }
}
