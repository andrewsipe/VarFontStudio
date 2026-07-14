import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Inspector

    func isInstanceIncluded(_ key: String) -> Bool {
        instanceListDisplay.includedByKey[key]
            ?? instancePlan?.instances.first(where: { $0.key == key })?.included
            ?? true
    }

    func focusInspectorAxisStop(tag: String, stopID: String) {
        inspectorFocus.focusAxisTag(tag)
        selectedAxisStopID = stopID
    }

    func axisTag(forStopID stopID: String) -> String? {
        selectedFont?.axes.first { axis in
            axis.values.contains { $0.id == stopID }
        }?.tag
    }

    var conflictStopIDs: Set<String> {
        Set(axisConflictBundles.flatMap(\.involvedStopIDs))
    }

    func focusInspectorAxis(for instance: PlannedInstance, tag: String) {
        if let resolved = axisStop(for: instance, tag: tag) {
            focusInspectorAxisStop(tag: resolved.axisTag, stopID: resolved.stopID)
        }
    }

    func inspectorAxisCoordRows(for instance: PlannedInstance) -> [InspectorAxisCoordRow] {
        let order = project?.naming.order ?? instance.coords.keys.sorted()
        let extra = instance.coords.keys.filter { !order.contains($0) }.sorted()
        let tags = order.filter { instance.coords[$0] != nil } + extra

        return tags.compactMap { tag in
            guard let value = instance.coords[tag] else { return nil }
            let participatesInNaming = axisParticipatesInInstanceGrid(tag: tag)
            let link = instance.namingChain.first(where: { $0.tag == tag })
            let isElided = link?.elided ?? false
            let stop = axisStop(for: instance, tag: tag)
            let stopName: String
            if let link {
                stopName = link.name
            } else if let font = selectedFont,
                      let axis = font.axes.first(where: { $0.tag == tag }),
                      let match = axis.values.first(where: { AxisCoordinate.valuesEqual($0.value, value) }) {
                stopName = match.name
            } else {
                stopName = axisDisplayName(for: tag)
            }
            let showsElisionToggle = link != nil && stop != nil && participatesInNaming
            let isElidable: Bool
            if showsElisionToggle, let font = selectedFont,
               let axis = font.axes.first(where: { $0.tag == tag }),
               let match = axis.values.first(where: { $0.id == stop?.stopID }) {
                isElidable = match.elidable
            } else {
                isElidable = false
            }
            return InspectorAxisCoordRow(
                tag: tag,
                value: value,
                stopName: stopName,
                participatesInNaming: participatesInNaming,
                isElided: isElided,
                stopID: stop?.stopID,
                showsElisionToggle: showsElisionToggle,
                isElidable: isElidable
            )
        }
    }

    func openTypePreviewRows(for instance: PlannedInstance) -> [InspectorOpenTypeRow] {
        guard let font = selectedFont else { return [] }
        var rows: [InspectorOpenTypeRow] = []

        for link in instance.namingChain {
            let axisLabel = font.axes.first(where: { $0.tag == link.tag })?.displayName ?? link.tag
            let value = instance.coords[link.tag].map(StudioFormatting.axisValue) ?? "—"
            let elideNote = link.elided ? " · elidable" : ""
            rows.append(
                InspectorOpenTypeRow(
                    id: "stat-\(link.tag)",
                    table: "STAT",
                    field: "Instance coordinates",
                    content: "\(axisLabel) “\(link.name)” @ \(value)\(elideNote)",
                    sources: [.stat, .planned],
                    isDerived: true,
                    kind: .statAxisValue
                )
            )
        }

        let coordText = StudioFormatting.coordPairs(
            coords: instance.coords,
            namingOrder: project?.naming.order ?? []
        ).joined(separator: " ")

        rows.append(
            InspectorOpenTypeRow(
                id: "fvar-coords",
                table: "fvar",
                field: "coordinates",
                content: coordText,
                sources: [.fvar, .planned],
                isDerived: true,
                kind: .fvarCoordinates
            )
        )

        rows.append(
            InspectorOpenTypeRow(
                id: "fvar-subfamily",
                table: "fvar",
                field: "Subfamily name",
                content: "→ “\(instance.composedName)”",
                sources: [.fvar, .planned],
                isDerived: true,
                kind: .fvarSubfamilyNameID
            )
        )

        if let summary = instancePlan?.namePlanSummary {
            var parts: [String] = []
            if let prefix = summary.familyPSPrefix {
                parts.append("PS prefix: \(prefix)")
            }
            if let range = summary.newIDRange, range.count == 2 {
                parts.append("IDs \(range[0])–\(range[1])")
            }
            if let note = summary.note {
                parts.append(note)
            }
            if !parts.isEmpty {
                rows.append(
                    InspectorOpenTypeRow(
                        id: "name-summary",
                        table: "name",
                        field: "summary",
                        content: parts.joined(separator: " · "),
                        sources: [.name, .planned],
                        isDerived: true,
                        kind: .nameSummary
                    )
                )
            }
        }

        return rows
    }

    func showAllDuplicateInstances() {
        instanceFilter = .duplicates
        searchText = ""
    }

    func showDuplicateInstances(matchingName name: String) {
        instanceFilter = .duplicates
        searchText = name
    }

    func showDuplicateInstances(matching instance: PlannedInstance) {
        showDuplicateInstances(matchingName: instance.composedName)
    }

    func requestInstanceSearchFocus() {
        StudioFieldFocus.resignIfEditing()
        instanceSearchFocusToken = UUID()
    }

    func suggestedNewStopValue(for axis: AxisDefinition) -> Double {
        AxisStopSuggestions.suggestedValue(for: axis)
    }

    func conflictProposals(for bundle: AxisConflictBundle) -> [ConflictResolutionProposal] {
        guard let axis = selectedFont?.axes.first(where: { $0.tag == bundle.axisTag }) else { return [] }
        return ConflictResolver.proposals(for: bundle, axis: axis)
    }

    func conflictPreview(
        for bundle: AxisConflictBundle,
        applying action: ConflictFixAction
    ) -> ConflictFixPreview? {
        guard let font = selectedFont, let project else { return nil }
        return ConflictResolver.previewPlan(
            font: font,
            naming: project.naming,
            bundle: bundle,
            applying: action
        )
    }

    func currentConflictPreview(for bundle: AxisConflictBundle) -> ConflictFixPreview? {
        guard let font = selectedFont, let project else { return nil }
        let plan = InstancePlanner.plan(font: font, naming: project.naming)
        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: font.axes,
            namingOrder: project.naming.order
        )
        let remaining = bundles.filter { $0.axisTag == bundle.axisTag }.count
        return ConflictFixPreview(
            totalInstances: plan.instances.count,
            duplicateInstanceCount: plan.instances.filter(\.duplicate).count,
            remainingAxisConflicts: remaining,
            sampleComposedNames: Array(plan.instances.prefix(3).map(\.composedName)),
            resolvesConflict: remaining == 0
        )
    }

}
