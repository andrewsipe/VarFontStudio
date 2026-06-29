import Foundation

public enum NamingConflictAnalyzer {
    public static func composedNameDuplicateWarning(
        composedName: String,
        priorKey: String,
        priorCoords: [String: Double],
        currentKey: String,
        currentCoords: [String: Double],
        axes: [AxisDefinition],
        naming: NamingPolicy
    ) -> PlanWarning {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        var stopIDs: [String] = []
        var details: [String] = []

        for tag in naming.order {
            guard let axis = axisByTag[tag], axis.role == .instance else { continue }
            guard let valueA = priorCoords[tag], let valueB = currentCoords[tag] else { continue }

            let stopA = AxisCoordinate.matchingStop(in: axis.values, coordinate: valueA)
            let stopB = AxisCoordinate.matchingStop(in: axis.values, coordinate: valueB)
            let label = axis.displayName ?? tag

            if AxisCoordinate.valuesEqual(valueA, valueB) {
                let matches = axis.values.filter { AxisCoordinate.valuesEqual($0.value, valueA) }
                if matches.count > 1 {
                    stopIDs.append(contentsOf: matches.map(\.id))
                    let names = matches.map(\.name).joined(separator: "”, “")
                    details.append(
                        "\(label) value \(formatValue(valueA)) is defined by multiple stops (“\(names)”)"
                    )
                }
                continue
            }

            if let stopA, let stopB {
                stopIDs.append(stopA.id)
                stopIDs.append(stopB.id)
                if stopA.name == stopB.name {
                    details.append(
                        "\(label) \(formatValue(valueA)) and \(formatValue(valueB)) both use “\(stopA.name)”"
                    )
                } else if stopA.elidable == stopB.elidable {
                    details.append(
                        "\(label) \(formatValue(valueA)) “\(stopA.name)” vs \(formatValue(valueB)) “\(stopB.name)”"
                    )
                } else {
                    let elided = stopA.elidable ? stopA : stopB
                    let visible = stopA.elidable ? stopB : stopA
                    details.append(
                        "\(label) elision differs for “\(visible.name)” vs elided “\(elided.name)” at \(formatValue(elided.value))"
                    )
                }
            }
        }

        let detailText = details.isEmpty
            ? "Instances differ but share the same naming contribution"
            : details.joined(separator: "; ")

        return PlanWarning(
            code: "duplicate_composed_name",
            axis: stopIDs.isEmpty ? nil : axisTag(forStopID: stopIDs[0], in: axes),
            name: composedName,
            keys: [priorKey, currentKey],
            stopIDs: stopIDs.isEmpty ? nil : Array(Set(stopIDs)),
            message: "Composed name “\(composedName)” appears more than once. \(detailText).",
            hint: "In the axis tree, rename a stop, adjust elision, remove a stop, or change a value."
        )
    }

    // MARK: - Private

    private static func axisTag(forStopID stopID: String, in axes: [AxisDefinition]) -> String? {
        axes.first { axis in axis.values.contains { $0.id == stopID } }?.tag
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
