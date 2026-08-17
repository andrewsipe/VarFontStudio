import Foundation

/// Format 2 range geometry: tile a covering from noms, or insert a nom and nip only
/// the neighboring shared edges.
public enum AxisStopRangeGeometry {
    public struct TiledStop: Sendable, Equatable {
        public var min: Double
        public var nom: Double
        public var max: Double
    }

    public enum Edge: String, Sendable, Equatable {
        case min
        case max
    }

    public struct NeighborRewrite: Sendable, Equatable {
        public var stopID: String
        public var name: String
        public var field: Edge
        public var from: Double?
        public var to: Double
    }

    public struct InsertRequest: Sendable, Equatable {
        public var value: Double
        public var name: String
        public var code: String?

        public init(value: Double, name: String, code: String? = nil) {
            self.value = value
            self.name = name
            self.code = code
        }
    }

    public enum InsertError: Error, Equatable, Sendable {
        case duplicate(Double)
        case empty
    }

    public struct InsertPlan: Sendable, Equatable {
        public var values: [AxisValue]
        public var rewrites: [NeighborRewrite]
        public var insertedIDs: [String]
    }

    public static func tile(noms: [Double], axisMin: Double, axisMax: Double) -> [TiledStop] {
        let sorted = noms.map(AxisCoordinateFormat.canonical).sorted()
        guard !sorted.isEmpty else { return [] }
        return sorted.enumerated().map { index, nom in
            let min = index == 0
                ? AxisCoordinateFormat.canonical(axisMin)
                : AxisCoordinateFormat.canonical((sorted[index - 1] + nom) / 2)
            let max = index == sorted.count - 1
                ? AxisCoordinateFormat.canonical(axisMax)
                : AxisCoordinateFormat.canonical((nom + sorted[index + 1]) / 2)
            return TiledStop(min: min, nom: nom, max: max)
        }
    }

    /// Insert Format 2 stops by nom. Existing stops stay. Only the stop before and after
    /// each new nom rewrite the shared edge so ranges meet without overlap.
    public static func insert(
        _ incoming: [InsertRequest],
        into values: [AxisValue],
        axisMin: Double,
        axisMax: Double,
        makeID: (Double) -> String
    ) -> Result<InsertPlan, InsertError> {
        guard !incoming.isEmpty else { return .failure(.empty) }

        var next = values
        var rewrites: [NeighborRewrite] = []
        var insertedIDs: [String] = []

        for request in incoming.sorted(by: { $0.value < $1.value }) {
            let nom = AxisCoordinateFormat.canonical(request.value)
            if next.contains(where: { AxisCoordinate.valuesEqual($0.value, nom) }) {
                return .failure(.duplicate(nom))
            }

            let sorted = next.sorted { $0.value < $1.value }
            let prev = sorted.last { $0.value < nom - AxisCoordinate.tolerance }
            let after = sorted.first { $0.value > nom + AxisCoordinate.tolerance }
            let min = prev.map { AxisCoordinateFormat.canonical(($0.value + nom) / 2) }
                ?? AxisCoordinateFormat.canonical(axisMin)
            let max = after.map { AxisCoordinateFormat.canonical((nom + $0.value) / 2) }
                ?? AxisCoordinateFormat.canonical(axisMax)

            if let prev, prev.statFormat != 3,
               let index = next.firstIndex(where: { $0.id == prev.id }) {
                var stop = next[index]
                let from = stop.rangeMax
                promoteToFormat2(
                    &stop,
                    axisMin: axisMin,
                    axisMax: axisMax,
                    neighbors: sorted,
                    sharedMax: min
                )
                if !optionalEqual(from, stop.rangeMax) {
                    rewrites.append(
                        NeighborRewrite(
                            stopID: stop.id,
                            name: stop.name,
                            field: .max,
                            from: from,
                            to: stop.rangeMax ?? min
                        )
                    )
                }
                next[index] = stop
            }

            if let after, after.statFormat != 3,
               let index = next.firstIndex(where: { $0.id == after.id }) {
                var stop = next[index]
                let from = stop.rangeMin
                promoteToFormat2(
                    &stop,
                    axisMin: axisMin,
                    axisMax: axisMax,
                    neighbors: sorted,
                    sharedMin: max
                )
                if !optionalEqual(from, stop.rangeMin) {
                    rewrites.append(
                        NeighborRewrite(
                            stopID: stop.id,
                            name: stop.name,
                            field: .min,
                            from: from,
                            to: stop.rangeMin ?? max
                        )
                    )
                }
                next[index] = stop
            }

            let id = makeID(nom)
            let name = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
            next.append(
                AxisValue(
                    id: id,
                    value: nom,
                    name: name.isEmpty ? AxisStopSuggestions.formatValue(nom) : name,
                    elidable: false,
                    statFormat: 2,
                    rangeMin: min,
                    rangeMax: max,
                    linkedValue: nil,
                    code: InstanceCodeBuilder.sanitize(request.code)
                )
            )
            insertedIDs.append(id)
        }

        next.sort { $0.value < $1.value }
        return .success(InsertPlan(values: next, rewrites: rewrites, insertedIDs: insertedIDs))
    }

    public static func rewriteSummary(_ rewrites: [NeighborRewrite]) -> String {
        guard !rewrites.isEmpty else {
            return "Neighbors keep their current edges."
        }
        return rewrites.map { rewrite in
            let from = rewrite.from.map { AxisStopSuggestions.formatValue($0) } ?? "—"
            let to = AxisStopSuggestions.formatValue(rewrite.to)
            return "\(rewrite.name) \(rewrite.field.rawValue) \(from) → \(to)"
        }.joined(separator: " · ")
    }

    // MARK: - Private

    private static func promoteToFormat2(
        _ stop: inout AxisValue,
        axisMin: Double,
        axisMax: Double,
        neighbors: [AxisValue],
        sharedMin: Double? = nil,
        sharedMax: Double? = nil
    ) {
        if stop.statFormat != 2 {
            stop.statFormat = 2
            stop.linkedValue = nil
            if stop.rangeMin == nil {
                if let previous = neighbors.last(where: { $0.value < stop.value - AxisCoordinate.tolerance }) {
                    stop.rangeMin = AxisCoordinateFormat.canonical((previous.value + stop.value) / 2)
                } else {
                    stop.rangeMin = AxisCoordinateFormat.canonical(axisMin)
                }
            }
            if stop.rangeMax == nil {
                if let following = neighbors.first(where: { $0.value > stop.value + AxisCoordinate.tolerance }) {
                    stop.rangeMax = AxisCoordinateFormat.canonical((stop.value + following.value) / 2)
                } else {
                    stop.rangeMax = AxisCoordinateFormat.canonical(axisMax)
                }
            }
        }
        if let sharedMin {
            stop.rangeMin = sharedMin
        }
        if let sharedMax {
            stop.rangeMax = sharedMax
        }
    }

    private static func optionalEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return AxisCoordinate.valuesEqual(left, right)
        default:
            return false
        }
    }
}
