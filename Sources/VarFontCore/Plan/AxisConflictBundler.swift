import Foundation

public enum AxisConflictBundler {
    private static let axisConflictCodes: Set<String> = [
        "duplicate_stop_value",
        "duplicate_stop_name",
    ]

    public static func bundles(
        warnings: [PlanWarning],
        axes: [AxisDefinition],
        namingOrder: [String]
    ) -> [AxisConflictBundle] {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        let conflictWarnings = warnings.filter { axisConflictCodes.contains($0.code) }

        var valueWarningsByAxis: [String: [PlanWarning]] = [:]
        var nameWarningsByAxis: [String: [PlanWarning]] = [:]

        for warning in conflictWarnings {
            guard let axisTag = warning.axis else { continue }
            switch warning.code {
            case "duplicate_stop_value":
                valueWarningsByAxis[axisTag, default: []].append(warning)
            case "duplicate_stop_name":
                nameWarningsByAxis[axisTag, default: []].append(warning)
            default:
                break
            }
        }

        let axisTags = Set(valueWarningsByAxis.keys).union(nameWarningsByAxis.keys)
        let orderedTags = namingOrder.filter { axisTags.contains($0) }
            + axisTags.filter { !namingOrder.contains($0) }.sorted()

        return orderedTags.compactMap { axisTag in
            guard let axis = axisByTag[axisTag] else { return nil }
            return bundle(
                axis: axis,
                valueWarnings: valueWarningsByAxis[axisTag] ?? [],
                nameWarnings: nameWarningsByAxis[axisTag] ?? []
            )
        }
    }

    // MARK: - Private

    private static func bundle(
        axis: AxisDefinition,
        valueWarnings: [PlanWarning],
        nameWarnings: [PlanWarning]
    ) -> AxisConflictBundle? {
        guard !valueWarnings.isEmpty || !nameWarnings.isEmpty else { return nil }

        var groups: [AxisConflictGroup] = []
        var involvedStopIDs = Set<String>()

        for warning in valueWarnings {
            let ids = warning.stopIDs ?? []
            involvedStopIDs.formUnion(ids)
            let value = warning.name.flatMap(Double.init)
                ?? axis.values.first(where: { ids.contains($0.id) })?.value
            groups.append(
                AxisConflictGroup(
                    id: "value-\(warning.name ?? ids.joined(separator: "-"))",
                    duplicateValue: value,
                    duplicateName: nil,
                    stopIDs: ids
                )
            )
        }

        for warning in nameWarnings {
            let ids = warning.stopIDs ?? []
            involvedStopIDs.formUnion(ids)
            groups.append(
                AxisConflictGroup(
                    id: "name-\(warning.name ?? ids.joined(separator: "-"))",
                    duplicateValue: nil,
                    duplicateName: warning.name,
                    stopIDs: ids
                )
            )
        }

        let valueStopIDs = Set(valueWarnings.flatMap { $0.stopIDs ?? [] })
        let nameStopIDs = Set(nameWarnings.flatMap { $0.stopIDs ?? [] })
        let hasOverlap = !valueStopIDs.isDisjoint(with: nameStopIDs)

        let kind: AxisConflictKind
        if !valueWarnings.isEmpty, !nameWarnings.isEmpty, hasOverlap {
            kind = .duplicateValueAndName
        } else if !valueWarnings.isEmpty {
            kind = .duplicateValue
        } else {
            kind = .duplicateName
        }

        let label = axisLabel(axis)
        return AxisConflictBundle(
            axisTag: axis.tag,
            axisLabel: label,
            kind: kind,
            groups: groups,
            involvedStopIDs: Array(involvedStopIDs)
        )
    }

    private static func axisLabel(_ axis: AxisDefinition) -> String {
        if let displayName = axis.displayName, !displayName.isEmpty {
            return displayName
        }
        return axis.tag
    }
}
