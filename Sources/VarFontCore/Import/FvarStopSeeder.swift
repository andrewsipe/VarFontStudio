import Foundation

/// Seeds missing Format 1 STAT stops from fvar instance coordinates on import.
///
/// Quiet path: add values that appear in fvar but not in STAT.
/// Intervention: same coordinate, STAT name ≠ fvar-attributed name.
public enum FvarStopSeeder {
    public struct Report: Equatable, Sendable {
        public var seededStopCount: Int
        public var conflicts: [NameConflict]

        public init(seededStopCount: Int = 0, conflicts: [NameConflict] = []) {
            self.seededStopCount = seededStopCount
            self.conflicts = conflicts
        }

        public var isEmpty: Bool { seededStopCount == 0 && conflicts.isEmpty }
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

        return Report(seededStopCount: seededStopCount, conflicts: conflicts)
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
}
