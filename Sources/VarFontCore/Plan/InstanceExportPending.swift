import Foundation

/// Compares planned included instances against fvar instances on the working binary.
public enum InstanceExportPending {
    public static func fvarInstanceKeys(from analysis: FontAnalysis) -> Set<String> {
        Set(analysis.instancesExisting.map(\.key))
    }

    public static func fvarAxisTags(from analysis: FontAnalysis) -> Set<String> {
        Set(analysis.instancesExisting.flatMap { $0.coords.keys })
    }

    /// Project keys include pinned non-grid axes; fvar keys only carry instance axes.
    public static func fvarAlignedKey(coords: [String: Double], fvarTags: Set<String>) -> String {
        var filtered: [String: Double] = [:]
        filtered.reserveCapacity(fvarTags.count)
        for tag in fvarTags {
            if let value = coords[tag] {
                filtered[tag] = value
            }
        }
        return InstanceKeyBuilder.makeKey(coords: filtered)
    }

    /// Included plan keys that are not yet present in the working font's fvar table.
    public static func pendingIncludedKeys(
        plan: InstancePlan,
        analysis: FontAnalysis
    ) -> Set<String> {
        let fvarKeys = fvarInstanceKeys(from: analysis)
        let fvarTags = fvarAxisTags(from: analysis)

        var pending: Set<String> = []
        pending.reserveCapacity(plan.instances.count)

        for instance in plan.instances where instance.included {
            if fvarKeys.contains(instance.key) { continue }
            if !fvarTags.isEmpty {
                let aligned = fvarAlignedKey(coords: instance.coords, fvarTags: fvarTags)
                if fvarKeys.contains(aligned) { continue }
            }
            pending.insert(instance.key)
        }
        return pending
    }
}
