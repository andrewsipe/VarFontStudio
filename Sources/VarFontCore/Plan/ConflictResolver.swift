import Foundation

public enum ConflictResolver {
    public static func proposals(
        for bundle: AxisConflictBundle,
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let involved = bundle.stops(from: axis)
        guard involved.count >= 2 else { return [] }

        switch bundle.kind {
        case .duplicateValue:
            return duplicateValueProposals(involved: involved, axis: axis)
        case .duplicateName:
            return duplicateNameProposals(involved: involved, axis: axis)
        case .duplicateValueAndName:
            return duplicateValueAndNameProposals(involved: involved, axis: axis)
        }
    }

    public static func previewPlan(
        font: FontDocument,
        naming: NamingPolicy,
        bundle: AxisConflictBundle,
        applying action: ConflictFixAction
    ) -> ConflictFixPreview {
        var mutatedFont = font
        apply(action, axisTag: bundle.axisTag, to: &mutatedFont)

        let plan = InstancePlanner.plan(font: mutatedFont, naming: naming)
        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: mutatedFont.axes,
            namingOrder: naming.order
        )
        let remaining = bundles.filter { $0.axisTag == bundle.axisTag }.count
        let duplicateCount = plan.instances.filter(\.duplicate).count
        let samples = plan.instances.prefix(3).map(\.composedName)

        return ConflictFixPreview(
            totalInstances: plan.instances.count,
            duplicateInstanceCount: duplicateCount,
            remainingAxisConflicts: remaining,
            sampleComposedNames: Array(samples),
            resolvesConflict: remaining == 0
        )
    }

    public static func symptomSummary(
        for bundle: AxisConflictBundle,
        font: FontDocument,
        naming: NamingPolicy
    ) -> String {
        let plan = InstancePlanner.plan(font: font, naming: naming)
        let duplicateCount = plan.instances.filter(\.duplicate).count
        if duplicateCount > 0 {
            return "\(duplicateCount) instance\(duplicateCount == 1 ? "" : "s") share composed names"
        }
        switch bundle.kind {
        case .duplicateValue:
            return "Duplicate values on this axis expand the instance grid"
        case .duplicateName:
            return "Duplicate stop names can produce identical composed names"
        case .duplicateValueAndName:
            return "Duplicate values and names on this axis affect instance naming"
        }
    }

    public static func apply(
        _ action: ConflictFixAction,
        axisTag: String,
        to font: inout FontDocument
    ) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }) else { return }

        switch action {
        case let .removeStop(stopID):
            font.axes[axisIndex].values.removeAll { $0.id == stopID }

        case let .revalueStop(stopID, newValue):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            var clamped = newValue
            let axis = font.axes[axisIndex]
            if let min = axis.min { clamped = max(clamped, min) }
            if let max = axis.max { clamped = min(clamped, max) }
            font.axes[axisIndex].values[stopIndex].value = clamped
            font.axes[axisIndex].values.sort { $0.value < $1.value }

        case let .renameStop(stopID, newName):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            font.axes[axisIndex].values[stopIndex].name = newName

        case let .setElidable(stopID, elidable):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            if elidable {
                for index in font.axes[axisIndex].values.indices {
                    font.axes[axisIndex].values[index].elidable =
                        font.axes[axisIndex].values[index].id == stopID
                }
            } else {
                font.axes[axisIndex].values[stopIndex].elidable = false
            }

        case let .compound(actions):
            for step in actions {
                apply(step, axisTag: axisTag, to: &font)
            }
        }
    }

    // MARK: - Proposal builders

    static func targetStopID(for action: ConflictFixAction) -> String {
        switch action {
        case let .removeStop(stopID),
             let .revalueStop(stopID, _),
             let .renameStop(stopID, _),
             let .setElidable(stopID, _):
            return stopID
        case let .compound(actions):
            return actions.compactMap { targetStopID(for: $0) }.first ?? ""
        }
    }

    private static func duplicateValueProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let sorted = involved.sorted { $0.value < $1.value }
        guard let keep = preferredKeepStop(in: sorted),
              let remove = sorted.first(where: { $0.id != keep.id }) else {
            return []
        }

        var proposals: [ConflictResolutionProposal] = [
            ConflictResolutionProposal(
                id: "remove-\(remove.id)",
                title: "Remove “\(remove.name)”",
                detail: "Keep “\(keep.name)” at \(AxisStopSuggestions.formatValue(keep.value)) and remove the duplicate stop.",
                action: .removeStop(stopID: remove.id),
                keepStopID: keep.id
            ),
        ]

        let suggested = AxisStopSuggestions.suggestedValue(
            for: axis,
            excludingStopIDs: Set(sorted.map(\.id).filter { $0 != remove.id })
        )
        proposals.append(
            ConflictResolutionProposal(
                id: "revalue-\(remove.id)",
                title: "Change “\(remove.name)” to \(AxisStopSuggestions.formatValue(suggested))",
                detail: "Keep both stops with unique values.",
                action: .revalueStop(stopID: remove.id, newValue: suggested),
                keepStopID: keep.id
            )
        )

        return proposals
    }

    private static func duplicateNameProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let sorted = involved.sorted { $0.value < $1.value }
        guard let keep = preferredKeepStop(in: sorted),
              let rename = sorted.first(where: { $0.id != keep.id }) else {
            return []
        }

        let newName = "\(rename.name) (\(AxisStopSuggestions.formatValue(rename.value)))"
        var proposals: [ConflictResolutionProposal] = [
            ConflictResolutionProposal(
                id: "rename-\(rename.id)",
                title: "Rename “\(rename.name)” to “\(newName)”",
                detail: "Keep both stops; distinguish names by value.",
                action: .renameStop(stopID: rename.id, newName: newName),
                keepStopID: keep.id
            ),
            ConflictResolutionProposal(
                id: "remove-\(rename.id)",
                title: "Remove “\(rename.name)” at \(AxisStopSuggestions.formatValue(rename.value))",
                detail: "Keep “\(keep.name)” at \(AxisStopSuggestions.formatValue(keep.value)).",
                action: .removeStop(stopID: rename.id),
                keepStopID: keep.id
            ),
        ]

        if axis.role == .instance {
            proposals.append(
                ConflictResolutionProposal(
                    id: "elide-\(keep.id)",
                    title: "Mark “\(keep.name)” as elidable",
                    detail: "Only one stop contributes “\(keep.name)” to composed instance names.",
                    action: .setElidable(stopID: keep.id, elidable: true),
                    keepStopID: keep.id
                )
            )
        }

        return proposals
    }

    private static func duplicateValueAndNameProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        var proposals = duplicateValueProposals(involved: involved, axis: axis)
        let sorted = involved.sorted { $0.value < $1.value }
        if let remove = sorted.last,
           proposals.contains(where: {
               if case let .removeStop(id) = $0.action { return id == remove.id }
               return false
           }) == false {
            proposals.insert(
                ConflictResolutionProposal(
                    id: "remove-redundant-\(remove.id)",
                    title: "Remove redundant stop “\(remove.name)”",
                    detail: "Same value and name as another stop on this axis.",
                    action: .removeStop(stopID: remove.id),
                    keepStopID: sorted.first?.id
                ),
                at: 0
            )
        }
        return proposals
    }
}
