import Foundation

public enum ConflictFixAction: Equatable, Sendable {
    case removeStop(stopID: String)
    case revalueStop(stopID: String, newValue: Double)
    case renameStop(stopID: String, newName: String)
    case setElidable(stopID: String, elidable: Bool)
    case compound([ConflictFixAction])
}

public struct ConflictResolutionProposal: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var action: ConflictFixAction
    public var keepStopID: String?

    public init(
        id: String,
        title: String,
        detail: String,
        action: ConflictFixAction,
        keepStopID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.action = action
        self.keepStopID = keepStopID
    }
}

public struct ConflictFixPreview: Equatable, Sendable {
    public var totalInstances: Int
    public var duplicateInstanceCount: Int
    public var remainingAxisConflicts: Int
    public var sampleComposedNames: [String]
    public var resolvesConflict: Bool

    public init(
        totalInstances: Int,
        duplicateInstanceCount: Int,
        remainingAxisConflicts: Int,
        sampleComposedNames: [String],
        resolvesConflict: Bool
    ) {
        self.totalInstances = totalInstances
        self.duplicateInstanceCount = duplicateInstanceCount
        self.remainingAxisConflicts = remainingAxisConflicts
        self.sampleComposedNames = sampleComposedNames
        self.resolvesConflict = resolvesConflict
    }
}

public enum ConflictFixStrategy: String, CaseIterable, Sendable, Identifiable {
    case remove
    case revalue
    case rename
    case setElidable
    case revalueAndRename
    case revalueAndSetElidable
    case renameAllFromValues
    case renameEach
    case applyAllAxisDefaults
    case keepOneStop
    case removeSelected
    case revalueEach

    public var id: String { rawValue }
}

public struct ConflictStopOutcome: Equatable, Sendable, Identifiable {
    public var stopID: String
    public var valueBefore: Double
    public var nameBefore: String
    public var elidableBefore: Bool
    public var valueAfter: Double?
    public var nameAfter: String?
    public var elidableAfter: Bool?
    public var isRemoved: Bool
    public var isTarget: Bool

    public var id: String { stopID }

    public init(
        stopID: String,
        valueBefore: Double,
        nameBefore: String,
        elidableBefore: Bool,
        valueAfter: Double?,
        nameAfter: String?,
        elidableAfter: Bool?,
        isRemoved: Bool,
        isTarget: Bool
    ) {
        self.stopID = stopID
        self.valueBefore = valueBefore
        self.nameBefore = nameBefore
        self.elidableBefore = elidableBefore
        self.valueAfter = valueAfter
        self.nameAfter = nameAfter
        self.elidableAfter = elidableAfter
        self.isRemoved = isRemoved
        self.isTarget = isTarget
    }
}

public enum ConflictResolver {
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

    public static func proposals(
        for bundle: AxisConflictBundle,
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let involved = bundle.stops(from: axis)
        guard involved.count >= 2 else { return [] }

        switch bundle.kind {
        case .duplicateValue:
            return duplicateValueProposals(involved: involved, axis: axis)
        case .duplicateName:
            return duplicateNameProposals(involved: involved, axis: axis)
        case .duplicateValueAndName:
            return duplicateValueAndNameProposals(involved: involved, axis: axis)
        }
    }

    public static func previewPlan(
        font: FontDocument,
        naming: NamingPolicy,
        bundle: AxisConflictBundle,
        applying action: ConflictFixAction
    ) -> ConflictFixPreview {
        var mutatedFont = font
        apply(action, axisTag: bundle.axisTag, to: &mutatedFont)

        let plan = InstancePlanner.plan(font: mutatedFont, naming: naming)
        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: mutatedFont.axes,
            namingOrder: naming.order
        )
        let remaining = bundles.filter { $0.axisTag == bundle.axisTag }.count
        let duplicateCount = plan.instances.filter(\.duplicate).count
        let samples = plan.instances.prefix(3).map(\.composedName)

        return ConflictFixPreview(
            totalInstances: plan.instances.count,
            duplicateInstanceCount: duplicateCount,
            remainingAxisConflicts: remaining,
            sampleComposedNames: Array(samples),
            resolvesConflict: remaining == 0
        )
    }

    public static func symptomSummary(
        for bundle: AxisConflictBundle,
        font: FontDocument,
        naming: NamingPolicy
    ) -> String {
        let plan = InstancePlanner.plan(font: font, naming: naming)
        let duplicateCount = plan.instances.filter(\.duplicate).count
        if duplicateCount > 0 {
            return "\(duplicateCount) instance\(duplicateCount == 1 ? "" : "s") share composed names"
        }
        switch bundle.kind {
        case .duplicateValue:
            return "Duplicate values on this axis expand the instance grid"
        case .duplicateName:
            return "Duplicate stop names can produce identical composed names"
        case .duplicateValueAndName:
            return "Duplicate values and names on this axis affect instance naming"
        }
    }

    public static func apply(
        _ action: ConflictFixAction,
        axisTag: String,
        to font: inout FontDocument
    ) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }) else { return }

        switch action {
        case let .removeStop(stopID):
            font.axes[axisIndex].values.removeAll { $0.id == stopID }

        case let .revalueStop(stopID, newValue):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            var clamped = newValue
            let axis = font.axes[axisIndex]
            if let min = axis.min { clamped = max(clamped, min) }
            if let max = axis.max { clamped = min(clamped, max) }
            font.axes[axisIndex].values[stopIndex].value = clamped
            font.axes[axisIndex].values.sort { $0.value < $1.value }

        case let .renameStop(stopID, newName):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            font.axes[axisIndex].values[stopIndex].name = newName

        case let .setElidable(stopID, elidable):
            guard let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else {
                return
            }
            if elidable {
                for index in font.axes[axisIndex].values.indices {
                    font.axes[axisIndex].values[index].elidable =
                        font.axes[axisIndex].values[index].id == stopID
                }
            } else {
                font.axes[axisIndex].values[stopIndex].elidable = false
            }

        case let .compound(actions):
            for step in actions {
                apply(step, axisTag: axisTag, to: &font)
            }
        }
    }

    // MARK: - Proposal builders

    private static func targetStopID(for action: ConflictFixAction) -> String {
        switch action {
        case let .removeStop(stopID),
             let .revalueStop(stopID, _),
             let .renameStop(stopID, _),
             let .setElidable(stopID, _):
            return stopID
        case let .compound(actions):
            return actions.compactMap { targetStopID(for: $0) }.first ?? ""
        }
    }

    private static func duplicateValueProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let sorted = involved.sorted { $0.value < $1.value }
        guard let keep = preferredKeepStop(in: sorted),
              let remove = sorted.first(where: { $0.id != keep.id }) else {
            return []
        }

        var proposals: [ConflictResolutionProposal] = [
            ConflictResolutionProposal(
                id: "remove-\(remove.id)",
                title: "Remove “\(remove.name)”",
                detail: "Keep “\(keep.name)” at \(AxisStopSuggestions.formatValue(keep.value)) and remove the duplicate stop.",
                action: .removeStop(stopID: remove.id),
                keepStopID: keep.id
            ),
        ]

        let suggested = AxisStopSuggestions.suggestedValue(
            for: axis,
            excludingStopIDs: Set(sorted.map(\.id).filter { $0 != remove.id })
        )
        proposals.append(
            ConflictResolutionProposal(
                id: "revalue-\(remove.id)",
                title: "Change “\(remove.name)” to \(AxisStopSuggestions.formatValue(suggested))",
                detail: "Keep both stops with unique values.",
                action: .revalueStop(stopID: remove.id, newValue: suggested),
                keepStopID: keep.id
            )
        )

        return proposals
    }

    private static func duplicateNameProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        let sorted = involved.sorted { $0.value < $1.value }
        guard let keep = preferredKeepStop(in: sorted),
              let rename = sorted.first(where: { $0.id != keep.id }) else {
            return []
        }

        let newName = "\(rename.name) (\(AxisStopSuggestions.formatValue(rename.value)))"
        var proposals: [ConflictResolutionProposal] = [
            ConflictResolutionProposal(
                id: "rename-\(rename.id)",
                title: "Rename “\(rename.name)” to “\(newName)”",
                detail: "Keep both stops; distinguish names by value.",
                action: .renameStop(stopID: rename.id, newName: newName),
                keepStopID: keep.id
            ),
            ConflictResolutionProposal(
                id: "remove-\(rename.id)",
                title: "Remove “\(rename.name)” at \(AxisStopSuggestions.formatValue(rename.value))",
                detail: "Keep “\(keep.name)” at \(AxisStopSuggestions.formatValue(keep.value)).",
                action: .removeStop(stopID: rename.id),
                keepStopID: keep.id
            ),
        ]

        if axis.role == .instance {
            proposals.append(
                ConflictResolutionProposal(
                    id: "elide-\(keep.id)",
                    title: "Mark “\(keep.name)” as elidable",
                    detail: "Only one stop contributes “\(keep.name)” to composed instance names.",
                    action: .setElidable(stopID: keep.id, elidable: true),
                    keepStopID: keep.id
                )
            )
        }

        return proposals
    }

    private static func duplicateValueAndNameProposals(
        involved: [AxisValue],
        axis: AxisDefinition
    ) -> [ConflictResolutionProposal] {
        var proposals = duplicateValueProposals(involved: involved, axis: axis)
        let sorted = involved.sorted { $0.value < $1.value }
        if let remove = sorted.last,
           proposals.contains(where: {
               if case let .removeStop(id) = $0.action { return id == remove.id }
               return false
           }) == false {
            proposals.insert(
                ConflictResolutionProposal(
                    id: "remove-redundant-\(remove.id)",
                    title: "Remove redundant stop “\(remove.name)”",
                    detail: "Same value and name as another stop on this axis.",
                    action: .removeStop(stopID: remove.id),
                    keepStopID: sorted.first?.id
                ),
                at: 0
            )
        }
        return proposals
    }
}
