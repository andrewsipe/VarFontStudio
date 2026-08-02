import Foundation

/// Seeds missing Format 1 STAT stops from fvar instance coordinates on import.
///
/// Quiet path: add values that appear in fvar but not in STAT.
/// Intervention: same coordinate, STAT name ≠ fvar-attributed name.
public enum FvarStopSeeder {
    public struct Report: Equatable, Sendable {
        public var seededStopCount: Int
        public var conflicts: [NameConflict]
        public var compoundSuggestions: [CompoundSuggestion]

        public init(
            seededStopCount: Int = 0,
            conflicts: [NameConflict] = [],
            compoundSuggestions: [CompoundSuggestion] = []
        ) {
            self.seededStopCount = seededStopCount
            self.conflicts = conflicts
            self.compoundSuggestions = compoundSuggestions
        }

        public var isEmpty: Bool {
            seededStopCount == 0 && conflicts.isEmpty && compoundSuggestions.isEmpty
        }
    }

    public struct CompoundSuggestion: Equatable, Sendable, Identifiable {
        public var id: String
        public var fontID: String
        public var name: String
        public var coords: [String: Double]
        /// Display labels per axis tag (stop name at that coordinate).
        public var legLabels: [String: String]
        public var coveredInstanceCount: Int
        public var sampleInstanceNames: [String]

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            name: String,
            coords: [String: Double],
            legLabels: [String: String],
            coveredInstanceCount: Int,
            sampleInstanceNames: [String] = []
        ) {
            self.id = id
            self.fontID = fontID
            self.name = name
            self.coords = coords
            self.legLabels = legLabels
            self.coveredInstanceCount = coveredInstanceCount
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public struct NameConflict: Equatable, Sendable, Identifiable {
        public var id: String
        public var fontID: String
        public var axisTag: String
        public var axisLabel: String
        public var value: Double
        public var existingStopID: String
        public var existingName: String
        public var fvarName: String
        public var sampleInstanceNames: [String]

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            axisTag: String,
            axisLabel: String,
            value: Double,
            existingStopID: String,
            existingName: String,
            fvarName: String,
            sampleInstanceNames: [String] = []
        ) {
            self.id = id
            self.fontID = fontID
            self.axisTag = axisTag
            self.axisLabel = axisLabel
            self.value = value
            self.existingStopID = existingStopID
            self.existingName = existingName
            self.fvarName = fvarName
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public enum Resolution: Equatable, Sendable {
        case keepSTAT
        case takeFvar
        case custom(String)
    }

    /// Mutates `font.axes` in place. Returns seed counts and unresolved name conflicts.
    @discardableResult
    public static func seed(
        into font: inout FontDocument,
        analysis: FontAnalysis
    ) -> Report {
        let analysisByTag = Dictionary(uniqueKeysWithValues: analysis.axes.map { ($0.tag, $0) })
        var seededStopCount = 0
        var conflicts: [NameConflict] = []

        let instanceAxes = font.axes.filter { $0.role == .instance && $0.hasFvarScale }
        let instanceTags = instanceAxes.map(\.tag)

        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard axis.role == .instance, axis.hasFvarScale else { continue }

            let analyzed = analysisByTag[axis.tag]
            let observed = observedValues(for: axis.tag, analyzed: analyzed, analysis: analysis)
            guard !observed.isEmpty else { continue }

            for value in observed {
                let attributed = attributedName(
                    axisTag: axis.tag,
                    value: value,
                    instanceTags: instanceTags,
                    axes: font.axes,
                    analysis: analysis
                )

                if let existing = AxisCoordinate.matchingStop(in: font.axes[axisIndex].values, coordinate: value) {
                    if let fvarName = attributed?.name,
                       !namesEqual(existing.name, fvarName) {
                        conflicts.append(
                            NameConflict(
                                fontID: font.id,
                                axisTag: axis.tag,
                                axisLabel: axis.displayName ?? axis.tag,
                                value: value,
                                existingStopID: existing.id,
                                existingName: existing.name,
                                fvarName: fvarName,
                                sampleInstanceNames: attributed?.samples ?? []
                            )
                        )
                    }
                    continue
                }

                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(value, $0) } ?? false
                let name: String
                if let attributedName = attributed?.name {
                    name = attributedName
                } else if atDefault, let elidableName = AxisStopNamingDefaults.defaultElidableName(for: axis.tag) {
                    name = elidableName
                } else {
                    name = AxisCoordinateFormat.format(value)
                }
                let stop = AxisValue(
                    id: "\(axis.tag)-fvar-\(UUID().uuidString.prefix(8))",
                    value: AxisCoordinateFormat.canonical(value),
                    name: name,
                    elidable: atDefault,
                    statFormat: 1
                )
                font.axes[axisIndex].values.append(stop)
                seededStopCount += 1
            }

            font.axes[axisIndex].values.sort { $0.value < $1.value }
        }

        let suggestions = suggestCompounds(
            font: font,
            analysis: analysis,
            instanceTags: instanceTags
        )
        return Report(
            seededStopCount: seededStopCount,
            conflicts: conflicts,
            compoundSuggestions: suggestions
        )
    }

    public static func apply(
        resolution: Resolution,
        conflict: NameConflict,
        to font: inout FontDocument
    ) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == conflict.axisTag }),
              let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == conflict.existingStopID })
        else { return }

        switch resolution {
        case .keepSTAT:
            break
        case .takeFvar:
            font.axes[axisIndex].values[stopIndex].name = conflict.fvarName
        case .custom(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            font.axes[axisIndex].values[stopIndex].name = trimmed
        }
    }

    // MARK: - Observed values

    private static func observedValues(
        for tag: String,
        analyzed: FontAnalysis.AnalyzedAxis?,
        analysis: FontAnalysis
    ) -> [Double] {
        if let observed = analyzed?.fvarValuesObserved, !observed.isEmpty {
            return uniqueSorted(observed)
        }
        var values: [Double] = []
        for instance in analysis.instancesExisting {
            if let value = instance.coords[tag] {
                values.append(value)
            }
        }
        return uniqueSorted(values)
    }

    private static func uniqueSorted(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values.map(AxisCoordinateFormat.canonical).sorted() {
            if let last = result.last, AxisCoordinate.valuesEqual(last, value) { continue }
            result.append(value)
        }
        return result
    }

    // MARK: - Name attribution (univariate slice)

    private struct Attribution {
        var name: String
        var samples: [String]
    }

    /// Prefer instance names where every other instance-role axis sits at its fvar default.
    /// Peels known STAT stop tokens for those other axes; requires a single shared residue.
    private static func attributedName(
        axisTag: String,
        value: Double,
        instanceTags: [String],
        axes: [AxisDefinition],
        analysis: FontAnalysis
    ) -> Attribution? {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        let otherTags = instanceTags.filter { $0 != axisTag }

        let candidates = analysis.instancesExisting.filter { instance in
            guard let coord = instance.coords[axisTag],
                  AxisCoordinate.valuesEqual(coord, value) else { return false }
            for tag in otherTags {
                guard let other = axisByTag[tag], let defaultValue = other.default else { return false }
                let actual = instance.coords[tag] ?? defaultValue
                guard AxisCoordinate.valuesEqual(actual, defaultValue) else { return false }
            }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        var residues: [String] = []
        var samples: [String] = []
        for instance in candidates {
            let composed = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !composed.isEmpty else { continue }
            if samples.count < 3 { samples.append(composed) }

            var tokens = composed.split(separator: " ").map(String.init)
            for tag in otherTags {
                guard let other = axisByTag[tag] else { continue }
                let actual = instance.coords[tag] ?? other.default ?? 0
                guard let stop = AxisCoordinate.matchingStop(in: other.values, coordinate: actual) else {
                    continue
                }
                let stopName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !stopName.isEmpty else { continue }
                tokens.removeAll { namesEqual($0, stopName) }
            }

            let residue = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !residue.isEmpty else { return nil }
            // Numeric-only residue is not a strong attribution.
            if residue == AxisCoordinateFormat.format(value) { return nil }
            residues.append(residue)
        }

        guard let first = residues.first else { return nil }
        guard residues.allSatisfy({ namesEqual($0, first) }) else { return nil }
        return Attribution(name: first, samples: samples)
    }

    private static func namesEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    // MARK: - Format 4 suggestions

    /// After Format 1 seeding: find fvar names that only make sense as multi-axis combinations.
    /// Groups by residual name; compound legs are axes whose off-default values stay constant
    /// across that group (so weight drops out of DoubleRounded / FullRounded).
    private static func suggestCompounds(
        font: FontDocument,
        analysis: FontAnalysis,
        instanceTags: [String]
    ) -> [CompoundSuggestion] {
        let axisByTag = Dictionary(uniqueKeysWithValues: font.axes.map { ($0.tag, $0) })

        struct Candidate {
            var residue: String
            var offDefault: [String: Double]
            var sample: String
        }

        var candidates: [Candidate] = []
        for instance in analysis.instancesExisting {
            let composed = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !composed.isEmpty else { continue }

            var tokens = composed.split(separator: " ").map(String.init)
            var offDefault: [String: Double] = [:]

            for tag in instanceTags {
                guard let axis = axisByTag[tag] else { continue }
                let actual = instance.coords[tag] ?? axis.default ?? 0
                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(actual, $0) } ?? false
                if !atDefault {
                    offDefault[tag] = AxisCoordinateFormat.canonical(actual)
                }
                if let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: actual) {
                    let stopName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !stopName.isEmpty {
                        tokens.removeAll { namesEqual($0, stopName) }
                    }
                }
            }

            let residue = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !residue.isEmpty, offDefault.count >= 2 else { continue }
            candidates.append(Candidate(residue: residue, offDefault: offDefault, sample: composed))
        }

        var groups: [String: [Candidate]] = [:]
        for candidate in candidates {
            groups[candidate.residue.lowercased(), default: []].append(candidate)
        }

        var suggestions: [CompoundSuggestion] = []
        for group in groups.values {
            guard let head = group.first else { continue }
            let constantCoords = constantOffDefaultCoords(across: group.map(\.offDefault))
            guard constantCoords.count >= 2 else { continue }
            if font.compoundStatValues.contains(where: { coordsEqual($0.coords, constantCoords) }) {
                continue
            }
            if suggestions.contains(where: { coordsEqual($0.coords, constantCoords) }) {
                continue
            }

            var legLabels: [String: String] = [:]
            for (tag, value) in constantCoords {
                if let axis = axisByTag[tag],
                   let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) {
                    let label = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    legLabels[tag] = label.isEmpty ? AxisCoordinateFormat.format(value) : label
                } else {
                    legLabels[tag] = AxisCoordinateFormat.format(value)
                }
            }

            var samples: [String] = []
            for candidate in group {
                if samples.count >= 3 { break }
                if !samples.contains(where: { namesEqual($0, candidate.sample) }) {
                    samples.append(candidate.sample)
                }
            }

            suggestions.append(
                CompoundSuggestion(
                    fontID: font.id,
                    name: head.residue,
                    coords: constantCoords,
                    legLabels: legLabels,
                    coveredInstanceCount: group.count,
                    sampleInstanceNames: samples
                )
            )
        }

        return suggestions.sorted {
            if $0.coveredInstanceCount != $1.coveredInstanceCount {
                return $0.coveredInstanceCount > $1.coveredInstanceCount
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func constantOffDefaultCoords(across locations: [[String: Double]]) -> [String: Double] {
        guard let first = locations.first else { return [:] }
        let tags = Set(locations.flatMap(\.keys))
        var constant: [String: Double] = [:]
        for tag in tags {
            let values = locations.compactMap { $0[tag] }
            guard values.count == locations.count,
                  let head = values.first,
                  values.allSatisfy({ AxisCoordinate.valuesEqual($0, head) })
            else { continue }
            constant[tag] = head
        }
        // Preserve axis-tree-ish order: first location's key order, then leftovers.
        let preferred = first.keys.filter { constant[$0] != nil }
        let leftovers = constant.keys.filter { !preferred.contains($0) }.sorted()
        var ordered: [String: Double] = [:]
        for tag in preferred + leftovers {
            ordered[tag] = constant[tag]
        }
        return ordered
    }

    private static func coordsEqual(_ lhs: [String: Double], _ rhs: [String: Double]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (tag, value) in lhs {
            guard let other = rhs[tag], AxisCoordinate.valuesEqual(value, other) else { return false }
        }
        return true
    }
}
