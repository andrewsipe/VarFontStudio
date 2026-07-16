import Foundation

/// Keeps axis tree order, naming-order axis chips, STAT design-axis tags, and
/// Format 4 indices aligned when the user reorders axes.
public enum AxisOrderRealigner {
    // MARK: - Canonical order

    /// Axis tags from naming order first, then any font-local tags not in naming (stable tail).
    public static func canonicalAxisTagOrder(namingOrder: [String], fontAxisTags: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for token in namingOrder where !NamingToken.isSpecialToken(token) {
            guard fontAxisTags.contains(token), !seen.contains(token) else { continue }
            result.append(token)
            seen.insert(token)
        }
        for tag in fontAxisTags where !seen.contains(tag) {
            result.append(tag)
            seen.insert(tag)
        }
        return result
    }

    /// Reorders axis definitions to match `tagOrder`, appending unknown tags at the end.
    public static func permuteAxes(_ axes: [AxisDefinition], toTagOrder tagOrder: [String]) -> [AxisDefinition] {
        let byTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        var ordered: [AxisDefinition] = []
        var seen = Set<String>()
        for tag in tagOrder {
            guard let axis = byTag[tag], !seen.contains(tag) else { continue }
            ordered.append(axis)
            seen.insert(tag)
        }
        for axis in axes where !seen.contains(axis.tag) {
            ordered.append(axis)
            seen.insert(axis.tag)
        }
        return ordered
    }

    /// Permutes only axis-tag tokens inside naming order; clarifiers / PS hyphen stay put.
    public static func permuteNamingAxisTags(
        _ namingOrder: [String],
        axisTags: Set<String>,
        toAxisTagOrder: [String]
    ) -> [String] {
        let target = toAxisTagOrder.filter { axisTags.contains($0) }
        var iterator = target.makeIterator()
        return namingOrder.map { token in
            guard axisTags.contains(token) else { return token }
            return iterator.next() ?? token
        }
    }

    /// Design-axis record order follows the canonical axis order for design tags.
    public static func syncStatDesignAxisTags(
        canonicalOrder: [String],
        currentDesignTags: [String],
        axes: [AxisDefinition]
    ) -> [String] {
        let designUniverse: Set<String>
        if currentDesignTags.isEmpty {
            designUniverse = Set(axes.map(\.tag))
        } else {
            designUniverse = Set(
                currentDesignTags
                    + axes.filter { $0.isDesignRecordOnly && !currentDesignTags.contains($0.tag) }.map(\.tag)
            )
        }
        var result: [String] = []
        var seen = Set<String>()
        for tag in canonicalOrder where designUniverse.contains(tag) {
            result.append(tag)
            seen.insert(tag)
        }
        for tag in currentDesignTags where designUniverse.contains(tag) && !seen.contains(tag) {
            result.append(tag)
            seen.insert(tag)
        }
        return result
    }

    /// fvar axis write order: canonical order filtered to axes that carry an fvar scale.
    public static func fvarTagOrder(from canonicalOrder: [String], axes: [AxisDefinition]) -> [String] {
        let fvarTags = Set(axes.filter(\.hasFvarScale).map(\.tag))
        return canonicalOrder.filter { fvarTags.contains($0) }
    }

    // MARK: - Compounds / instances

    public static func remapCompounds(
        _ compounds: inout [CompoundStatValue],
        designAxisOrder: [AxisDefinition]
    ) {
        for index in compounds.indices {
            CompoundStatCoordinateSync.syncIndicesAndValues(
                compound: &compounds[index],
                designAxisOrder: designAxisOrder
            )
        }
    }

    /// Keeps inclusion whitelist but sorts keys to match a freshly generated plan order.
    public static func resortIncludedInstanceKeys(
        currentKeys: [String],
        planInstanceKeys: [String]
    ) -> [String] {
        guard !currentKeys.isEmpty else { return currentKeys }
        let whitelist = Set(currentKeys)
        let resorted = planInstanceKeys.filter { whitelist.contains($0) }
        let missing = currentKeys.filter { !planInstanceKeys.contains($0) }
        return resorted + missing
    }

    /// Applies canonical tag order to one font document (axes, design tags, compounds).
    public static func applyCanonicalOrder(
        to font: inout FontDocument,
        canonicalOrder: [String]
    ) {
        font.axes = permuteAxes(font.axes, toTagOrder: canonicalOrder)
        font.statDesignAxisTags = syncStatDesignAxisTags(
            canonicalOrder: font.axes.map(\.tag),
            currentDesignTags: font.statDesignAxisTags,
            axes: font.axes
        )
        remapCompounds(&font.compoundStatValues, designAxisOrder: font.axes)
    }
}
