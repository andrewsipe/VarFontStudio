import SwiftUI
import VarFontCore

struct FvarImportReviewSession: Identifiable {
    let id = UUID()
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
struct FvarImportReviewSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    private enum ReviewTab {
        case stops
        case styles
    }

    let session: FvarImportReviewSession

    @State private var stopDecisions: [String: FvarStopSeeder.StopDecision] = [:]
    @State private var conflictResolutions: [String: FvarStopSeeder.Resolution] = [:]
    @State private var dismissedCompoundIDs: Set<String> = []
    @State private var promotedStopNames: [String: String] = [:]
    @State private var keepOriginalInstancesOnly = false
    @State private var selectedTab: ReviewTab = .stops

    private var report: FvarStopSeeder.Report { session.report }

    private var font: FontDocument? {
        editor.project?.fonts.first { $0.id == session.fontID }
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
    }

    private var hasStylesTab: Bool { !report.compoundSuggestions.isEmpty }

    private var hasDecisionSections: Bool { hasStopsTab || hasStylesTab }

    private var recommendedStopDecisions: [String: FvarStopSeeder.StopDecision] {
        Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
            ($0.id, $0.recommendedDecision)
        })
    }

    private func decision(for candidate: FvarStopSeeder.StopCandidate) -> FvarStopSeeder.StopDecision {
        stopDecisions[candidate.id] ?? candidate.recommendedDecision
    }

    /// Live style-grid size. Falls back to the report's static projection when the font
    /// is somehow unavailable (project closed out from under the sheet).
    private var projectedStyleCount: Int? {
        guard let font else { return report.orthogonality?.projectedAnalyticCount }
        return FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: report.heldStopCandidates,
            decisions: stopDecisions
        )
    }

    private var liveExpansion: FvarStopSeeder.ExpansionCallout? {
        guard let context = report.expansionPreview else { return report.expansionCallouts.first }
        return FvarStopSeeder.previewExpansion(
            context: context,
            decisions: stopDecisions,
            recommended: recommendedStopDecisions,
            promotedNames: promotedStopNames
        )
    }

    private var inventedCombinationCount: Int {
        liveExpansion?.inventedCombinationCount ?? 0
    }

    private var isDeviatingFromRecommendations: Bool {
        report.heldStopCandidates.contains { decision(for: $0) != $0.recommendedDecision }
            || report.conflicts.contains {
                (conflictResolutions[$0.id] ?? $0.recommendedResolution) != $0.recommendedResolution
            }
            || !dismissedCompoundIDs.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x5) {
            header
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
            actionBar
        }
        .padding(StudioSpace.x5)
        .frame(minWidth: 580, idealWidth: 620)
        .onAppear { seedDefaults() }
    }

    private func seedDefaults() {
        resetToRecommendations()
        selectedTab = hasStopsTab ? .stops : .styles
    }

    private func resetToRecommendations() {
        for candidate in report.heldStopCandidates {
            stopDecisions[candidate.id] = candidate.recommendedDecision
            promotedStopNames[candidate.id] = candidate.proposedName
        }
        for conflict in report.conflicts {
            conflictResolutions[conflict.id] = conflict.recommendedResolution
        }
        dismissedCompoundIDs = []
        // Default: export all projected instances (checked). Uncheck to keep origin-only.
        keepOriginalInstancesOnly = false
    }

    // MARK: - Header / outcome

    private var header: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text("Import Review")
                .font(StudioTypography.projectTitle)
            Text(headerSubtitle)
                .font(StudioTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerSubtitle: String {
        if !hasDecisionSections {
            return "Stops seeded normally — a few instance names are just thin or repeated."
        }
        return "Some of this font’s values don’t map cleanly to a style of their own."
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
        }
    }

    private var stopsSection: some View {
        reviewSection(
            title: "Stops to decide",
            caption: "Each one opens on our recommendation — change any of them."
        ) {
            rowStack(report.heldStopCandidates) { candidate in
                stopRow(candidate)
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
        let current = decision(for: candidate)
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                StudioTagPill(text: candidate.axisTag, compact: true)
                Text(candidate.axisLabel)
                    .font(StudioTypography.bodyMedium)
                Text(AxisCoordinateFormat.format(candidate.value))
                    .font(StudioTypography.monoValue)
                    .foregroundStyle(.secondary)
                Spacer(minLength: StudioSpace.x4)
                HStack(spacing: StudioSpacing.tightGap) {
                    stopChoice(candidate, title: "Promote", decision: .promote)
                    stopChoice(candidate, title: "Combo only", decision: .comboOnly)
                    stopChoice(candidate, title: "Ignore", decision: .ignore)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.controlGap) {
                Text(classificationLabel(candidate.classification))
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: StudioSpace.x4)
                if current != candidate.recommendedDecision {
                    Button("Reset to \(decisionTitle(candidate.recommendedDecision))") {
                        stopDecisions[candidate.id] = candidate.recommendedDecision
                    }
                    .buttonStyle(.plain)
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.metricForeground)
                }
            }
            if current == .promote {
                HStack(spacing: StudioSpacing.controlGap) {
                    Text("Stop name")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                    StudioTextField(
                        placeholder: "Name",
                        text: promotedNameBinding(for: candidate),
                        font: StudioTypography.body,
                        rowHeight: StudioFieldMetrics.bodyRowHeight
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

    private func decisionTitle(_ decision: FvarStopSeeder.StopDecision) -> String {
        switch decision {
        case .promote: return "Promote"
        case .comboOnly: return "Combo only"
        case .ignore: return "Ignore"
        }
    }

    private func decisionHelp(_ decision: FvarStopSeeder.StopDecision) -> String {
        switch decision {
        case .promote:
            return "Add as a stop on the axis — every existing style gets a version at this value."
        case .comboOnly:
            return "No stop of its own — the value stays available inside named combinations."
        case .ignore:
            return "Leave this value out entirely."
        }
    }

    private func stopChoice(
        _ candidate: FvarStopSeeder.StopCandidate,
        title: String,
        decision: FvarStopSeeder.StopDecision
    ) -> some View {
        choiceChip(
            title: title,
            selected: self.decision(for: candidate) == decision,
            help: decisionHelp(decision)
        ) {
            stopDecisions[candidate.id] = decision
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

    // MARK: - Styles tab

    private var stylesTabContent: some View {
        reviewSection(
            title: "Named combinations",
            caption: "Recurring pairings found in the instance names, included by default."
        ) {
            rowStack(report.compoundSuggestions) { suggestion in
                compoundRow(suggestion)
            }
        }
    }

    private func compoundRow(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> some View {
        let included = !dismissedCompoundIDs.contains(suggestion.id)
        let tags = suggestion.coords.keys.sorted()
        return Button {
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
                            Text(suggestion.name)
                                .font(StudioTypography.bodyMedium)
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
        return suggestion.coords.keys.sorted().map { tag in
            let axisLabel = axisLabels[tag] ?? tag
            let value = suggestion.coords[tag] ?? 0
            let stopName = resolvedStopName(tag: tag, value: value, suggestion: suggestion)
            return "\(axisLabel) “\(stopName)”"
        }.joined(separator: " × ")
    }

    private func resolvedStopName(
        tag: String,
        value: Double,
        suggestion: FvarStopSeeder.CompoundSuggestion
    ) -> String {
        if let held = report.heldStopCandidates.first(where: {
            $0.axisTag == tag && AxisCoordinate.valuesEqual($0.value, value)
        }), decision(for: held) == .promote {
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
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(StudioTypography.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                .background(
                    selected ? StudioColors.surfaceInset : StudioColors.surfaceSubtle,
                    in: RoundedRectangle.studio(StudioRadius.chip)
                )
                .overlay {
                    RoundedRectangle.studio(StudioRadius.chip)
                        .strokeBorder(
                            selected ? StudioColors.surfaceStrokeStrong : StudioColors.surfaceStroke,
                            lineWidth: StudioStroke.hairline
                        )
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var actionBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioFlatButton(title: "Cancel import", role: .destructiveAction, size: .compact) {
                editor.cancelFvarImportReview()
                dismiss()
            }
            if isDeviatingFromRecommendations {
                StudioFlatButton(title: "Reset to recommendations", size: .compact) {
                    resetToRecommendations()
                }
            }
            Spacer()
            StudioFlatButton(title: "Apply", role: .primary, size: .compact) {
                applyCurrentDecisions()
            }
        }
    }

    private func applyCurrentDecisions() {
        let accepted = Set(report.compoundSuggestions.map(\.id)).subtracting(dismissedCompoundIDs)
        editor.applyFvarImportReview(
            FvarStopSeeder.ReviewDecisions(
                stopDecisions: stopDecisions,
                conflictResolutions: conflictResolutions,
                acceptedCompoundIDs: accepted,
                dismissedCompoundIDs: dismissedCompoundIDs,
                promotedStopNames: promotedStopNames,
                keepOriginalInstancesOnly: inventedCombinationCount > 0 && keepOriginalInstancesOnly
            )
        )
        dismiss()
    }
}
