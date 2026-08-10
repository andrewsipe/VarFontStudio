import SwiftUI
import VarFontCore

struct FvarImportReviewSession: Identifiable {
    let id = UUID()
    var report: FvarStopSeeder.Report
    var fontID: String
}

/// Import Review for non-orthogonal / sparse fvar seeding decisions.
///
/// Flow: orient (summary + accept recommendations) → decide held stops with a live
/// expansion consequence → optional Format 4 adds. Expansion is not its own decision step.
struct FvarImportReviewSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: FvarImportReviewSession

    @State private var stopDecisions: [String: FvarStopSeeder.StopDecision] = [:]
    @State private var conflictResolutions: [String: FvarStopSeeder.Resolution] = [:]
    @State private var acceptedCompoundIDs: Set<String> = []
    @State private var dismissedCompoundIDs: Set<String> = []
    @State private var promotedStopNames: [String: String] = [:]
    @State private var reviewExpanded = false

    private var report: FvarStopSeeder.Report { session.report }

    private var recommendedStopDecisions: [String: FvarStopSeeder.StopDecision] {
        Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
            ($0.id, $0.recommendedDecision)
        })
    }

    private var liveExpansion: FvarStopSeeder.ExpansionCallout? {
        if let context = report.expansionPreview {
            return FvarStopSeeder.previewExpansion(
                context: context,
                decisions: stopDecisions,
                recommended: recommendedStopDecisions,
                promotedNames: promotedStopNames
            )
        }
        return report.expansionCallouts.first
    }

    private var decisionsMatchRecommendations: Bool {
        report.heldStopCandidates.allSatisfy { candidate in
            (stopDecisions[candidate.id] ?? candidate.recommendedDecision) == candidate.recommendedDecision
        }
        && report.conflicts.allSatisfy { conflict in
            (conflictResolutions[conflict.id] ?? .keepSTAT) == .keepSTAT
        }
        && acceptedCompoundIDs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x5) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: StudioSpace.x5) {
                    summarySection
                    if reviewExpanded || !hasDecisionSections {
                        if let sparsity = report.namingSparsity, !sparsity.isEmpty {
                            sparsitySection(sparsity)
                        }
                        if !report.conflicts.isEmpty {
                            conflictsSection
                        }
                        if !report.heldStopCandidates.isEmpty {
                            stopsSection
                        }
                        if !report.compoundSuggestions.isEmpty {
                            compoundsSection
                        }
                    }
                }
                // Keep cards clear of the overlay scrollbar (sheet padding alone is not enough).
                .padding(.trailing, StudioSpacing.contentInset)
            }
            .frame(maxHeight: 520)
            actionBar
        }
        .padding(StudioSpace.x5)
        .frame(minWidth: 540, idealWidth: 580)
        .onAppear { seedDefaults() }
    }

    private var hasDecisionSections: Bool {
        !report.heldStopCandidates.isEmpty
            || !report.compoundSuggestions.isEmpty
            || !report.conflicts.isEmpty
            || !(report.namingSparsity?.isEmpty ?? true)
    }

    private func seedDefaults() {
        for candidate in report.heldStopCandidates {
            stopDecisions[candidate.id] = candidate.recommendedDecision
            promotedStopNames[candidate.id] = candidate.proposedName
        }
        for conflict in report.conflicts {
            conflictResolutions[conflict.id] = .keepSTAT
        }
        acceptedCompoundIDs = []
        dismissedCompoundIDs = []
        // Start on the summary path when there are real decisions; expand sparsity-only.
        reviewExpanded = report.heldStopCandidates.isEmpty
            && report.compoundSuggestions.isEmpty
            && report.conflicts.isEmpty
    }

    // MARK: - Header / summary

    private var header: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            Text("Import Review")
                .font(StudioTypography.projectTitle)
            Text(headerSubtitle)
                .font(StudioTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerSubtitle: String {
        if report.heldStopCandidates.isEmpty,
           report.compoundSuggestions.isEmpty,
           report.conflicts.isEmpty {
            return "Named styles look thin or shared. Stops still seed — polish names later in the Axis Tree."
        }
        return "Seeding every fvar coordinate as a global stop would densify styles beyond what’s in the font. Accept the recommendations, or walk through each choice."
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            if let metrics = report.orthogonality {
                HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x4) {
                    metricBlock(value: "\(metrics.originalInstanceCount)", label: "in the font")
                    Image(systemName: "arrow.right")
                        .font(StudioTypography.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, StudioSpace.x1)
                    metricBlock(
                        value: "\(metrics.projectedAnalyticCount)",
                        label: "with recommendations"
                    )
                    if metrics.projectedIfAllPromoted > metrics.projectedAnalyticCount {
                        metricBlock(
                            value: "\(metrics.projectedIfAllPromoted)",
                            label: "if everything promotes"
                        )
                        .opacity(0.72)
                    }
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                ForEach(summaryBullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                        Circle()
                            .fill(StudioColors.surfaceStrokeStrong)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(bullet)
                            .font(StudioTypography.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if report.seededStopCount > 0 {
                Text("Already seeded \(report.seededStopCount) safe stop\(report.seededStopCount == 1 ? "" : "s").")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }

            if hasDecisionSections {
                HStack(spacing: StudioSpacing.controlGap) {
                    StudioFlatButton(title: "Accept recommendations", role: .primary, size: .compact) {
                        acceptRecommendationsAndApply()
                    }
                    StudioFlatButton(
                        title: reviewExpanded ? "Hide details" : "Review choices",
                        size: .compact
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            reviewExpanded.toggle()
                        }
                    }
                }
                .padding(.top, StudioSpacing.tightGap)
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.surface))
    }

    private func metricBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text(value)
                .font(StudioTypography.statValue)
                .foregroundStyle(.primary)
            Text(label)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryBullets: [String] {
        var items: [String] = []
        let comboOnlyCount = report.heldStopCandidates.filter { $0.classification == .comboOnly }.count
        if comboOnlyCount > 0 {
            items.append(
                comboOnlyCount == 1
                    ? "One value only shows up inside multi-axis styles — keep it for named combinations."
                    : "\(comboOnlyCount) values only show up inside multi-axis styles — keep them for named combinations."
            )
        }
        if let expansion = report.expansionCallouts.first, expansion.inventedCombinationCount > 0 {
            items.append(
                "Even with recommendations, \(expansion.inventedCombinationCount) style combination\(expansion.inventedCombinationCount == 1 ? "" : "s") aren’t in the original font (from stops already seeded)."
            )
        }
        if !report.compoundSuggestions.isEmpty {
            let n = report.compoundSuggestions.count
            items.append(
                n == 1
                    ? "One named combination can be added as a Format 4 style, or left for the Combinations drawer."
                    : "\(n) named combinations can be added as Format 4 styles, or left for the Combinations drawer."
            )
        }
        if !report.conflicts.isEmpty {
            let n = report.conflicts.count
            items.append(
                n == 1
                    ? "One stop name disagrees between STAT and the font."
                    : "\(n) stop names disagree between STAT and the font."
            )
        }
        if let sparsity = report.namingSparsity, !sparsity.isEmpty {
            if sparsity.missingSubfamilyCount > 0 {
                items.append("Some instances are missing subfamily names — stops may use values as labels.")
            } else if sparsity.sharedNameCollapseSize >= 2 {
                items.append("Several locations share one instance name — rename later in the Axis Tree.")
            }
        }
        if items.isEmpty, !report.reviewReason.isEmpty {
            items.append(report.reviewReason)
        }
        return items
    }

    // MARK: - Sections

    private func sparsitySection(_ sparsity: FvarStopSeeder.NamingSparsityCallout) -> some View {
        reviewSection(
            title: "Instance names",
            caption: "Stops still seed. Treat this as a polish reminder, not a blocker."
        ) {
            Text(sparsity.message)
                .font(StudioTypography.body)
                .fixedSize(horizontal: false, vertical: true)
            if sparsity.missingSubfamilyCount > 0 {
                Text("\(sparsity.missingSubfamilyCount) instance\(sparsity.missingSubfamilyCount == 1 ? "" : "s") missing a subfamily name.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
            if sparsity.sharedNameCollapseSize >= 2 {
                Text("Up to \(sparsity.sharedNameCollapseSize) distinct locations share one name.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(sparsity.sharedNameSamples, id: \.self) { sample in
                Text(sample)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var conflictsSection: some View {
        reviewSection(
            title: "Name conflicts",
            caption: "Pick which label to keep for each stop."
        ) {
            ForEach(report.conflicts) { conflict in
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    Text("\(conflict.axisLabel) at \(AxisCoordinateFormat.format(conflict.value))")
                        .font(StudioTypography.bodyMedium)
                    Text("STAT “\(conflict.existingName)” vs font “\(conflict.fvarName)”")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: StudioSpacing.controlGap) {
                        conflictChoice(conflict, title: "Keep STAT", resolution: .keepSTAT)
                        conflictChoice(conflict, title: "Use font name", resolution: .takeFvar)
                    }
                }
                .padding(StudioSpacing.contentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.control))
            }
        }
    }

    private func conflictChoice(
        _ conflict: FvarStopSeeder.NameConflict,
        title: String,
        resolution: FvarStopSeeder.Resolution
    ) -> some View {
        let selected = conflictResolutions[conflict.id] == resolution
        return choiceChip(title: title, selected: selected) {
            conflictResolutions[conflict.id] = resolution
        }
    }

    private var stopsSection: some View {
        reviewSection(
            title: "Stops to decide",
            caption: "Choose how each held value should live in STAT. The consequence below updates as you choose."
        ) {
            ForEach(report.heldStopCandidates) { candidate in
                let decision = stopDecisions[candidate.id] ?? candidate.recommendedDecision
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(candidate.axisLabel)
                            .font(StudioTypography.bodyMedium)
                        Text(AxisCoordinateFormat.format(candidate.value))
                            .font(StudioTypography.monoValue)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: StudioSpacing.controlGap)
                    }
                    Text(classificationLabel(candidate.classification))
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: StudioSpacing.controlGap) {
                        stopChoice(candidate, title: "Promote", decision: .promote)
                        stopChoice(candidate, title: "Combo only", decision: .comboOnly)
                        stopChoice(candidate, title: "Ignore", decision: .ignore)
                    }
                    Text(decisionOutcome(decision))
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if decision == .promote {
                        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                            Text("Stop name (optional)")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.tertiary)
                            TextField(
                                "Name",
                                text: promotedNameBinding(for: candidate)
                            )
                            .textFieldStyle(.roundedBorder)
                            .font(StudioTypography.body)
                        }
                    }
                }
                .padding(StudioSpacing.contentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.control))
            }

            if let expansion = liveExpansion {
                expansionConsequence(expansion)
            } else if report.expansionPreview != nil {
                expansionClearCallout
            }
        }
    }

    private func classificationLabel(_ classification: FvarStopSeeder.StopClassification) -> String {
        switch classification {
        case .safeUnivariate:
            return "Safe to promote as a global stop."
        case .comboOnly:
            return "Recommended: keep for named combinations only — don’t multiply the style grid."
        case .ambiguous:
            return "Unclear attribution — review before promoting."
        }
    }

    private func decisionOutcome(_ decision: FvarStopSeeder.StopDecision) -> String {
        switch decision {
        case .promote:
            return "Adds a global Format 1 stop on this axis (multiplies the style grid)."
        case .comboOnly:
            return "No Format 1 stop — value stays available for Format 4 / named combinations only."
        case .ignore:
            return "Skip entirely — neither a Format 1 stop nor reserved for Format 4."
        }
    }

    private func promotedNameBinding(for candidate: FvarStopSeeder.StopCandidate) -> Binding<String> {
        Binding(
            get: { promotedStopNames[candidate.id] ?? candidate.proposedName },
            set: { promotedStopNames[candidate.id] = $0 }
        )
    }

    private func stopChoice(
        _ candidate: FvarStopSeeder.StopCandidate,
        title: String,
        decision: FvarStopSeeder.StopDecision
    ) -> some View {
        let selected = (stopDecisions[candidate.id] ?? candidate.recommendedDecision) == decision
        return choiceChip(title: title, selected: selected) {
            stopDecisions[candidate.id] = decision
        }
    }

    private func expansionConsequence(_ callout: FvarStopSeeder.ExpansionCallout) -> some View {
        let promotingHeld = report.heldStopCandidates.contains {
            (stopDecisions[$0.id] ?? $0.recommendedDecision) == .promote
        }
        return VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            Text("Consequence of current choices")
                .font(StudioTypography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(consequenceHeadline(callout, promotingHeld: promotingHeld))
                .font(StudioTypography.bodyMedium)
                .fixedSize(horizontal: false, vertical: true)
            Text("Orthogonal STAT naming would compose these style names. They are not in the original font.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                ForEach(Array(callout.samples.enumerated()), id: \.offset) { _, sample in
                    VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                        Text(sample.composedName.isEmpty ? sample.coordLabel : sample.composedName)
                            .font(StudioTypography.bodyMedium)
                        if !sample.composedName.isEmpty {
                            Text(sample.coordLabel)
                                .font(StudioTypography.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            if promotingHeld {
                Text("Demote or ignore promoted stops above to shrink this list.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.surface))
        .overlay(alignment: .leading) {
            RoundedRectangle.studio(StudioRadius.chip)
                .fill(StudioColors.surfaceStrokeStrong)
                .frame(width: 3)
                .padding(.vertical, StudioSpacing.controlGap)
                .padding(.leading, StudioSpace.x0_5)
        }
    }

    private var expansionClearCallout: some View {
        Text("With these choices, the custom-axis product stays within the styles present in the font.")
            .font(StudioTypography.caption)
            .foregroundStyle(.secondary)
            .padding(StudioSpacing.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.surface))
    }

    private func consequenceHeadline(
        _ callout: FvarStopSeeder.ExpansionCallout,
        promotingHeld: Bool
    ) -> String {
        let n = callout.inventedCombinationCount
        if promotingHeld {
            return "\(n) style combination\(n == 1 ? "" : "s") would be invented that aren’t in the original font."
        }
        return "\(n) style combination\(n == 1 ? "" : "s") still aren’t in the original font — from stops already seeded."
    }

    private var compoundsSection: some View {
        reviewSection(
            title: "Named combinations",
            caption: "Optional Format 4 styles. Add now, or leave them for the Combinations drawer after Apply."
        ) {
            ForEach(report.compoundSuggestions) { suggestion in
                let accepted = acceptedCompoundIDs.contains(suggestion.id)
                let dismissed = dismissedCompoundIDs.contains(suggestion.id)
                VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(suggestion.name)
                            .font(StudioTypography.bodyMedium)
                        Spacer(minLength: StudioSpacing.controlGap)
                        Text("covers \(suggestion.coveredInstanceCount) style\(suggestion.coveredInstanceCount == 1 ? "" : "s")")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(compoundLegSummary(suggestion))
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                    HStack(spacing: StudioSpacing.controlGap) {
                        StudioFlatButton(
                            title: dismissed ? "Dismissed" : "Dismiss",
                            size: .compact,
                            isEnabled: !accepted
                        ) {
                            acceptedCompoundIDs.remove(suggestion.id)
                            dismissedCompoundIDs.insert(suggestion.id)
                        }
                        StudioFlatButton(
                            title: accepted ? "Added" : "Add",
                            role: .primary,
                            size: .compact,
                            isEnabled: !dismissed
                        ) {
                            dismissedCompoundIDs.remove(suggestion.id)
                            acceptedCompoundIDs.insert(suggestion.id)
                        }
                    }
                }
                .padding(StudioSpacing.contentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.control))
                .opacity(dismissed ? 0.55 : 1)
            }
        }
    }

    private func compoundLegSummary(_ suggestion: FvarStopSeeder.CompoundSuggestion) -> String {
        suggestion.coords.keys.sorted().map { tag in
            let value = AxisCoordinateFormat.format(suggestion.coords[tag] ?? 0)
            if let label = suggestion.legLabels[tag], !label.isEmpty {
                return "\(label)"
            }
            return "\(value) \(tag)"
        }.joined(separator: " × ")
    }

    // MARK: - Shared chrome

    private func reviewSection<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
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

    private func choiceChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(StudioTypography.caption.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
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
    }

    private var actionBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            Spacer()
            StudioFlatButton(title: "Decide later", size: .compact) {
                editor.deferFvarImportReview()
                dismiss()
            }
            StudioFlatButton(
                title: decisionsMatchRecommendations && !reviewExpanded
                    ? "Apply recommendations"
                    : "Apply",
                role: .primary,
                size: .compact
            ) {
                applyCurrentDecisions()
            }
        }
    }

    private func acceptRecommendationsAndApply() {
        for candidate in report.heldStopCandidates {
            stopDecisions[candidate.id] = candidate.recommendedDecision
        }
        for conflict in report.conflicts {
            conflictResolutions[conflict.id] = .keepSTAT
        }
        // Leave Format 4 for the Combinations drawer — recommendations don’t auto-add.
        acceptedCompoundIDs = []
        dismissedCompoundIDs = []
        applyCurrentDecisions()
    }

    private func applyCurrentDecisions() {
        editor.applyFvarImportReview(
            FvarStopSeeder.ReviewDecisions(
                stopDecisions: stopDecisions,
                conflictResolutions: conflictResolutions,
                acceptedCompoundIDs: acceptedCompoundIDs,
                dismissedCompoundIDs: dismissedCompoundIDs,
                promotedStopNames: promotedStopNames
            )
        )
        dismiss()
    }
}
