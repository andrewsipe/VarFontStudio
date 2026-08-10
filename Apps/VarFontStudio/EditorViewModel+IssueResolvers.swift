import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Conflict / plan-issue (facades → IssueResolverStore)

    func instanceAffectedByUnresolvedConflict(_ instance: PlannedInstance) -> Bool {
        issueResolvers.instanceAffectedByUnresolvedConflict(instance)
    }

    func primaryConflictAxis(for instance: PlannedInstance) -> AxisConflictBundle? {
        issueResolvers.primaryConflictAxis(for: instance)
    }

    var axisConflictBundles: [AxisConflictBundle] { issueResolvers.axisConflictBundles }

    var unresolvedAxisConflictCount: Int { issueResolvers.unresolvedAxisConflictCount }

    func bundle(for axisTag: String) -> AxisConflictBundle? {
        issueResolvers.bundle(for: axisTag)
    }

    func presentConflictResolver(for axisTag: String) {
        issueResolvers.presentConflictResolver(for: axisTag)
    }

    func presentConflictResolver(bundle: AxisConflictBundle) {
        issueResolvers.presentConflictResolver(bundle: bundle)
    }

    func presentFirstConflictResolver() {
        issueResolvers.presentFirstConflictResolver()
    }

    func dismissConflictResolver() {
        issueResolvers.dismissConflictResolver()
    }

    func reviewQueue() -> [AxisTreeReviewItem] {
        issueResolvers.reviewQueue()
    }

    var reviewIssueCount: Int { issueResolvers.reviewIssueCount }

    func informationalPlanWarnings() -> [PlanWarning] {
        issueResolvers.informationalPlanWarnings()
    }

    func startReviewSession(jumpingTo warning: PlanWarning? = nil) {
        issueResolvers.startReviewSession(jumpingTo: warning)
    }

    func startAxisReviewSession(on axisTag: String) {
        issueResolvers.startAxisReviewSession(on: axisTag)
    }

    func continueReviewSession() {
        issueResolvers.continueReviewSession()
    }

    func advanceReviewSession() {
        issueResolvers.advanceReviewSession()
    }

    func endReviewSession() {
        issueResolvers.endReviewSession()
    }

    func resolvablePlanWarnings(for axisTag: String) -> [PlanWarning] {
        issueResolvers.resolvablePlanWarnings(for: axisTag)
    }

    func planIssueProposals(for warning: PlanWarning) -> [PlanIssueProposal] {
        issueResolvers.planIssueProposals(for: warning)
    }

    func applyPlanIssueFix(_ action: PlanIssueAction, andContinue: Bool = false) {
        issueResolvers.applyPlanIssueFix(action, andContinue: andContinue)
    }

    func presentPlanIssueResolver(for warning: PlanWarning) {
        issueResolvers.presentPlanIssueResolver(for: warning)
    }

    func presentFirstResolvablePlanIssue(on axisTag: String) {
        issueResolvers.presentFirstResolvablePlanIssue(on: axisTag)
    }

    func dismissPlanIssueResolver() {
        issueResolvers.dismissPlanIssueResolver()
    }

    func applyConflictFix(_ action: ConflictFixAction, axisTag: String, andContinue: Bool = false) {
        issueResolvers.applyConflictFix(action, axisTag: axisTag, andContinue: andContinue)
    }

    func presentFvarStatConflicts(_ conflicts: [FvarStopSeeder.NameConflict]) {
        issueResolvers.presentFvarStatConflicts(conflicts)
    }

    func presentFvarImportReview(report: FvarStopSeeder.Report, fontID: String) {
        issueResolvers.presentFvarImportReview(report: report, fontID: fontID)
    }

    func dismissFvarStatConflictResolver() {
        issueResolvers.dismissFvarStatConflictResolver()
    }

    func applyFvarStatConflictResolution(
        _ resolution: FvarStopSeeder.Resolution,
        andContinue: Bool = false
    ) {
        issueResolvers.applyFvarStatConflictResolution(resolution, andContinue: andContinue)
    }

    func applyFvarImportReview(_ decisions: FvarStopSeeder.ReviewDecisions) {
        guard let session = issueResolvers.fvarImportReviewRequest,
              var project,
              let fontIndex = project.fonts.firstIndex(where: { $0.id == session.fontID })
        else {
            issueResolvers.dismissFvarImportReview()
            return
        }

        pushUndoSnapshot()
        let remaining = FvarStopSeeder.apply(
            reviewDecisions: decisions,
            report: session.report,
            to: &project.fonts[fontIndex]
        )
        project.fonts[fontIndex].dirty = true
        project.modified = Date()
        self.project = project
        canSave = true

        // Replace this font's compound suggestions with unresolved leftovers.
        compoundSuggestions.removeAll { $0.fontID == session.fontID }
        compoundSuggestions.append(contentsOf: remaining)

        regeneratePlan()
        issueResolvers.dismissFvarImportReview()
    }

    func deferFvarImportReview() {
        guard let session = issueResolvers.fvarImportReviewRequest else {
            issueResolvers.dismissFvarImportReview()
            return
        }
        // Park Format 4 suggestions; leave held stops unapplied for later Axis Tree / Combinations work.
        compoundSuggestions.removeAll { $0.fontID == session.fontID }
        compoundSuggestions.append(contentsOf: session.report.compoundSuggestions)
        issueResolvers.dismissFvarImportReview()
    }

    // MARK: - Naming / compound helpers (remain on editor)

    func setElidedFallback(_ value: String) {
        guard var project else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "Regular" : trimmed
        guard resolved != project.naming.elidedFallback else { return }
        pushUndoSnapshot()
        project.naming.elidedFallback = resolved
        project.modified = Date()
        self.project = project
        regeneratePlan()
    }
    func updateCompoundStatName(id: String, name: String) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }) else { return }
            font.compoundStatValues[index].name = name
        }
    }
    func updateCompoundStatElidable(id: String, elidable: Bool) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }) else { return }
            font.compoundStatValues[index].elidable = elidable
        }
    }
    func updateCompoundStatCoordinate(id: String, tag: String, value: Double) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }) else { return }
            font.compoundStatValues[index].coords[tag] = value
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &font.compoundStatValues[index],
                designAxisOrder: font.axes
            )
        }
    }

    func addCompoundStatValue(name: String, coords: [String: Double]) {
        guard coords.count >= 2 else { return }
        mutateSelectedFont { font in
            var compound = CompoundStatValue(
                id: "compound-\(UUID().uuidString.prefix(8))",
                coords: coords.mapValues(AxisCoordinateFormat.canonical),
                axisIndices: [],
                axisValues: [],
                name: name,
                elidable: false
            )
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &compound,
                designAxisOrder: font.axes
            )
            font.compoundStatValues.append(compound)
        }
        let canonical = coords.mapValues(AxisCoordinateFormat.canonical)
        compoundSuggestions.removeAll { suggestion in
            suggestion.fontID == selectedFontID
                && suggestion.coords.count == canonical.count
                && suggestion.coords.allSatisfy { tag, value in
                    guard let other = canonical[tag] else { return false }
                    return AxisCoordinate.valuesEqual(value, other)
                }
        }
    }

    func removeCompoundStatValue(id: String) {
        mutateSelectedFont { font in
            font.compoundStatValues.removeAll { $0.id == id }
        }
    }

    func acceptCompoundSuggestion(_ suggestion: FvarStopSeeder.CompoundSuggestion) {
        addCompoundStatValue(name: suggestion.name, coords: suggestion.coords)
        compoundSuggestions.removeAll { $0.id == suggestion.id }
    }

    func dismissCompoundSuggestion(id: String) {
        compoundSuggestions.removeAll { $0.id == id }
    }

    var compoundSuggestionsForSelectedFont: [FvarStopSeeder.CompoundSuggestion] {
        guard let fontID = selectedFontID else { return [] }
        return compoundSuggestions.filter { $0.fontID == fontID }
    }

    func addCompoundStatLeg(id: String, tag: String) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }),
                  let axis = font.axes.first(where: { $0.tag == tag }),
                  font.compoundStatValues[index].coords[tag] == nil else { return }
            let value: Double
            if let max = axis.max, let def = axis.default, !AxisCoordinate.valuesEqual(max, def) {
                value = max
            } else {
                value = axis.default ?? axis.min ?? 0
            }
            font.compoundStatValues[index].coords[tag] = value
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &font.compoundStatValues[index],
                designAxisOrder: font.axes
            )
        }
    }

    func replaceCompoundStatLeg(id: String, oldTag: String, newTag: String, value: Double) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }),
                  font.compoundStatValues[index].coords[oldTag] != nil,
                  font.compoundStatValues[index].coords[newTag] == nil,
                  font.axes.contains(where: { $0.tag == newTag }) else { return }
            font.compoundStatValues[index].coords.removeValue(forKey: oldTag)
            font.compoundStatValues[index].coords[newTag] = AxisCoordinateFormat.canonical(value)
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &font.compoundStatValues[index],
                designAxisOrder: font.axes
            )
        }
    }

    func removeCompoundStatLeg(id: String, tag: String) {
        mutateSelectedFont { font in
            guard let index = font.compoundStatValues.firstIndex(where: { $0.id == id }) else { return }
            guard font.compoundStatValues[index].coords.count > 2 else { return }
            font.compoundStatValues[index].coords.removeValue(forKey: tag)
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &font.compoundStatValues[index],
                designAxisOrder: font.axes
            )
        }
    }

    func axisStop(for instance: PlannedInstance, tag: String) -> (axisTag: String, stopID: String)? {
        guard let font = selectedFont,
              let coord = instance.coords[tag],
              let axis = font.axes.first(where: { $0.tag == tag }),
              let stop = axis.values.first(where: { AxisCoordinate.valuesEqual($0.value, coord) }) else {
            return nil
        }
        return (tag, stop.id)
    }
}
