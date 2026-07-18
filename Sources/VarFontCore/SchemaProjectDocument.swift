import Foundation

// MARK: - ProjectDocument

public enum CoordinateDisplayMode: String, Codable, Sendable, CaseIterable {
    case native
    case reference
}

public struct ProjectDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var created: Date?
    public var modified: Date?
    public var familyLabel: String
    /// User-visible project tab label; falls back to familyLabel then first filename.
    public var displayName: String?
    public var naming: NamingPolicy
    public var template: ProjectTemplate
    public var fonts: [FontDocument]
    public var coordinateDisplay: CoordinateDisplayMode
    /// Project-wide OpenType feature label nameID strategy for save/commit.
    public var nameidStrategy: NameIDStrategy

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case created, modified
        case familyLabel = "family_label"
        case displayName = "display_name"
        case naming, template, fonts
        case coordinateDisplay = "coordinate_display"
        case nameidStrategy = "nameid_strategy"
    }

    public init(
        schemaVersion: Int,
        created: Date? = nil,
        modified: Date? = nil,
        familyLabel: String,
        displayName: String? = nil,
        naming: NamingPolicy,
        template: ProjectTemplate,
        fonts: [FontDocument],
        coordinateDisplay: CoordinateDisplayMode = .reference,
        nameidStrategy: NameIDStrategy = .preserve
    ) {
        self.schemaVersion = schemaVersion
        self.created = created
        self.modified = modified
        self.familyLabel = familyLabel
        self.displayName = displayName
        self.naming = naming
        self.template = template
        self.fonts = fonts
        self.coordinateDisplay = coordinateDisplay
        self.nameidStrategy = nameidStrategy
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        created = try c.decodeIfPresent(Date.self, forKey: .created)
        modified = try c.decodeIfPresent(Date.self, forKey: .modified)
        familyLabel = try c.decode(String.self, forKey: .familyLabel)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        naming = try c.decode(NamingPolicy.self, forKey: .naming)
        template = try c.decode(ProjectTemplate.self, forKey: .template)
        fonts = try c.decode([FontDocument].self, forKey: .fonts)
        coordinateDisplay = try c.decodeIfPresent(CoordinateDisplayMode.self, forKey: .coordinateDisplay) ?? .reference
        nameidStrategy = try c.decodeIfPresent(NameIDStrategy.self, forKey: .nameidStrategy)
            ?? fonts.first?.options.nameidStrategy
            ?? .preserve
        migrateFileRolesIfNeeded()
        var promoted = self
        _ = RegistrationAxisFactory.promoteClarifiersToRegistration(&promoted)
        self = promoted
        syncNameIDStrategyToFonts()
    }

    /// Keep per-font commit options aligned with the project preference.
    public mutating func syncNameIDStrategyToFonts() {
        for index in fonts.indices where fonts[index].options.nameidStrategy != nameidStrategy {
            fonts[index].options.nameidStrategy = nameidStrategy
        }
    }

    /// First font is master; others are variants when `file_role` was absent (legacy projects).
    private mutating func migrateFileRolesIfNeeded() {
        guard !fonts.isEmpty else { return }
        let needsMigration = fonts.contains { $0.fileRole == nil }
        guard needsMigration else { return }

        let masterID = fonts[0].id
        for index in fonts.indices {
            if fonts[index].fileRole == nil {
                fonts[index].fileRole = index == 0
                    ? .master()
                    : .variant(masterFontID: masterID)
            }
        }
    }

    /// Font to focus when opening a project — master when present, otherwise first file.
    public var preferredSelectedFontID: String? {
        fonts.first { $0.fileRole?.kind == .master }?.id ?? fonts.first?.id
    }
}

public struct ProjectTemplate: Codable, Equatable, Sendable {
    public var syncRoles: Bool
    public var axes: [AxisDefinition]

    enum CodingKeys: String, CodingKey {
        case syncRoles = "sync_roles"
        case axes
    }

    public init(syncRoles: Bool = true, axes: [AxisDefinition] = []) {
        self.syncRoles = syncRoles
        self.axes = axes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        syncRoles = try c.decodeIfPresent(Bool.self, forKey: .syncRoles) ?? true
        axes = try c.decodeIfPresent([AxisDefinition].self, forKey: .axes) ?? []
    }
}

public struct FontDocument: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var sourcePath: String
    public var outputPath: String?
    public var analysisSnapshotID: String?
    public var dirty: Bool
    public var fileRole: FileRole?
    public var axes: [AxisDefinition]
    public var options: CommitOptions
    public var includedInstanceKeys: [String]
    public var excludedInstanceKeys: [String]
    public var overrides: InstanceOverrides
    /// Per-file resolved values on registration (`design_record_only`) axes.
    public var fileStatRegistration: [String: Double]
    /// Import-time italic file cue for registration warnings without re-analyzing.
    public var inferredIsItalicFile: Bool?
    /// User-acknowledged plan issues (orphan F3 kept, etc.) — keys from `PlanIssueCodes.issueKey`.
    public var dismissedPlanIssues: [String]
    /// Preserved STAT format 4 compound entries (read-only in Phase 0).
    public var compoundStatValues: [CompoundStatValue]
    /// STAT DesignAxisRecord tags captured at import (fvar parity checks).
    public var statDesignAxisTags: [String]
    /// Windows (3,1,0x0409) edits for name IDs 0–24. Keys are decimal name IDs.
    /// Empty string means delete that Windows record on save. ID 25 uses `options.familyPSPrefix`.
    public var windowsNameOverrides: [String: String]

    enum CodingKeys: String, CodingKey {
        case id
        case sourcePath = "source_path"
        case outputPath = "output_path"
        case analysisSnapshotID = "analysis_snapshot_id"
        case dirty
        case fileRole = "file_role"
        case axes, options
        case includedInstanceKeys = "included_instance_keys"
        case excludedInstanceKeys = "excluded_instance_keys"
        case overrides
        case fileStatRegistration = "file_stat_registration"
        case inferredIsItalicFile = "inferred_is_italic_file"
        case dismissedPlanIssues = "dismissed_plan_issues"
        case compoundStatValues = "compound_stat_values"
        case statDesignAxisTags = "stat_design_axis_tags"
        case windowsNameOverrides = "windows_name_overrides"
    }

    public init(
        id: String,
        sourcePath: String,
        outputPath: String? = nil,
        analysisSnapshotID: String? = nil,
        dirty: Bool = false,
        fileRole: FileRole? = nil,
        axes: [AxisDefinition] = [],
        options: CommitOptions = CommitOptions(),
        includedInstanceKeys: [String] = [],
        excludedInstanceKeys: [String] = [],
        overrides: InstanceOverrides = InstanceOverrides(),
        fileStatRegistration: [String: Double] = [:],
        inferredIsItalicFile: Bool? = nil,
        dismissedPlanIssues: [String] = [],
        compoundStatValues: [CompoundStatValue] = [],
        statDesignAxisTags: [String] = [],
        windowsNameOverrides: [String: String] = [:]
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.outputPath = outputPath
        self.analysisSnapshotID = analysisSnapshotID
        self.dirty = dirty
        self.fileRole = fileRole
        self.axes = axes
        self.options = options
        self.includedInstanceKeys = includedInstanceKeys
        self.excludedInstanceKeys = excludedInstanceKeys
        self.overrides = overrides
        self.fileStatRegistration = fileStatRegistration
        self.inferredIsItalicFile = inferredIsItalicFile
        self.dismissedPlanIssues = dismissedPlanIssues
        self.compoundStatValues = compoundStatValues
        self.statDesignAxisTags = statDesignAxisTags
        self.windowsNameOverrides = windowsNameOverrides
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sourcePath = try c.decode(String.self, forKey: .sourcePath)
        outputPath = try c.decodeIfPresent(String.self, forKey: .outputPath)
        analysisSnapshotID = try c.decodeIfPresent(String.self, forKey: .analysisSnapshotID)
        dirty = try c.decodeIfPresent(Bool.self, forKey: .dirty) ?? false
        fileRole = try c.decodeIfPresent(FileRole.self, forKey: .fileRole)
        axes = try c.decodeIfPresent([AxisDefinition].self, forKey: .axes) ?? []
        options = try c.decodeIfPresent(CommitOptions.self, forKey: .options) ?? CommitOptions()
        includedInstanceKeys = try c.decodeIfPresent([String].self, forKey: .includedInstanceKeys) ?? []
        excludedInstanceKeys = try c.decodeIfPresent([String].self, forKey: .excludedInstanceKeys) ?? []
        overrides = try c.decodeIfPresent(InstanceOverrides.self, forKey: .overrides) ?? InstanceOverrides()
        fileStatRegistration = try c.decodeIfPresent([String: Double].self, forKey: .fileStatRegistration) ?? [:]
        inferredIsItalicFile = try c.decodeIfPresent(Bool.self, forKey: .inferredIsItalicFile)
        dismissedPlanIssues = try c.decodeIfPresent([String].self, forKey: .dismissedPlanIssues) ?? []
        compoundStatValues = try c.decodeIfPresent([CompoundStatValue].self, forKey: .compoundStatValues) ?? []
        statDesignAxisTags = try c.decodeIfPresent([String].self, forKey: .statDesignAxisTags) ?? []
        windowsNameOverrides = try c.decodeIfPresent([String: String].self, forKey: .windowsNameOverrides) ?? [:]
    }
}

public struct InstanceOverrides: Codable, Equatable, Sendable {
    public var perInstance: [PerInstanceOverride]

    enum CodingKeys: String, CodingKey {
        case perInstance = "per_instance"
    }

    public init(perInstance: [PerInstanceOverride] = []) {
        self.perInstance = perInstance
    }
}

public struct PerInstanceOverride: Codable, Equatable, Sendable {
    public var key: String
    public var omitAxesFromName: [String]?
    public var pinCoords: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case key
        case omitAxesFromName = "omit_axes_from_name"
        case pinCoords = "pin_coords"
    }
}

