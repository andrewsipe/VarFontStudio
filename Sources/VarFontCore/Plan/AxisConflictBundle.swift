import Foundation

public enum AxisConflictKind: String, Codable, Equatable, Sendable {
    case duplicateValue = "duplicate_value"
    case duplicateName = "duplicate_name"
    case duplicateValueAndName = "duplicate_value_and_name"
}

public struct AxisConflictGroup: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var duplicateValue: Double?
    public var duplicateName: String?
    public var stopIDs: [String]

    public init(
        id: String,
        duplicateValue: Double? = nil,
        duplicateName: String? = nil,
        stopIDs: [String]
    ) {
        self.id = id
        self.duplicateValue = duplicateValue
        self.duplicateName = duplicateName
        self.stopIDs = stopIDs
    }
}

public struct AxisConflictBundle: Codable, Equatable, Sendable, Identifiable {
    public var axisTag: String
    public var axisLabel: String
    public var kind: AxisConflictKind
    public var groups: [AxisConflictGroup]
    public var involvedStopIDs: [String]
    public var symptomSummary: String?

    public var id: String { axisTag }

    public init(
        axisTag: String,
        axisLabel: String,
        kind: AxisConflictKind,
        groups: [AxisConflictGroup],
        involvedStopIDs: [String],
        symptomSummary: String? = nil
    ) {
        self.axisTag = axisTag
        self.axisLabel = axisLabel
        self.kind = kind
        self.groups = groups
        self.involvedStopIDs = involvedStopIDs
        self.symptomSummary = symptomSummary
    }

    public func stops(from axis: AxisDefinition) -> [AxisValue] {
        let idSet = Set(involvedStopIDs)
        return axis.values.filter { idSet.contains($0.id) }
    }
}
