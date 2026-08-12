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

    /// Include/exclude helpers that respect whitelist vs exclude-list mode.
    ///
    /// When excluding empties the whitelist, converts to exclude-list mode using
    /// `allInstanceKeys`. An empty whitelist means “include all” in the planner —
    /// without this conversion, Exclude All after Origin File’s Instances Only
    /// would flip every style back on.
    public static func applyInclusion(
        keys: some Collection<String>,
        included: Bool,
        to font: inout FontDocument,
        allInstanceKeys: Set<String>
    ) {
        let keySet = Set(keys)
        guard !keySet.isEmpty else { return }
        if !font.includedInstanceKeys.isEmpty {
            if included {
                for key in keySet where !font.includedInstanceKeys.contains(key) {
                    font.includedInstanceKeys.append(key)
                }
            } else {
                font.includedInstanceKeys.removeAll { keySet.contains($0) }
                if font.includedInstanceKeys.isEmpty {
                    // Leave whitelist mode without accidentally including styles that
                    // were outside the whitelist (or the keys just removed).
                    let universe = allInstanceKeys.union(keySet)
                    font.excludedInstanceKeys = universe.sorted()
                }
            }
        } else if included {
            font.excludedInstanceKeys.removeAll { keySet.contains($0) }
        } else {
            for key in keySet where !font.excludedInstanceKeys.contains(key) {
                font.excludedInstanceKeys.append(key)
            }
        }
    }
}
