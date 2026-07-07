import Foundation

public enum AxisStopValidator {
    public static func validate(axes: [AxisDefinition]) -> [PlanWarning] {
        var warnings: [PlanWarning] = []
        for axis in axes {
            warnings.append(contentsOf: duplicateValueWarnings(for: axis))
            warnings.append(contentsOf: StatFormat3Pairing.orphanLinkWarnings(for: axis))
            if axis.role == .instance {
                warnings.append(contentsOf: duplicateNameWarnings(for: axis))
            }
        }
        return warnings
    }

    // MARK: - Private

    private static func duplicateValueWarnings(for axis: AxisDefinition) -> [PlanWarning] {
        var groups: [Double: [AxisValue]] = [:]
        for stop in axis.values {
            if let existingKey = groups.keys.first(where: { AxisCoordinate.valuesEqual($0, stop.value) }) {
                groups[existingKey, default: []].append(stop)
            } else {
                groups[stop.value] = [stop]
            }
        }

        return groups
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { _, stops in
            let label = axisLabel(axis)
            let valueText = formatValue(stops[0].value)
            let names = stops.map(\.name).sorted().joined(separator: "”, “")
            return PlanWarning(
                code: "duplicate_stop_value",
                axis: axis.tag,
                name: valueText,
                stopIDs: stops.map(\.id).sorted(),
                message: "\(label) has \(stops.count) stops at value \(valueText) (“\(names)”).",
                hint: "Two stops land on the same value here — remove one, or give it a different number."
            )
        }
    }

    private static func duplicateNameWarnings(for axis: AxisDefinition) -> [PlanWarning] {
        var groups: [String: [AxisValue]] = [:]
        for stop in axis.values {
            groups[stop.name, default: []].append(stop)
        }

        return groups
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .compactMap { name, stops in
            let contributing = stops.filter { !$0.elidable }
            guard contributing.count > 1 else { return nil }
            let label = axisLabel(axis)
            let valueList = stops.sorted { $0.value < $1.value }.map { "\(formatValue($0.value))" }.joined(separator: ", ")
            return PlanWarning(
                code: "duplicate_stop_name",
                axis: axis.tag,
                name: name,
                stopIDs: stops.map(\.id).sorted(),
                message: "\(label) has \(stops.count) stops named “\(name)” at values \(valueList).",
                hint: "A couple of stops share this name — rename one, remove one, or elide it so only one feeds composed names."
            )
        }
    }

    private static func axisLabel(_ axis: AxisDefinition) -> String {
        if let displayName = axis.displayName, !displayName.isEmpty {
            return "\(displayName) (\(axis.tag))"
        }
        return "Axis \(axis.tag)"
    }

    private static func formatValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        var text = String(value)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        return text
    }
}
