import Foundation

// MARK: - Commit

public struct CommitRequest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var requestID: String
    public var sourcePath: String
    public var outputPath: String
    public var dryRun: Bool
    public var options: CommitOptions
    public var naming: NamingPolicy
    public var fileRole: FileRole?
    public var axes: [AxisDefinition]
    public var includedInstanceKeys: [String]
    public var fileStatRegistration: [String: Double]
    public var compoundStatValues: [CompoundStatValue]
    public var statDesignAxisTags: [String]
    public var originalSourcePath: String?
    public var allowInPlace: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case requestID = "request_id"
        case sourcePath = "source_path"
        case outputPath = "output_path"
        case dryRun = "dry_run"
        case options, naming
        case fileRole = "file_role"
        case axes
        case includedInstanceKeys = "included_instance_keys"
        case fileStatRegistration = "file_stat_registration"
        case compoundStatValues = "compound_stat_values"
        case statDesignAxisTags = "stat_design_axis_tags"
        case originalSourcePath = "original_source_path"
        case allowInPlace = "allow_in_place"
    }

    public init(
        schemaVersion: Int,
        requestID: String,
        sourcePath: String,
        outputPath: String,
        dryRun: Bool,
        options: CommitOptions,
        naming: NamingPolicy,
        fileRole: FileRole? = nil,
        axes: [AxisDefinition],
        includedInstanceKeys: [String] = [],
        fileStatRegistration: [String: Double] = [:],
        compoundStatValues: [CompoundStatValue] = [],
        statDesignAxisTags: [String] = [],
        originalSourcePath: String? = nil,
        allowInPlace: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.sourcePath = sourcePath
        self.outputPath = outputPath
        self.dryRun = dryRun
        self.options = options
        self.naming = naming
        self.fileRole = fileRole
        self.axes = axes
        self.includedInstanceKeys = includedInstanceKeys
        self.fileStatRegistration = fileStatRegistration
        self.compoundStatValues = compoundStatValues
        self.statDesignAxisTags = statDesignAxisTags
        self.originalSourcePath = originalSourcePath
        self.allowInPlace = allowInPlace
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        requestID = try c.decode(String.self, forKey: .requestID)
        sourcePath = try c.decode(String.self, forKey: .sourcePath)
        outputPath = try c.decode(String.self, forKey: .outputPath)
        dryRun = try c.decode(Bool.self, forKey: .dryRun)
        options = try c.decode(CommitOptions.self, forKey: .options)
        naming = try c.decode(NamingPolicy.self, forKey: .naming)
        fileRole = try c.decodeIfPresent(FileRole.self, forKey: .fileRole)
        axes = try c.decode([AxisDefinition].self, forKey: .axes)
        includedInstanceKeys = try c.decodeIfPresent([String].self, forKey: .includedInstanceKeys) ?? []
        fileStatRegistration = try c.decodeIfPresent([String: Double].self, forKey: .fileStatRegistration) ?? [:]
        compoundStatValues = try c.decodeIfPresent([CompoundStatValue].self, forKey: .compoundStatValues) ?? []
        statDesignAxisTags = try c.decodeIfPresent([String].self, forKey: .statDesignAxisTags) ?? []
        originalSourcePath = try c.decodeIfPresent(String.self, forKey: .originalSourcePath)
        allowInPlace = try c.decodeIfPresent(Bool.self, forKey: .allowInPlace) ?? false
    }
}

public struct CommitResult: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var requestID: String
    public var ok: Bool
    public var outputPath: String?
    public var dryRun: Bool
    public var summary: CommitSummary?
    public var diff: CommitDiff?
    public var validation: CommitValidation?
    public var warnings: [PlanWarning]
    public var errors: [CommitError]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case requestID = "request_id"
        case ok
        case outputPath = "output_path"
        case dryRun = "dry_run"
        case summary, diff, validation, warnings, errors
    }
}

public struct CommitValidation: Codable, Equatable, Sendable {
    public var ok: Bool
    public var issueCount: Int
    public var issues: [CommitValidationIssue]

    enum CodingKeys: String, CodingKey {
        case ok
        case issueCount = "issue_count"
        case issues
    }
}

public struct CommitValidationIssue: Codable, Equatable, Sendable {
    public var code: String
    public var severity: String
    public var message: String
}

public struct CommitDiffOTReflowEntry: Codable, Equatable, Sendable {
    public var fromID: Int
    public var toID: Int
    public var string: String?
    public var feature: String?

    enum CodingKeys: String, CodingKey {
        case fromID = "from"
        case toID = "to"
        case string
        case feature
    }
}

public struct CommitDiff: Codable, Equatable, Sendable {
    public var familyPSPrefix: String?
    public var elidedFallbackName: String?
    public var elidedFallbackID: Int?
    public var nameIDRange: [Int]?
    public var nameRecordsPlanned: [CommitNameRecordPlanned]
    /// Write-order name records (axis → stat → elided → instances). Prefer for Save Review sequencing.
    public var nameRecordsSequenced: [CommitNameRecordPlanned]
    public var statValuesPlanned: [CommitDiffStatValuePlanned]
    public var instancesPlanned: [CommitDiffInstancePlanned]
    public var otReflowMapping: [CommitDiffOTReflowEntry]?

    enum CodingKeys: String, CodingKey {
        case familyPSPrefix = "family_ps_prefix"
        case elidedFallbackName = "elided_fallback_name"
        case elidedFallbackID = "elided_fallback_id"
        case nameIDRange = "name_id_range"
        case nameRecordsPlanned = "name_records_planned"
        case nameRecordsSequenced = "name_records_sequenced"
        case statValuesPlanned = "stat_values_planned"
        case instancesPlanned = "instances_planned"
        case otReflowMapping = "ot_reflow_mapping"
    }

    public init(
        familyPSPrefix: String? = nil,
        elidedFallbackName: String? = nil,
        elidedFallbackID: Int? = nil,
        nameIDRange: [Int]? = nil,
        nameRecordsPlanned: [CommitNameRecordPlanned] = [],
        nameRecordsSequenced: [CommitNameRecordPlanned] = [],
        statValuesPlanned: [CommitDiffStatValuePlanned] = [],
        instancesPlanned: [CommitDiffInstancePlanned] = [],
        otReflowMapping: [CommitDiffOTReflowEntry]? = nil
    ) {
        self.familyPSPrefix = familyPSPrefix
        self.elidedFallbackName = elidedFallbackName
        self.elidedFallbackID = elidedFallbackID
        self.nameIDRange = nameIDRange
        self.nameRecordsPlanned = nameRecordsPlanned
        self.nameRecordsSequenced = nameRecordsSequenced.isEmpty ? nameRecordsPlanned : nameRecordsSequenced
        self.statValuesPlanned = statValuesPlanned
        self.instancesPlanned = instancesPlanned
        self.otReflowMapping = otReflowMapping
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        familyPSPrefix = try c.decodeIfPresent(String.self, forKey: .familyPSPrefix)
        elidedFallbackName = try c.decodeIfPresent(String.self, forKey: .elidedFallbackName)
        elidedFallbackID = try c.decodeIfPresent(Int.self, forKey: .elidedFallbackID)
        nameIDRange = try c.decodeIfPresent([Int].self, forKey: .nameIDRange)
        nameRecordsPlanned = try c.decodeIfPresent([CommitNameRecordPlanned].self, forKey: .nameRecordsPlanned) ?? []
        nameRecordsSequenced = try c.decodeIfPresent([CommitNameRecordPlanned].self, forKey: .nameRecordsSequenced)
            ?? nameRecordsPlanned
        statValuesPlanned = try c.decodeIfPresent([CommitDiffStatValuePlanned].self, forKey: .statValuesPlanned) ?? []
        instancesPlanned = try c.decodeIfPresent([CommitDiffInstancePlanned].self, forKey: .instancesPlanned) ?? []
        otReflowMapping = try c.decodeIfPresent([CommitDiffOTReflowEntry].self, forKey: .otReflowMapping)
    }
}

public struct CommitNameRecordPlanned: Codable, Equatable, Sendable {
    public var id: Int
    public var string: String
    public var role: String
}

public struct CommitDiffStatValuePlanned: Codable, Equatable, Sendable {
    public var tag: String
    public var value: Double
    public var name: String
    public var elidable: Bool
    public var statFormat: Int
    public var nameID: Int?
    public var linkedValue: Double?
    public var rangeMin: Double?
    public var rangeMax: Double?

    enum CodingKeys: String, CodingKey {
        case tag, value, name, elidable
        case statFormat = "stat_format"
        case nameID = "name_id"
        case linkedValue = "linked_value"
        case rangeMin = "range_min"
        case rangeMax = "range_max"
    }
}

public struct CommitDiffInstancePlanned: Codable, Equatable, Sendable {
    public var composedName: String
    public var subfamilyNameID: Int
    public var postscriptName: String?
    public var postscriptNameID: Int?

    enum CodingKeys: String, CodingKey {
        case composedName = "composed_name"
        case subfamilyNameID = "subfamily_name_id"
        case postscriptName = "postscript_name"
        case postscriptNameID = "postscript_name_id"
    }
}

public enum CommitDiffChangeKind: String, Codable, Equatable, Sendable {
    case added
    case removed
    case changed
    case unchanged
}

public struct CommitDiffStatRow: Codable, Equatable, Sendable, Identifiable {
    public var tag: String
    public var value: Double
    public var beforeName: String?
    public var afterName: String?
    public var beforeNameID: Int?
    public var afterNameID: Int?
    public var afterStatFormat: Int?
    public var afterLinkedValue: Double?
    public var change: CommitDiffChangeKind

    public var id: String { "\(tag):\(value)" }

    enum CodingKeys: String, CodingKey {
        case tag, value, beforeName, afterName, beforeNameID, afterNameID, change
        case afterStatFormat = "after_stat_format"
        case afterLinkedValue = "after_linked_value"
    }
}

public struct CommitDiffInstanceRow: Codable, Equatable, Sendable, Identifiable {
    public var key: String
    public var beforeName: String?
    public var afterName: String?
    public var beforePostscriptName: String?
    public var afterPostscriptName: String?
    public var coords: [String: Double]?
    public var change: CommitDiffChangeKind
    public var postscriptChange: CommitDiffChangeKind

    public var id: String { key }

    public init(
        key: String,
        beforeName: String? = nil,
        afterName: String? = nil,
        beforePostscriptName: String? = nil,
        afterPostscriptName: String? = nil,
        coords: [String: Double]? = nil,
        change: CommitDiffChangeKind,
        postscriptChange: CommitDiffChangeKind = .unchanged
    ) {
        self.key = key
        self.beforeName = beforeName
        self.afterName = afterName
        self.beforePostscriptName = beforePostscriptName
        self.afterPostscriptName = afterPostscriptName
        self.coords = coords
        self.change = change
        self.postscriptChange = postscriptChange
    }
}

public struct CommitDiffNameIDRow: Codable, Equatable, Sendable, Identifiable {
    /// Name table slot (≥256).
    public var id: Int
    public var beforeDescription: String?
    public var beforeString: String?
    public var afterString: String?
    public var afterRole: String?
    public var change: CommitDiffChangeKind
    /// Prior slot when the same string moved to this name ID.
    public var reflowedFromNameID: Int?
    /// Hidden from Save Review when consumed as reflow source/target pair.
    public var reflowSuppressed: Bool

    public init(
        id: Int,
        beforeDescription: String? = nil,
        beforeString: String? = nil,
        afterString: String? = nil,
        afterRole: String? = nil,
        change: CommitDiffChangeKind,
        reflowedFromNameID: Int? = nil,
        reflowSuppressed: Bool = false
    ) {
        self.id = id
        self.beforeDescription = beforeDescription
        self.beforeString = beforeString
        self.afterString = afterString
        self.afterRole = afterRole
        self.change = change
        self.reflowedFromNameID = reflowedFromNameID
        self.reflowSuppressed = reflowSuppressed
    }

    enum CodingKeys: String, CodingKey {
        case id, beforeDescription, beforeString, afterString, afterRole, change
        case reflowedFromNameID = "reflowed_from_name_id"
        case reflowSuppressed = "reflow_suppressed"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        beforeDescription = try c.decodeIfPresent(String.self, forKey: .beforeDescription)
        beforeString = try c.decodeIfPresent(String.self, forKey: .beforeString)
        afterString = try c.decodeIfPresent(String.self, forKey: .afterString)
        afterRole = try c.decodeIfPresent(String.self, forKey: .afterRole)
        change = try c.decode(CommitDiffChangeKind.self, forKey: .change)
        reflowedFromNameID = try c.decodeIfPresent(Int.self, forKey: .reflowedFromNameID)
        reflowSuppressed = try c.decodeIfPresent(Bool.self, forKey: .reflowSuppressed) ?? false
    }
}

public struct CommitDiffReport: Codable, Equatable, Sendable {
    public var statRows: [CommitDiffStatRow]
    public var instanceRows: [CommitDiffInstanceRow]
    public var nameIDRows: [CommitDiffNameIDRow]

    public var statChangedCount: Int {
        statRows.filter { $0.change != .unchanged }.count
    }

    public var instanceChangedCount: Int {
        instanceRows.filter { $0.change != .unchanged }.count
    }

    public var nameIDChangedCount: Int {
        nameIDRows.filter { $0.change != .unchanged }.count
    }
}

public struct CommitSummary: Codable, Equatable, Sendable {
    public var instancesWritten: Int
    public var statValuesWritten: Int
    public var nameIDsAllocated: [Int]
    public var wipedInstanceCount: Int
    public var protectedNameIDs: [Int]
    public var otReflowMapping: [String: Int]?
    public var orphanNameIDsDropped: [Int]?

    enum CodingKeys: String, CodingKey {
        case instancesWritten = "instances_written"
        case statValuesWritten = "stat_values_written"
        case nameIDsAllocated = "name_ids_allocated"
        case wipedInstanceCount = "wiped_instance_count"
        case protectedNameIDs = "protected_name_ids"
        case otReflowMapping = "ot_reflow_mapping"
        case orphanNameIDsDropped = "orphan_nameids_dropped"
    }

    public init(
        instancesWritten: Int = 0,
        statValuesWritten: Int = 0,
        nameIDsAllocated: [Int] = [],
        wipedInstanceCount: Int = 0,
        protectedNameIDs: [Int] = [],
        otReflowMapping: [String: Int]? = nil,
        orphanNameIDsDropped: [Int]? = nil
    ) {
        self.instancesWritten = instancesWritten
        self.statValuesWritten = statValuesWritten
        self.nameIDsAllocated = nameIDsAllocated
        self.wipedInstanceCount = wipedInstanceCount
        self.protectedNameIDs = protectedNameIDs
        self.otReflowMapping = otReflowMapping
        self.orphanNameIDsDropped = orphanNameIDsDropped
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instancesWritten = try c.decode(Int.self, forKey: .instancesWritten)
        statValuesWritten = try c.decode(Int.self, forKey: .statValuesWritten)
        nameIDsAllocated = try c.decode([Int].self, forKey: .nameIDsAllocated)
        wipedInstanceCount = try c.decode(Int.self, forKey: .wipedInstanceCount)
        protectedNameIDs = try c.decode([Int].self, forKey: .protectedNameIDs)
        otReflowMapping = try c.decodeIfPresent([String: Int].self, forKey: .otReflowMapping)
        orphanNameIDsDropped = try c.decodeIfPresent([Int].self, forKey: .orphanNameIDsDropped)
    }
}

public struct CommitError: Codable, Equatable, Sendable {
    public var code: String
    public var message: String
}
