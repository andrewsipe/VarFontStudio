import Foundation

public enum ComposedNameWarningRollup {
    public static func warnings(
        instances: [PlannedInstance],
        axes: [AxisDefinition],
        naming: NamingPolicy
    ) -> [PlanWarning] {
        var byName: [String: [PlannedInstance]] = [:]
        for instance in instances where instance.included {
            byName[instance.composedName, default: []].append(instance)
        }

        return byName.compactMap { composedName, group in
            guard group.count > 1 else { return nil }
            return rollupWarning(
                composedName: composedName,
                instances: group,
                axes: axes,
                naming: naming
            )
        }
        .sorted { $0.name ?? "" < $1.name ?? "" }
    }

    private static func rollupWarning(
        composedName: String,
        instances: [PlannedInstance],
        axes: [AxisDefinition],
        naming: NamingPolicy
    ) -> PlanWarning {
        let keys = instances.map(\.key)
        let sampleKeys = Array(keys.prefix(8))
        let keysField = sampleKeys.count < keys.count
            ? sampleKeys + ["+\(keys.count - sampleKeys.count) more"]
            : sampleKeys

        var stopIDs = Set<String>()
        var axisCounts: [String: Int] = [:]

        if instances.count >= 2 {
            let anchor = instances[0]
            for duplicate in instances.dropFirst() {
                let detail = NamingConflictAnalyzer.composedNameDuplicateWarning(
                    composedName: composedName,
                    priorKey: anchor.key,
                    priorCoords: anchor.coords,
                    currentKey: duplicate.key,
                    currentCoords: duplicate.coords,
                    axes: axes,
                    naming: naming
                )
                stopIDs.formUnion(detail.stopIDs ?? [])
                if let axis = detail.axis {
                    axisCounts[axis, default: 0] += 1
                }
            }
        }

        let primaryAxis = primaryAxisTag(from: axisCounts, naming: naming)

        return PlanWarning(
            code: "duplicate_composed_name",
            axis: primaryAxis,
            name: composedName,
            keys: keysField,
            stopIDs: stopIDs.isEmpty ? nil : Array(stopIDs).sorted(),
            message: "Composed name “\(composedName)” is used by \(instances.count) instances.",
            hint: "The stops on these axes are contributing identical labels — rename one, or elide it."
        )
    }

    private static func primaryAxisTag(
        from axisCounts: [String: Int],
        naming: NamingPolicy
    ) -> String? {
        axisCounts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            let lhsOrder = naming.order.firstIndex(of: lhs.key) ?? Int.max
            let rhsOrder = naming.order.firstIndex(of: rhs.key) ?? Int.max
            if lhsOrder != rhsOrder { return lhsOrder > rhsOrder }
            return lhs.key > rhs.key
        }?.key
    }
}
