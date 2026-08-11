import Foundation

/// Builds export-inclusion whitelists from plan keys that match original fvar instances.
public enum InstanceInclusion {
    /// Plan instance keys that correspond to an fvar named instance (exact or fvar-aligned).
    ///
    /// Prefer these over raw `analysis.instancesExisting` keys: plan keys may include
    /// pinned axes that fvar keys omit.
    public static func planKeysMatchingFvar(
        plan: InstancePlan,
        analysis: FontAnalysis
    ) -> [String] {
        let fvarKeys = InstanceExportPending.fvarInstanceKeys(from: analysis)
        let fvarTags = InstanceExportPending.fvarAxisTags(from: analysis)
        guard !fvarKeys.isEmpty else { return [] }

        var matched: [String] = []
        matched.reserveCapacity(min(plan.instances.count, fvarKeys.count))
        var seen = Set<String>()

        for instance in plan.instances {
            let matches: Bool
            if fvarKeys.contains(instance.key) {
                matches = true
            } else if !fvarTags.isEmpty {
                let aligned = InstanceExportPending.fvarAlignedKey(
                    coords: instance.coords,
                    fvarTags: fvarTags
                )
                matches = fvarKeys.contains(aligned)
            } else {
                matches = false
            }
            guard matches, seen.insert(instance.key).inserted else { continue }
            matched.append(instance.key)
        }

        return matched.sorted()
    }

    /// Whether the font currently uses an originals whitelist.
    public static func isTrimmedToOriginals(_ font: FontDocument) -> Bool {
        !font.includedInstanceKeys.isEmpty
    }
}
