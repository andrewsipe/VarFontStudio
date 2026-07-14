import AppKit
import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Conflict / plan-issue orchestration

    func instanceAffectedByUnresolvedConflict(_ instance: PlannedInstance) -> Bool {
        primaryConflictAxis(for: instance) != nil
    }

    private func instanceParticipates(inStopID stopID: String, instance: PlannedInstance) -> Bool {
        guard let font = selectedFont else { return false }
        for axis in font.axes {
            guard let stop = axis.values.first(where: { $0.id == stopID }) else { continue }
            guard let coord = instance.coords[axis.tag] else { return false }
            return AxisCoordinate.valuesEqual(coord, stop.value)
        }
        return false
    }

    func primaryConflictAxis(for instance: PlannedInstance) -> AxisConflictBundle? {
        axisConflictBundles.first { bundle in
            bundle.involvedStopIDs.contains { instanceParticipates(inStopID: $0, instance: instance) }
        }
    }

    var axisConflictBundles: [AxisConflictBundle] {
        guard let instancePlan, let font = selectedFont, let project else { return [] }
        return AxisConflictBundler.bundles(
            warnings: instancePlan.warnings,
            axes: font.axes,
            namingOrder: project.naming.order
        ).map { bundle in
            var updated = bundle
            updated.symptomSummary = ConflictResolver.symptomSummary(
                for: bundle,
                font: font,
                naming: project.naming
            )
            return updated
        }
    }

    var unresolvedAxisConflictCount: Int { axisConflictBundles.count }

    func bundle(for axisTag: String) -> AxisConflictBundle? {
        axisConflictBundles.first { $0.axisTag == axisTag }
    }

    func presentConflictResolver(for axisTag: String) {
        guard let bundle = bundle(for: axisTag) else { return }
        presentConflictResolver(bundle: bundle)
    }

    func presentConflictResolver(bundle: AxisConflictBundle) {
        let position = reviewSessionPosition(for: .axisConflict(bundle))
        issueResolvers.presentConflict(
            bundle: bundle,
            reviewPosition: position?.current,
            reviewTotal: position?.total
        )
        focusConflictAxis(bundle)
    }

    func presentFirstConflictResolver() {
        guard let first = axisConflictBundles.first else { return }
        presentConflictResolver(bundle: first)
    }

    func dismissConflictResolver() {
        issueResolvers.dismissConflictResolver(clearReviewSession: true)
    }

    func reviewQueue() -> [AxisTreeReviewItem] {
        guard let instancePlan, selectedFont != nil, let project else { return [] }
        return AxisTreeReviewQueue.build(
            warnings: instancePlan.warnings,
            conflictBundles: axisConflictBundles,
            namingOrder: project.naming.order
        )
    }

    var reviewIssueCount: Int { reviewQueue().count }

    func informationalPlanWarnings() -> [PlanWarning] {
        guard let instancePlan, let project else { return [] }
        return AxisTreeReviewQueue.informationalWarnings(
            warnings: instancePlan.warnings,
            namingOrder: project.naming.order
        )
    }

    func startReviewSession(jumpingTo warning: PlanWarning? = nil) {
        let queue = reviewQueue()
        guard !queue.isEmpty else { return }
        let index: Int
        if let warning {
            let key = PlanIssueCodes.issueKey(for: warning)
            index = queue.firstIndex { item in
                guard case let .planIssue(w) = item else { return false }
                return PlanIssueCodes.issueKey(for: w) == key
            } ?? 0
        } else {
            index = 0
        }
        issueResolvers.startReviewSession(
            state: AxisTreeReviewSessionState(scope: .full, initialTotal: queue.count)
        )
        presentReviewItem(at: index, in: queue)
    }

    func startAxisReviewSession(on axisTag: String) {
        let queue = AxisTreeReviewQueue.filter(reviewQueue(), axisTag: axisTag)
        guard !queue.isEmpty else { return }
        issueResolvers.startReviewSession(
            state: AxisTreeReviewSessionState(scope: .axis(axisTag), initialTotal: queue.count)
        )
        presentReviewItem(at: 0, in: queue)
    }

    func continueReviewSession() {
        advanceReviewSession()
    }

    func advanceReviewSession() {
        guard issueResolvers.hasActiveReviewSession else { return }
        issueResolvers.updateReviewSession { session in
            session.state.completedCount += 1
        }
        let queue = scopedReviewQueue()
        guard !queue.isEmpty else {
            issueResolvers.clearBothResolversAndReviewSession()
            return
        }
        presentReviewItem(at: 0, in: queue)
    }

    private func scopedReviewQueue() -> [AxisTreeReviewItem] {
        let full = reviewQueue()
        guard let session = issueResolvers.reviewSession else { return full }
        return session.state.scopedQueue(from: full)
    }

    func endReviewSession() {
        issueResolvers.endReviewSession()
    }

    private func presentReviewItem(at index: Int, in queue: [AxisTreeReviewItem]) {
        guard index < queue.count else {
            issueResolvers.clearBothResolvers()
            return
        }
        switch queue[index] {
        case let .planIssue(warning):
            issueResolvers.conflictResolverRequest = nil
            presentPlanIssueResolver(for: warning)
        case let .axisConflict(bundle):
            issueResolvers.planIssueResolverRequest = nil
            presentConflictResolver(bundle: bundle)
        }
    }

    private func reviewSessionPosition(for item: AxisTreeReviewItem) -> (current: Int, total: Int)? {
        _ = item
        return issueResolvers.reviewSessionPosition()
    }

    func resolvablePlanWarnings(for axisTag: String) -> [PlanWarning] {
        guard selectedFont != nil else { return [] }
        return (instancePlan?.warnings ?? []).filter { warning in
            guard warning.axis == axisTag else { return false }
            return PlanIssueCodes.resolvable.contains(warning.code)
        }
    }

    func planIssueProposals(for warning: PlanWarning) -> [PlanIssueProposal] {
        guard let font = selectedFont else { return [] }
        return PlanIssueResolver.proposals(for: warning, font: font)
    }

    func applyPlanIssueFix(_ action: PlanIssueAction, andContinue: Bool = false) {
        if case .openAxisConflicts(let axisTag) = action {
            issueResolvers.planIssueResolverRequest = nil
            if let tag = axisTag, let bundle = bundle(for: tag) {
                presentConflictResolver(bundle: bundle)
            } else if let first = axisConflictBundles.first {
                presentConflictResolver(bundle: first)
            }
            return
        }

        guard var project, let fontIndex = project.fonts.firstIndex(where: { $0.id == selectedFontID }) else {
            return
        }
        pushUndoSnapshot()
        PlanIssueResolver.apply(action, to: &project.fonts[fontIndex])
        project.fonts[fontIndex].dirty = true
        project.modified = Date()
        self.project = project
        canSave = true
        regeneratePlan()
        if andContinue {
            advanceReviewSession()
        } else {
            issueResolvers.dismissPlanIssueResolver(clearReviewSession: true)
        }
    }

    func presentPlanIssueResolver(for warning: PlanWarning) {
        let item = AxisTreeReviewItem.planIssue(warning)
        let position = reviewSessionPosition(for: item)
        issueResolvers.presentPlanIssue(
            warning: warning,
            reviewPosition: position?.current,
            reviewTotal: position?.total
        )
        if let axis = warning.axis {
            inspectorFocus.focusedAxisTag = axis
            if let stopID = warning.stopIDs?.first {
                selectedAxisStopID = stopID
                inspectorFocus.requestAxisTreeFocus(axisTag: axis, stopID: stopID)
            }
        }
    }

    func presentFirstResolvablePlanIssue(on axisTag: String) {
        startAxisReviewSession(on: axisTag)
    }

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

    func dismissPlanIssueResolver() {
        issueResolvers.dismissPlanIssueResolver(clearReviewSession: true)
    }

    func applyConflictFix(_ action: ConflictFixAction, axisTag: String, andContinue: Bool = false) {
        guard var project, let fontIndex = project.fonts.firstIndex(where: { $0.id == selectedFontID }) else {
            return
        }
        pushUndoSnapshot()
        ConflictResolver.apply(action, axisTag: axisTag, to: &project.fonts[fontIndex])
        project.fonts[fontIndex].dirty = true
        project.modified = Date()
        self.project = project
        canSave = true
        regeneratePlan()
        if andContinue {
            advanceReviewSession()
        } else {
            issueResolvers.conflictResolverRequest = nil
            if issueResolvers.hasActiveReviewSession {
                issueResolvers.endReviewSession()
            } else if let sameAxis = axisConflictBundles.first(where: { $0.axisTag == axisTag }) {
                presentConflictResolver(bundle: sameAxis)
            } else if let next = axisConflictBundles.first {
                presentConflictResolver(bundle: next)
            }
        }
    }

    private func focusConflictAxis(_ bundle: AxisConflictBundle) {
        inspectorFocus.focusedAxisTag = bundle.axisTag
        guard let stopID = bundle.involvedStopIDs.first else { return }
        selectedAxisStopID = stopID
        inspectorFocus.requestAxisTreeFocus(axisTag: bundle.axisTag, stopID: stopID)
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
