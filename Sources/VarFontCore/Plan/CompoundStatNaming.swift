import Foundation

/// Format 4 compound matching and emit placement (OpenType / fontTools-aligned).
public enum CompoundStatNaming {
    /// Axes that normally carry their own Format 1 names — omit from Format 4 legs
    /// in suggestions and the combination builder (weight especially should not participate).
    public static let standaloneNamingTags: Set<String> = [
        "wght", "wdth", "opsz", "ital", "slnt", "GRAD",
    ]

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
    ///
    /// When `splitAtHyphen` is true, a compound that spans `@pshyphen` only claims
    /// (and emits on) the after-hyphen legs so optical-size stops can still appear
    /// before the PostScript split.
    public static func emitPlan(
        selected: [CompoundStatValue],
        namingOrder: [String],
        splitAtHyphen: Bool = false
    ) -> (emitAtTag: [String: CompoundStatValue], claimedTags: Set<String>) {
        let hyphenIndex = splitAtHyphen
            ? namingOrder.firstIndex(where: NamingToken.isPostscriptHyphen)
            : nil
        let beforeTags: Set<String> = {
            guard let hyphenIndex else { return [] }
            return Set(namingOrder[..<hyphenIndex].filter { !NamingToken.isPostscriptHyphen($0) })
        }()
        let afterTags: Set<String> = {
            guard let hyphenIndex else { return [] }
            return Set(namingOrder[(hyphenIndex + 1)...].filter { !NamingToken.isPostscriptHyphen($0) })
        }()

        var emitAtTag: [String: CompoundStatValue] = [:]
        var claimedTags = Set<String>()
        for compound in selected {
            let tags = Set(compound.coords.keys)
            let spansHyphen = hyphenIndex != nil
                && !tags.isDisjoint(with: beforeTags)
                && !tags.isDisjoint(with: afterTags)
            let claimed = spansHyphen ? tags.subtracting(beforeTags) : tags
            claimedTags.formUnion(claimed)
            if let first = namingOrder.first(where: { claimed.contains($0) }) {
                emitAtTag[first] = compound
            }
        }
        return (emitAtTag, claimedTags)
    }

    public static func chainTag(for compound: CompoundStatValue) -> String {
        compound.coords.keys.sorted().joined(separator: "+")
    }

    /// Sort key order: naming order (instance axes), then Axis Tree order, then leftovers.
    /// Matches how Instances groups/walks coordinates so Combinations aren't alphabetical islands.
    public static func sortedByAxisOrder<T>(
        _ items: [T],
        coords: (T) -> [String: Double],
        name: (T) -> String = { _ in "" },
        axes: [AxisDefinition],
        namingOrder: [String] = []
    ) -> [T] {
        items.sorted { lhs, rhs in
            let comparison = compareCoords(
                coords(lhs),
                coords(rhs),
                axes: axes,
                namingOrder: namingOrder
            )
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            return name(lhs).localizedCaseInsensitiveCompare(name(rhs)) == .orderedAscending
        }
    }

    public static func sortedByAxisOrder(
        _ compounds: [CompoundStatValue],
        axes: [AxisDefinition],
        namingOrder: [String] = []
    ) -> [CompoundStatValue] {
        sortedByAxisOrder(
            compounds,
            coords: { $0.coords },
            name: { $0.name },
            axes: axes,
            namingOrder: namingOrder
        )
    }

    public static func compareCoords(
        _ lhs: [String: Double],
        _ rhs: [String: Double],
        axes: [AxisDefinition],
        namingOrder: [String] = []
    ) -> ComparisonResult {
        let tags = comparisonTags(lhs: lhs, rhs: rhs, axes: axes, namingOrder: namingOrder)
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        for tag in tags {
            let left = lhs[tag]
            let right = rhs[tag]
            switch (left, right) {
            case (nil, nil):
                continue
            case (nil, _):
                return .orderedAscending
            case (_, nil):
                return .orderedDescending
            case (let leftValue?, let rightValue?):
                if AxisCoordinate.valuesEqual(leftValue, rightValue) { continue }
                if let axis = axisByTag[tag] {
                    let leftIndex = stopIndex(in: axis, value: leftValue)
                    let rightIndex = stopIndex(in: axis, value: rightValue)
                    // Both on the Axis Tree: honor stop order (may differ from raw numeric
                    // when the user reordered Format 1 stops).
                    if let li = leftIndex, let ri = rightIndex, li != ri {
                        return li < ri ? .orderedAscending : .orderedDescending
                    }
                }
                // Off-grid Format 4 (or mixed stop/off-grid): same design-space rule as
                // the axis value line — lighter/smaller coordinates first. Do not park
                // compounds after every Format 1 stop just because they lack a tree slot.
                return leftValue < rightValue ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }

    private static func comparisonTags(
        lhs: [String: Double],
        rhs: [String: Double],
        axes: [AxisDefinition],
        namingOrder: [String]
    ) -> [String] {
        let present = Set(lhs.keys).union(rhs.keys)
        var ordered: [String] = []
        var seen = Set<String>()
        for tag in namingOrder where present.contains(tag) {
            ordered.append(tag)
            seen.insert(tag)
        }
        for axis in axes where present.contains(axis.tag) && !seen.contains(axis.tag) {
            ordered.append(axis.tag)
            seen.insert(axis.tag)
        }
        for tag in present.subtracting(seen).sorted() {
            ordered.append(tag)
        }
        return ordered
    }

    private static func stopIndex(in axis: AxisDefinition, value: Double) -> Int? {
        axis.values.firstIndex { AxisCoordinate.valuesEqual($0.value, value) }
    }
}
