import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Import helpers

    enum FontImportError: LocalizedError {
        case notVariableFont

        var errorDescription: String? {
            switch self {
            case .notVariableFont:
                "Not a variable font — no variation axes found."
            }
        }
    }

    func validateVariableFont(_ analysis: FontAnalysis) throws {
        if analysis.axes.isEmpty {
            throw FontImportError.notVariableFont
        }
    }

    func findFont(normalizedPath: String) -> (projectID: String, fontID: String)? {
        for op in openProjects {
            for font in op.document.fonts {
                if Self.normalizedPath(font.sourcePath) == normalizedPath {
                    return (op.id, font.id)
                }
            }
        }
        return nil
    }

    static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    func refreshCanSave() {
        canSave = project?.fonts.contains(where: \.dirty) ?? false
    }

    /// Rebuilds the instance plan for the selected font.
    /// - Parameter refreshPendingExport: When false, skips source-font re-analysis (cosmetic renames).
    func regeneratePlan(refreshPendingExport: Bool = true) {
        guard project != nil, selectedFontID != nil else {
            planRegenTask?.cancel()
            planGenerationToken += 1
            instancePlan = nil
            pendingExportInstanceKeys = []
            instanceListDisplay = .empty
            return
        }
        backfillMissingInferredAxisRoles()
        syncSlopeOwnedNamingOrderIfNeeded()
        guard let project, let fontID = selectedFontID else {
            instancePlan = nil
            pendingExportInstanceKeys = []
            return
        }

        let estimatedProduct = Self.estimatedInstanceProduct(project: project, fontID: fontID)
        // Small grids stay synchronous to avoid stale-plan races in follow-up work.
        // Larger products move off the main actor so axis-tree commits stay responsive.
        if estimatedProduct <= Self.syncPlanProductThreshold {
            applyInstancePlan(
                InstancePlanner.plan(project: project, fontID: fontID),
                refreshPendingExport: refreshPendingExport
            )
            return
        }

        planGenerationToken += 1
        let token = planGenerationToken
        let projectSnapshot = project
        let shouldRefreshPendingExport = refreshPendingExport
        planRegenTask?.cancel()
        planRegenTask = Task { @MainActor in
            let planned = await Task.detached(priority: .userInitiated) {
                InstancePlanner.plan(project: projectSnapshot, fontID: fontID)
            }.value
            guard !Task.isCancelled,
                  token == self.planGenerationToken,
                  self.selectedFontID == fontID else { return }
            self.applyInstancePlan(planned, refreshPendingExport: shouldRefreshPendingExport)
        }
    }

    /// Drops passive slope siblings (`ital` when `slnt` owns) from the stored naming chain
    /// and elides registration ital stops so Axis Tree matches composed names.
    ///
    /// Must not re-merge against the selected font's axes: that would rewrite the shared
    /// project order on every font switch and discard sibling-only tags (and the user's
    /// relative order for axes that come back when switching back).
    private func syncSlopeOwnedNamingOrderIfNeeded() {
        guard var project, let fontID = selectedFontID,
              let fontIndex = project.fonts.firstIndex(where: { $0.id == fontID }) else { return }
        var font = project.fonts[fontIndex]
        let cleaned = SlopeAxisPolicy.effectiveNamingOrder(
            project.naming.order,
            axes: font.axes,
            forceInclude: Set(project.naming.slopeNamingIncludeTags)
        )
        let elidedItal = SlopeAxisPolicy.applyPassiveItalElision(to: &font)
        guard cleaned != project.naming.order || elidedItal else { return }
        project.naming.order = cleaned
        if elidedItal {
            project.fonts[fontIndex] = font
        }
        self.project = project
    }

    private func applyInstancePlan(_ plan: InstancePlan?, refreshPendingExport: Bool) {
        instancePlan = plan
        planRevision += 1
        if let key = selectedInstanceKey,
           instancePlan?.instances.contains(where: { $0.key == key }) != true {
            selectedInstanceKey = instancePlan?.instances.first?.key
        }
        // Instance list rebuilds via `$instancePlan` CombineLatest (and again after pending-export).
        if refreshPendingExport {
            refreshPendingExportKeys()
        }
        scheduleSaveReviewPrefetchIfNeeded()
    }

    private static let syncPlanProductThreshold = 48

    private static func estimatedInstanceProduct(project: ProjectDocument, fontID: String) -> Int {
        guard let font = project.fonts.first(where: { $0.id == fontID }) else { return 0 }
        let counts = font.axes.filter { $0.role == .instance }.map(\.values.count)
        guard !counts.isEmpty else { return 0 }
        return counts.reduce(1) { partial, count in
            let n = max(count, 1)
            let next = partial.multipliedReportingOverflow(by: n)
            return next.overflow ? Int.max : next.partialValue
        }
    }

    /// Warm Review dry-run in the background while the font is dirty so open is often a cache hit.
    func scheduleSaveReviewPrefetchIfNeeded() {
        guard let projectID = activeProjectID,
              let fontID = selectedFontID,
              let font = selectedFont,
              font.dirty else { return }
        saveReview.scheduleCommitDiffPrefetch(forProjectID: projectID, fontID: fontID)
    }

    func setInstanceIncluded(_ key: String, included: Bool) {
        guard var project, let fontIndex = project.fonts.firstIndex(where: { $0.id == selectedFontID }) else {
            return
        }
        pushUndoSnapshot()
        var font = project.fonts[fontIndex]
        Self.applyInclusion(keys: [key], included: included, to: &font, allInstanceKeys: plannedInstanceKeys)
        font.dirty = true
        project.fonts[fontIndex] = font
        project.modified = Date()
        self.project = project
        canSave = true
        regeneratePlan()
    }

    /// All planned instance keys for the selected font (whitelist→exclude conversion).
    var plannedInstanceKeys: Set<String> {
        Set(instancePlan?.instances.map(\.key) ?? [])
    }

    /// Include/exclude helpers that respect whitelist vs exclude-list mode.
    static func applyInclusion(
        keys: some Collection<String>,
        included: Bool,
        to font: inout FontDocument,
        allInstanceKeys: Set<String> = []
    ) {
        InstanceInclusion.applyInclusion(
            keys: keys,
            included: included,
            to: &font,
            allInstanceKeys: allInstanceKeys
        )
    }

    /// Whitelist plan keys that match fvar; clears exclude list.
    static func applyTrimNonOriginals(keys: [String], to font: inout FontDocument) {
        font.includedInstanceKeys = keys
        font.excludedInstanceKeys = []
    }

    /// Leave whitelist mode (all styles included unless excluded).
    static func clearTrimToOriginals(to font: inout FontDocument) {
        font.includedInstanceKeys = []
    }

    func setAxisInstanceGridEnabled(tag: String, enabled: Bool) {
        guard let axis = selectedFont?.axes.first(where: { $0.tag == tag }) else { return }
        if axis.isDesignRecordOnly {
            guard axis.canDemoteFromRegistration else { return }
        }
        updateAxisRole(tag: tag, role: enabled ? .instance : .statOnly)
    }

    func setAxisStatOnly(tag: String, statOnly: Bool) {
        setAxisInstanceGridEnabled(tag: tag, enabled: !statOnly)
    }

    func axisParticipatesInInstanceGrid(tag: String) -> Bool {
        if NamingToken.isClarifier(tag) { return false }
        return selectedFont?.axes.first(where: { $0.tag == tag })?.role == .instance
    }

    func isRegistrationNamingAxis(tag: String) -> Bool {
        selectedFont?.axes.first(where: { $0.tag == tag })?.isDesignRecordOnly == true
    }

    func clarifierCoveredByRegistration(category: FileClarifierCategory, for fontID: String) -> Bool {
        guard let font = font(forProjectID: activeProjectID ?? "", fontID: fontID) else { return false }
        return RegistrationAxisSupport.clarifierCategoriesCoveredByRegistration(font: font).contains(category)
    }
}
