import Foundation

public enum InstancePlanner {
    public struct Options: Sendable {
        public var detectDuplicates: Bool

        public init(detectDuplicates: Bool = true) {
            self.detectDuplicates = detectDuplicates
        }
    }

    public static func plan(
        font: FontDocument,
        naming: NamingPolicy,
        options: Options = Options()
    ) -> InstancePlan {
        let gridAxes = font.axes.filter { $0.role == .instance }
        let formulaParts = gridAxes.map(\.values.count)
        let generated = cartesianProduct(gridAxes: gridAxes)
        let excluded = Set(font.excludedInstanceKeys)
        let includedWhitelist = Set(font.includedInstanceKeys)

        var warnings = validateAxes(font.axes)
        warnings.append(contentsOf: AxisStopValidator.validate(axes: font.axes))
        warnings.append(contentsOf: validateInstanceKeySets(font))
        var instances: [PlannedInstance] = []
        var seenNames: [String: String] = [:]

        let pinned = pinnedCoords(from: font.axes)

        for var coords in generated {
            for (tag, value) in pinned where coords[tag] == nil {
                coords[tag] = value
            }
            let key = InstanceKeyBuilder.makeKey(coords: coords)
            let composed = NamingComposer.compose(coords: coords, axes: font.axes, naming: naming)
            let chain = composed.chain
                .filter { link in
                    font.axes.first(where: { $0.tag == link.tag })?.role == .instance
                }
                .map {
                    NamingChainLink(tag: $0.tag, name: $0.name, elided: $0.elided)
                }

            let included: Bool
            if !includedWhitelist.isEmpty {
                included = includedWhitelist.contains(key)
            } else {
                included = !excluded.contains(key)
            }

            var duplicate = false
            if options.detectDuplicates, let priorKey = seenNames[composed.name] {
                duplicate = true
                let priorCoords = instances.first { $0.key == priorKey }?.coords ?? [:]
                warnings.append(
                    NamingConflictAnalyzer.composedNameDuplicateWarning(
                        composedName: composed.name,
                        priorKey: priorKey,
                        priorCoords: priorCoords,
                        currentKey: key,
                        currentCoords: coords,
                        axes: font.axes,
                        naming: naming
                    )
                )
            } else {
                seenNames[composed.name] = key
            }

            instances.append(
                PlannedInstance(
                    key: key,
                    composedName: composed.name,
                    coords: coords,
                    included: included,
                    duplicate: duplicate,
                    namingChain: chain
                )
            )
        }

        markAllDuplicateComposedNames(in: &instances)

        let totalGenerated = instances.count
        let totalIncluded = instances.filter(\.included).count

        return InstancePlan(
            schemaVersion: 1,
            fontID: font.id,
            formula: PlanFormula(
                parts: formulaParts,
                totalGenerated: totalGenerated,
                totalIncluded: totalIncluded,
                totalExcluded: totalGenerated - totalIncluded
            ),
            instances: instances,
            warnings: warnings,
            namePlanSummary: nil
        )
    }

    public static func plan(project: ProjectDocument, fontID: String, options: Options = Options()) -> InstancePlan? {
        guard let font = project.fonts.first(where: { $0.id == fontID }) else { return nil }
        return plan(font: font, naming: project.naming, options: options)
    }

    // MARK: - Private

    private static func cartesianProduct(gridAxes: [AxisDefinition]) -> [[String: Double]] {
        guard !gridAxes.isEmpty else { return [] }
        var results: [[String: Double]] = [ [:] ]
        for axis in gridAxes {
            var next: [[String: Double]] = []
            for partial in results {
                for stop in axis.values {
                    var coords = partial
                    coords[axis.tag] = stop.value
                    next.append(coords)
                }
            }
            results = next
        }
        return results
    }

    private static func pinnedCoords(from axes: [AxisDefinition]) -> [String: Double] {
        var pinned: [String: Double] = [:]
        for axis in axes where axis.role != .instance {
            if axis.values.count == 1, let value = axis.values.first?.value {
                pinned[axis.tag] = value
            } else if let defaultValue = axis.default {
                pinned[axis.tag] = defaultValue
            } else if let first = axis.values.first?.value {
                pinned[axis.tag] = first
            }
        }
        return pinned
    }

    private static func validateAxes(_ axes: [AxisDefinition]) -> [PlanWarning] {
        var warnings: [PlanWarning] = []
        for axis in axes {
            let elidable = axis.values.filter(\.elidable)
            if elidable.count > 1 {
                warnings.append(
                    PlanWarning(
                        code: "multiple_elidable",
                        axis: axis.tag,
                        stopIDs: elidable.map(\.id),
                        message: "Axis '\(axis.tag)' has \(elidable.count) elidable stops; at most one is allowed.",
                        hint: "Clear elision on all but one stop for this axis."
                    )
                )
            }
            if axis.role == .instance, axis.values.isEmpty {
                warnings.append(
                    PlanWarning(
                        code: "empty_instance_axis",
                        axis: axis.tag,
                        message: "Instance axis '\(axis.tag)' has no stops.",
                        hint: "Add at least one stop or turn off instance axis for this axis."
                    )
                )
            }
        }
        return warnings
    }

    private static func markAllDuplicateComposedNames(in instances: inout [PlannedInstance]) {
        var counts: [String: Int] = [:]
        for instance in instances {
            counts[instance.composedName, default: 0] += 1
        }
        for index in instances.indices {
            if counts[instances[index].composedName, default: 0] > 1 {
                instances[index].duplicate = true
            }
        }
    }

    private static func validateInstanceKeySets(_ font: FontDocument) -> [PlanWarning] {
        let overlap = Set(font.includedInstanceKeys).intersection(font.excludedInstanceKeys)
        guard !overlap.isEmpty else { return [] }
        return [
            PlanWarning(
                code: "conflicting_instance_keys",
                axis: nil,
                name: nil,
                keys: Array(overlap).sorted(),
                message: "\(overlap.count) instance key(s) appear in both included and excluded lists."
            ),
        ]
    }
}
