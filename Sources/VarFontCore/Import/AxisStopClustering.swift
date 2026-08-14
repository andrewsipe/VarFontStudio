import Foundation

/// Groups an instance-role axis's observed coordinates by the style name they actually belong
/// to, then decides which named groups are safe to collapse into one Format 1 stop versus which
/// are entangled with another axis and need Format 4 combinations instead.
///
/// Two failure modes this exists to avoid:
/// - Proximity clustering: nearby coordinates on the same axis can belong to *different* names
///   (opsz-compensated weight ladders put "Poster Thin" and "Title Extra Thin" a hair apart).
/// - Peeling that requires every other axis at default: that only ever names the slice that sits
///   at the axis default, leaving every other cut as numeric fallbacks.
///
/// No axis tag is special-cased and no fixed percentage/ratio constant is used. The axis being
/// clustered is discovered generically; the split point between "one stop" and "needs Format 4"
/// is the largest jump in a locally-normalized spread statistic, found fresh per font.
public enum AxisStopClustering {
    public struct Cluster: Equatable, Sendable {
        /// Peeled or shared residue name (case as first seen).
        public var name: String
        /// Distinct coordinate values on the axis being clustered, ascending.
        public var values: [Double]
        /// max(values) - min(values).
        public var span: Double
        /// Distance from this cluster's range to the nearest coordinate belonging to a
        /// different cluster on the same axis. `nil` when there is only one cluster.
        public var nearestForeignDistance: Double?
        /// span / nearestForeignDistance. `0` for single-coordinate or isolated clusters,
        /// `.infinity` when this cluster's range touches or overlaps another cluster's.
        public var entanglementRatio: Double
    }

    public struct AxisResult: Equatable, Sendable {
        public var axisTag: String
        public var clusters: [Cluster]
        /// Cluster names honest enough for one Format 1 stop (largest entanglement-gap cut).
        public var promoteNames: Set<String>
        /// True when at least one cluster is held back for Format 4 — this axis needs a
        /// companion axis somewhere rather than a full univariate ladder.
        public var hasEntanglement: Bool

        public func clusterName(for value: Double) -> String? {
            clusters.first { cluster in
                cluster.values.contains { AxisCoordinate.valuesEqual($0, value) }
            }?.name
        }

        public func cluster(named name: String) -> Cluster? {
            clusters.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
    }

    /// Clusters every instance-role axis that carries its own naming vocabulary in OpenType
    /// (`wght`, `wdth`, `opsz`, `ital`, `slnt`, `GRAD` — see `CompoundStatNaming.standaloneNamingTags`).
    /// Custom axes already get equivalent treatment from combo-only detection elsewhere and are
    /// left alone here.
    public static func classifyStandaloneAxes(
        instanceTags: [String],
        analysis: FontAnalysis
    ) -> [String: AxisResult] {
        var results: [String: AxisResult] = [:]
        for tag in instanceTags where CompoundStatNaming.standaloneNamingTags.contains(tag) {
            guard let result = classify(axisTag: tag, instanceTags: instanceTags, analysis: analysis) else {
                continue
            }
            results[tag] = result
        }
        return results
    }

    public static func classify(
        axisTag: String,
        instanceTags: [String],
        analysis: FontAnalysis
    ) -> AxisResult? {
        let clusters = clusters(axisTag: axisTag, instanceTags: instanceTags, analysis: analysis)
        guard !clusters.isEmpty else { return nil }
        let promote = promoteNames(from: clusters)
        let allNames = Set(clusters.map(\.name))
        return AxisResult(
            axisTag: axisTag,
            clusters: clusters,
            promoteNames: promote,
            hasEntanglement: promote != allNames
        )
    }

    // MARK: - Clustering (two methods, chosen structurally)

    /// Two ways to find which coordinates on `axisTag` share a style name:
    ///
    /// - **Residue peeling**: strip companion axes' own repeated-coordinate labels from each
    ///   instance's composed name; whatever's left names `axisTag`'s coordinate. Works when a
    ///   companion axis repeats often (peeling opsz's "Micro"/"Title"/"Poster" out of the name
    ///   is what lets Black's four opsz-compensated wght values collapse into one cluster).
    /// - **Direct labeling**: `axisTag`'s own coordinates, grouped by whatever token every
    ///   instance sitting at that exact coordinate shares. Works when `axisTag` itself repeats
    ///   often (opsz has only 4 distinct values, ~10 instances apiece — no peeling needed).
    ///
    /// A shearing axis (wght here) fails the second test — its coordinates barely repeat, so
    /// direct labeling can't merge Black's four near-values at all. A repeating axis (opsz here)
    /// fails the first test for the opposite reason: its companion (wght) almost never repeats a
    /// coordinate, so there's nothing reliable to peel, and residue peeling fragments into one
    /// cluster per instance. Whichever method actually consolidates wins: a real clustering can
    /// never produce more groups than there are distinct coordinates, so residue peeling losing
    /// that comparison is proof it fragmented rather than grouped.
    static func clusters(
        axisTag: String,
        instanceTags: [String],
        analysis: FontAnalysis
    ) -> [Cluster] {
        let instances = analysis.instancesExisting
        let distinctValues = Set(instances.compactMap { $0.coords[axisTag].map(AxisCoordinateFormat.canonical) })
        guard !distinctValues.isEmpty else { return [] }

        let peeled = residuePeelClusters(axisTag: axisTag, instanceTags: instanceTags, instances: instances)
        if !peeled.isEmpty, peeled.count <= distinctValues.count {
            return finalize(peeled, allValues: distinctValues)
        }
        let direct = directLabelClusters(axisTag: axisTag, instances: instances, distinctValues: distinctValues)
        return finalize(direct, allValues: distinctValues)
    }

    private static func residuePeelClusters(
        axisTag: String,
        instanceTags: [String],
        instances: [FontAnalysis.ExistingInstance]
    ) -> [String: (display: String, values: Set<Double>)] {
        let otherTags = instanceTags.filter { $0 != axisTag }
        var otherLabels: [String: [Double: String]] = [:]
        for tag in otherTags {
            otherLabels[tag] = coordinateLabels(for: tag, instances: instances)
        }

        var valuesByResidue: [String: (display: String, values: Set<Double>)] = [:]
        for instance in instances {
            guard let raw = instance.coords[axisTag] else { continue }
            let value = AxisCoordinateFormat.canonical(raw)
            var tokens = instance.composedName.split(separator: " ").map(String.init)
            for tag in otherTags {
                guard let coord = instance.coords[tag] else { continue }
                let canonical = AxisCoordinateFormat.canonical(coord)
                guard let label = otherLabels[tag]?[canonical], !label.isEmpty else { continue }
                removeTokens(matching: label, from: &tokens)
            }
            let residue = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !residue.isEmpty else { continue }
            let key = residue.lowercased()
            var entry = valuesByResidue[key] ?? (display: residue, values: [])
            entry.values.insert(value)
            valuesByResidue[key] = entry
        }
        return valuesByResidue
    }

    private static func directLabelClusters(
        axisTag: String,
        instances: [FontAnalysis.ExistingInstance],
        distinctValues: Set<Double>
    ) -> [String: (display: String, values: Set<Double>)] {
        let labels = coordinateLabels(for: axisTag, instances: instances)
        var groups: [String: (display: String, values: Set<Double>)] = [:]
        for value in distinctValues {
            let display = labels[value] ?? AxisCoordinateFormat.format(value)
            let key = display.lowercased()
            var entry = groups[key] ?? (display: display, values: [])
            entry.values.insert(value)
            groups[key] = entry
        }
        return groups
    }

    private static func finalize(
        _ grouped: [String: (display: String, values: Set<Double>)],
        allValues: Set<Double>
    ) -> [Cluster] {
        var clusters = grouped.values.map { entry -> Cluster in
            let sorted = entry.values.sorted()
            let span = (sorted.last ?? 0) - (sorted.first ?? 0)
            return Cluster(
                name: entry.display,
                values: sorted,
                span: span,
                nearestForeignDistance: nil,
                entanglementRatio: 0
            )
        }

        for i in clusters.indices {
            let ownValues = Set(clusters[i].values)
            let foreign = allValues.subtracting(ownValues)
            guard !foreign.isEmpty else { continue }
            let nearest = clusters[i].values
                .map { own in foreign.map { abs(own - $0) }.min() ?? .infinity }
                .min() ?? .infinity
            clusters[i].nearestForeignDistance = nearest
            clusters[i].entanglementRatio = nearest <= .ulpOfOne
                ? .infinity
                : clusters[i].span / nearest
        }

        return clusters.sorted { ($0.values.first ?? 0) < ($1.values.first ?? 0) }
    }

    /// For every distinct coordinate on `tag`, the set of composed-name tokens shared by every
    /// instance that sits at that exact coordinate (regardless of any other axis's value).
    /// Requires at least two instances at a coordinate to call anything "shared" — a coordinate
    /// visited once has nothing to intersect against and gets no label here.
    static func coordinateLabels(
        for tag: String,
        instances: [FontAnalysis.ExistingInstance]
    ) -> [Double: String] {
        var tokenListsByValue: [Double: [[String]]] = [:]
        for instance in instances {
            guard let raw = instance.coords[tag] else { continue }
            let value = AxisCoordinateFormat.canonical(raw)
            let tokens = instance.composedName.split(separator: " ").map(String.init)
            guard !tokens.isEmpty else { continue }
            tokenListsByValue[value, default: []].append(tokens)
        }

        var labels: [Double: String] = [:]
        for (value, tokenLists) in tokenListsByValue {
            guard tokenLists.count >= 2, let first = tokenLists.first else { continue }
            var common = Set(first.map { $0.lowercased() })
            for tokens in tokenLists.dropFirst() {
                common.formIntersection(Set(tokens.map { $0.lowercased() }))
            }
            guard !common.isEmpty else { continue }
            let ordered = first.filter { common.contains($0.lowercased()) }
            guard !ordered.isEmpty else { continue }
            labels[value] = ordered.joined(separator: " ")
        }
        return labels
    }

    private static func removeTokens(matching label: String, from tokens: inout [String]) {
        let labelTokens = label.split(separator: " ").map { $0.lowercased() }
        for labelToken in labelTokens {
            if let index = tokens.firstIndex(where: { $0.lowercased() == labelToken }) {
                tokens.remove(at: index)
            }
        }
    }

    // MARK: - Gap-based split (no fixed threshold)

    /// Promotes every cluster on the low-entanglement side of the largest jump in log-spread.
    /// Overlapping / high-ratio names on the other side stay combo-only. A single cluster, or
    /// clusters that are all mutually isolated (no real jump), promote everything.
    static func promoteNames(from clusters: [Cluster]) -> Set<String> {
        let allNames = Set(clusters.map(\.name))
        guard clusters.count > 1 else { return allNames }

        let ranked = clusters.sorted { $0.entanglementRatio < $1.entanglementRatio }
        let logSpread = ranked.map { cluster -> Double in
            cluster.entanglementRatio.isFinite ? log(cluster.entanglementRatio + 1) : .greatestFiniteMagnitude
        }

        // gaps[i] is the jump between ranked[i] and ranked[i+1]; a split "at index k" promotes
        // ranked[0...k] and holds ranked[(k+1)...] back.
        let gaps = (0..<(ranked.count - 1)).map { logSpread[$0 + 1] - logSpread[$0] }
        // A perfectly uniform axis (every cluster equally isolated, or all mutually untouched)
        // has no real jump to split on — promoting everything is correct, not an arbitrary pick.
        guard !gaps.allSatisfy({ $0 <= .ulpOfOne }) else { return allNames }
        guard let floorIndex = gaps.indices.max(by: { gaps[$0] < gaps[$1] }) else {
            return allNames
        }

        return Set(ranked[0...floorIndex].map(\.name))
    }
}
