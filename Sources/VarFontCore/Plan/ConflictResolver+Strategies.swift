import Foundation

extension ConflictResolver {
    public static func strategies(
        for bundle: AxisConflictBundle,
        axis: AxisDefinition
    ) -> [ConflictFixStrategy] {
        switch bundle.kind {
        case .duplicateValue:
            var strategies: [ConflictFixStrategy] = []
            if bundle.involvedStopIDs.count >= 2 {
                strategies.append(contentsOf: [.keepOneStop, .removeSelected, .revalueEach])
            }
            strategies.append(contentsOf: [.remove, .revalue])
            return strategies
        case .duplicateName:
            var strategies: [ConflictFixStrategy] = []
            if bundle.involvedStopIDs.count >= 2 {
                strategies.append(contentsOf: [.renameAllFromValues, .renameEach, .applyAllAxisDefaults])
            }
            if axis.role == .instance {
                strategies.append(contentsOf: [.rename, .remove, .setElidable])
            } else {
                strategies.append(contentsOf: [.rename, .remove])
            }
            return strategies
        case .duplicateValueAndName:
            var strategies: [ConflictFixStrategy] = [.remove, .revalueAndRename]
            if axis.role == .instance {
                strategies.append(.revalueAndSetElidable)
            }
            return strategies
        }
    }

    public static func strategyLabel(_ strategy: ConflictFixStrategy) -> String {
        switch strategy {
        case .remove: "Remove this stop"
        case .revalue: "Change value only"
        case .rename: "Rename only"
        case .setElidable: "Mark as elidable"
        case .revalueAndRename: "Change value and rename"
        case .revalueAndSetElidable: "Change value and mark as elidable"
        case .renameAllFromValues: "Rename stops from values"
        case .renameEach: "Name each stop"
        case .applyAllAxisDefaults: "Apply axis defaults"
        case .keepOneStop: "Keep one stop"
        case .removeSelected: "Remove selected stops"
        case .revalueEach: "Revalue each stop"
        }
    }

    public static func strategyDetail(
        strategy: ConflictFixStrategy,
        stop: AxisValue,
        axis: AxisDefinition,
        bundle: AxisConflictBundle? = nil
    ) -> String {
        let valueText = AxisStopSuggestions.formatValue(stop.value)
        switch strategy {
        case .remove:
            return "Remove “\(stop.name)” at \(valueText) from this axis."
        case .revalue:
            return "Moves this stop to a unique value. The duplicate name may still remain."
        case .rename:
            return "Gives this stop a unique name. The duplicate value may still remain."
        case .setElidable:
            return "When this is the default choice, composed names will leave out “\(stop.name)”."
        case .revalueAndRename:
            if let bundle, bundle.involvedStopIDs.count > 2 {
                return "Give this stop a unique value and name. Fix remaining stops in a follow-up step."
            }
            return "Give this stop a unique value and name so both conflicts are resolved."
        case .revalueAndSetElidable:
            return "Move this stop to a unique value and omit its name from composed names."
        case .renameAllFromValues:
            return "Rename every involved stop to its formatted coordinate value."
        case .renameEach:
            return "Edit the name for every involved stop in the table above."
        case .applyAllAxisDefaults:
            return "Elidable stop gets the axis default label; other stops get value-based names."
        case .keepOneStop:
            return "Keeps the selected stop and removes the others sharing this value."
        case .removeSelected:
            return "Removes the checked stops (at least one needs to stay)."
        case .revalueEach:
            return "Edit the coordinate for every involved stop in the table above."
        }
    }

    public static func suggestedRename(
        for stop: AxisValue,
        bundle: AxisConflictBundle,
        axis: AxisDefinition,
        assumingValue: Double? = nil
    ) -> String {
        var effective = stop
        if let assumingValue {
            effective.value = assumingValue
        }
        let peers = bundle.stops(from: axis).filter { $0.id != stop.id }
        let sameNamePeers = peers.filter { $0.name == effective.name }
        let valueText = AxisStopSuggestions.formatValue(effective.value)

        if sameNamePeers.contains(where: { AxisCoordinate.valuesEqual($0.value, effective.value) }) {
            if let label = axis.displayName?.split(separator: " ").first.map(String.init), !label.isEmpty {
                return "\(label) \(valueText)"
            }
            return "\(axis.tag.uppercased()) \(valueText)"
        }

        if !sameNamePeers.isEmpty {
            return valueText
        }

        return effective.name
    }

    public static func suggestedRevalue(
        for stop: AxisValue,
        axis: AxisDefinition,
        excludingStopIDs: Set<String>
    ) -> Double {
        AxisStopSuggestions.suggestedValue(
            for: axis,
            excludingStopIDs: excludingStopIDs.subtracting([stop.id])
        )
    }

    public static func suggestedBulkRenames(
        for bundle: AxisConflictBundle,
        axis: AxisDefinition
    ) -> [String: String] {
        let stops = bundle.stops(from: axis).sorted { $0.value < $1.value }
        var names: [String: String] = [:]
        for stop in stops {
            names[stop.id] = suggestedRename(for: stop, bundle: bundle, axis: axis)
        }
        return names
    }

    public static func validateBulkRenames(
        namesByStopID: [String: String],
        axis: AxisDefinition,
        involvedStopIDs: Set<String>
    ) -> String? {
        var finalNames: [String: String] = [:]
        for stopID in involvedStopIDs {
            guard let raw = namesByStopID[stopID] else { return "Name every stop." }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "Name is required for every stop." }
            finalNames[stopID] = trimmed
        }

        if Set(finalNames.values).count != finalNames.count {
            return "Names must be unique among involved stops."
        }

        let outsideNames = Set(
            axis.values.filter { !involvedStopIDs.contains($0.id) }.map(\.name)
        )
        for name in finalNames.values where outsideNames.contains(name) {
            return "Another stop already uses “\(name)”."
        }
        return nil
    }

    public static func bulkRenameAction(
        namesByStopID: [String: String],
        axis: AxisDefinition,
        involvedStopIDs: Set<String>
    ) -> ConflictFixAction? {
        guard validateBulkRenames(
            namesByStopID: namesByStopID,
            axis: axis,
            involvedStopIDs: involvedStopIDs
        ) == nil else {
            return nil
        }

        let involved = axis.values.filter { involvedStopIDs.contains($0.id) }
        let actions = involved.compactMap { stop -> ConflictFixAction? in
            guard let raw = namesByStopID[stop.id] else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, stop.name != trimmed else { return nil }
            return .renameStop(stopID: stop.id, newName: trimmed)
        }

        if actions.isEmpty {
            return nil
        }
        return actions.count == 1 ? actions[0] : .compound(actions)
    }

    public static func preferredKeepStop(in stops: [AxisValue]) -> AxisValue? {
        if let elidable = stops.first(where: \.elidable) {
            return elidable
        }
        return stops.first
    }

    public static func suggestedBulkRevalues(
        for bundle: AxisConflictBundle,
        axis: AxisDefinition
    ) -> [String: String] {
        let stops = bundle.stops(from: axis).sorted { $0.value < $1.value }
        let involvedIDs = Set(bundle.involvedStopIDs)
        var assignedValues = axis.values
            .filter { !involvedIDs.contains($0.id) }
            .map(\.value)
        var values: [String: String] = [:]
        for stop in stops {
            let value = AxisStopSuggestions.suggestedValue(
                for: axis,
                excludingStopIDs: involvedIDs.subtracting([stop.id]),
                excludingValues: assignedValues
            )
            assignedValues.append(value)
            values[stop.id] = AxisStopSuggestions.formatValue(value)
        }
        return values
    }

    public static func validateBulkRevalues(
        valuesByStopID: [String: String],
        axis: AxisDefinition,
        involvedStopIDs: Set<String>
    ) -> String? {
        var finalValues: [Double] = []
        for stopID in involvedStopIDs {
            guard let raw = valuesByStopID[stopID] else { return "Set a value for every stop." }
            guard let value = parseValue(raw) else { return "Enter a valid number for every stop." }
            if let min = axis.min, value < min {
                return "Value must be at least \(AxisStopSuggestions.formatValue(min))."
            }
            if let max = axis.max, value > max {
                return "Value must be at most \(AxisStopSuggestions.formatValue(max))."
            }
            finalValues.append(value)
        }

        for index in finalValues.indices {
            for other in finalValues.indices where other > index {
                if AxisCoordinate.valuesEqual(finalValues[index], finalValues[other]) {
                    return "Values must be unique among involved stops."
                }
            }
        }

        let outsideValues = axis.values
            .filter { !involvedStopIDs.contains($0.id) }
            .map(\.value)
        for value in finalValues where outsideValues.contains(where: { AxisCoordinate.valuesEqual($0, value) }) {
            return "Another stop already uses this value."
        }
        return nil
    }

    public static func keepOneStopAction(
        keepStopID: String,
        involvedStopIDs: Set<String>
    ) -> ConflictFixAction? {
        let removeIDs = involvedStopIDs.subtracting([keepStopID])
        guard involvedStopIDs.contains(keepStopID), !removeIDs.isEmpty else { return nil }
        let actions = removeIDs.sorted().map { ConflictFixAction.removeStop(stopID: $0) }
        return actions.count == 1 ? actions[0] : .compound(actions)
    }

    public static func removeSelectedAction(
        selectedStopIDs: Set<String>,
        involvedStopIDs: Set<String>
    ) -> ConflictFixAction? {
        let toRemove = selectedStopIDs.intersection(involvedStopIDs)
        guard !toRemove.isEmpty else { return nil }
        guard involvedStopIDs.subtracting(toRemove).isEmpty == false else {
            return nil
        }
        let actions = toRemove.sorted().map { ConflictFixAction.removeStop(stopID: $0) }
        return actions.count == 1 ? actions[0] : .compound(actions)
    }

    public static func bulkRevalueAction(
        valuesByStopID: [String: String],
        axis: AxisDefinition,
        involvedStopIDs: Set<String>
    ) -> ConflictFixAction? {
        guard validateBulkRevalues(
            valuesByStopID: valuesByStopID,
            axis: axis,
            involvedStopIDs: involvedStopIDs
        ) == nil else {
            return nil
        }

        let involved = axis.values.filter { involvedStopIDs.contains($0.id) }
        let actions = involved.compactMap { stop -> ConflictFixAction? in
            guard let raw = valuesByStopID[stop.id], let value = parseValue(raw) else { return nil }
            guard !AxisCoordinate.valuesEqual(stop.value, value) else { return nil }
            return .revalueStop(stopID: stop.id, newValue: value)
        }

        if actions.isEmpty { return nil }
        return actions.count == 1 ? actions[0] : .compound(actions)
    }

    public static func validateRemoveSelected(
        selectedStopIDs: Set<String>,
        involvedStopIDs: Set<String>
    ) -> String? {
        let toRemove = selectedStopIDs.intersection(involvedStopIDs)
        if toRemove.isEmpty { return "Select at least one stop to remove." }
        if involvedStopIDs.subtracting(toRemove).isEmpty {
            return "At least one stop must remain on this axis."
        }
        return nil
    }

    public static func resolvedAction(
        strategy: ConflictFixStrategy,
        stop: AxisValue,
        bundle: AxisConflictBundle,
        axis: AxisDefinition,
        renameText: String,
        revalueText: String,
        bulkRenameNames: [String: String]? = nil,
        bulkRevalueTexts: [String: String]? = nil,
        keepStopID: String? = nil,
        removalStopIDs: Set<String>? = nil
    ) -> ConflictFixAction? {
        switch strategy {
        case .remove:
            return .removeStop(stopID: stop.id)
        case .revalue, .revalueAndRename, .revalueAndSetElidable:
            guard let value = resolvedRevalue(
                text: revalueText,
                for: stop,
                axis: axis,
                excludingStopIDs: Set(bundle.involvedStopIDs)
            ) else {
                return nil
            }
            guard validateRevalue(value, for: stop, axis: axis, excludingStopIDs: Set(bundle.involvedStopIDs)) == nil else {
                return nil
            }
            switch strategy {
            case .revalue:
                return .revalueStop(stopID: stop.id, newValue: value)
            case .revalueAndRename:
                guard let name = resolvedRename(
                    text: renameText,
                    for: stop,
                    bundle: bundle,
                    axis: axis,
                    assumingValue: value
                ) else {
                    return nil
                }
                guard validateRename(name, for: stop, axis: axis) == nil else { return nil }
                return .compound([
                    .revalueStop(stopID: stop.id, newValue: value),
                    .renameStop(stopID: stop.id, newName: name),
                ])
            case .revalueAndSetElidable:
                return .compound([
                    .revalueStop(stopID: stop.id, newValue: value),
                    .setElidable(stopID: stop.id, elidable: true),
                ])
            default:
                return nil
            }
        case .rename:
            guard let resolved = resolvedRename(
                text: renameText,
                for: stop,
                bundle: bundle,
                axis: axis
            ) else {
                return nil
            }
            guard validateRename(resolved, for: stop, axis: axis) == nil else { return nil }
            return .renameStop(stopID: stop.id, newName: resolved)
        case .setElidable:
            return .setElidable(stopID: stop.id, elidable: true)
        case .renameAllFromValues:
            let involved = bundle.stops(from: axis).filter { bundle.involvedStopIDs.contains($0.id) }
            return AxisStopNamingDefaults.bulkRenameFromValues(stops: involved)
        case .renameEach:
            guard let bulkRenameNames else { return nil }
            return bulkRenameAction(
                namesByStopID: bulkRenameNames,
                axis: axis,
                involvedStopIDs: Set(bundle.involvedStopIDs)
            )
        case .applyAllAxisDefaults:
            return AxisStopNamingDefaults.bulkApplyDefaults(axis: axis, stopIDs: bundle.involvedStopIDs)
        case .keepOneStop:
            guard let keepStopID else { return nil }
            return keepOneStopAction(
                keepStopID: keepStopID,
                involvedStopIDs: Set(bundle.involvedStopIDs)
            )
        case .removeSelected:
            guard let removalStopIDs else { return nil }
            return removeSelectedAction(
                selectedStopIDs: removalStopIDs,
                involvedStopIDs: Set(bundle.involvedStopIDs)
            )
        case .revalueEach:
            guard let bulkRevalueTexts else { return nil }
            return bulkRevalueAction(
                valuesByStopID: bulkRevalueTexts,
                axis: axis,
                involvedStopIDs: Set(bundle.involvedStopIDs)
            )
        }
    }

    private static func resolvedRevalue(
        text: String,
        for stop: AxisValue,
        axis: AxisDefinition,
        excludingStopIDs: Set<String>
    ) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return suggestedRevalue(for: stop, axis: axis, excludingStopIDs: excludingStopIDs)
        }
        return parseValue(trimmed)
    }

    private static func resolvedRename(
        text: String,
        for stop: AxisValue,
        bundle: AxisConflictBundle,
        axis: AxisDefinition,
        assumingValue: Double? = nil
    ) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return suggestedRename(
                for: stop,
                bundle: bundle,
                axis: axis,
                assumingValue: assumingValue
            )
        }
        return trimmed
    }
}
