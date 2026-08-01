import Foundation

/// Format 4 compound matching and emit placement (OpenType / fontTools-aligned).
public enum CompoundStatNaming {
    /// Non-overlapping matches, most-specific (most legs) first.
    public static func selectedMatches(
        compounds: [CompoundStatValue],
        coords: [String: Double]
    ) -> [CompoundStatValue] {
        let matching = compounds.filter { matches($0, coords: coords) }
            .sorted { $0.coords.count > $1.coords.count }
        var claimed = Set<String>()
        var selected: [CompoundStatValue] = []
        for compound in matching {
            let tags = Set(compound.coords.keys)
            guard tags.count >= 2, claimed.isDisjoint(with: tags) else { continue }
            claimed.formUnion(tags)
            selected.append(compound)
        }
        return selected
    }

    public static func matches(_ compound: CompoundStatValue, coords: [String: Double]) -> Bool {
        guard compound.coords.count >= 2 else { return false }
        for (tag, value) in compound.coords {
            guard let actual = coords[tag], AxisCoordinate.valuesEqual(actual, value) else {
                return false
            }
        }
        return true
    }

    /// Emit each selected compound at the earliest covered tag in `namingOrder`.
    public static func emitPlan(
        selected: [CompoundStatValue],
        namingOrder: [String]
    ) -> (emitAtTag: [String: CompoundStatValue], claimedTags: Set<String>) {
        var emitAtTag: [String: CompoundStatValue] = [:]
        var claimedTags = Set<String>()
        for compound in selected {
            let tags = Set(compound.coords.keys)
            claimedTags.formUnion(tags)
            if let first = namingOrder.first(where: { tags.contains($0) }) {
                emitAtTag[first] = compound
            } else if let fallback = tags.sorted().first {
                // Covered axes absent from naming order — still claim them; no emit slot.
                _ = fallback
            }
        }
        return (emitAtTag, claimedTags)
    }

    public static func chainTag(for compound: CompoundStatValue) -> String {
        compound.coords.keys.sorted().joined(separator: "+")
    }
}
