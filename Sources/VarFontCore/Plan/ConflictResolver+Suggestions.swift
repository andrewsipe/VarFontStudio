import Foundation

extension ConflictResolver {
    public static func validateRename(
        _ name: String,
        for stop: AxisValue,
        axis: AxisDefinition
    ) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Name is required." }
        let duplicate = axis.values.contains { other in
            other.id != stop.id && other.name == trimmed
        }
        if duplicate { return "Another stop already uses this name." }
        return nil
    }

    public static func validateRevalue(
        _ value: Double,
        for stop: AxisValue,
        axis: AxisDefinition,
        excludingStopIDs: Set<String>
    ) -> String? {
        if let min = axis.min, value < min {
            return "Value must be at least \(AxisStopSuggestions.formatValue(min))."
        }
        if let max = axis.max, value > max {
            return "Value must be at most \(AxisStopSuggestions.formatValue(max))."
        }
        let duplicate = axis.values.contains { other in
            other.id != stop.id && AxisCoordinate.valuesEqual(other.value, value)
        }
        if duplicate { return "Another stop already uses this value." }
        return nil
    }

    public static func parseValue(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    public static func previewInvolvedStops(
        axis: AxisDefinition,
        bundle: AxisConflictBundle,
        applying action: ConflictFixAction
    ) -> [ConflictStopOutcome] {
        let beforeStops = bundle.stops(from: axis).sorted { $0.value < $1.value }
        let targetID = targetStopID(for: action)

        var font = FontDocument(
            id: "preview",
            sourcePath: "",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: [axis],
            options: CommitOptions(),
            includedInstanceKeys: [],
            excludedInstanceKeys: [],
            overrides: InstanceOverrides()
        )
        apply(action, axisTag: axis.tag, to: &font)
        let afterByID = Dictionary(
            uniqueKeysWithValues: font.axes[0].values.map { ($0.id, $0) }
        )

        return beforeStops.map { before in
            let after = afterByID[before.id]
            return ConflictStopOutcome(
                stopID: before.id,
                valueBefore: before.value,
                nameBefore: before.name,
                elidableBefore: before.elidable,
                valueAfter: after?.value,
                nameAfter: after?.name,
                elidableAfter: after?.elidable,
                isRemoved: after == nil,
                isTarget: before.id == targetID
            )
        }
    }
}
