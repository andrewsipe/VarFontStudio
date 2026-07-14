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
