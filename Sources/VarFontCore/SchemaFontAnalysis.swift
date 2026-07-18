import Foundation

// MARK: - FontAnalysis

public struct FontAnalysis: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var source: SourceInfo
    public var readiness: Readiness
    public var axes: [AnalyzedAxis]
    public var statValues: [StatValueRecord]
    public var compoundStatValues: [CompoundStatRecord]
    public var instancesExisting: [ExistingInstance]
    public var instancesExistingMeta: InstancesMeta?
    public var nameAudit: NameAudit
    /// Windows English (3,1,0x0409) name IDs 0–25 present in the font.
    public var windowsNameTable: [WindowsNameRecord]
    public var inferred: InferredAnalysis
    /// STAT DesignAxisRecord tags in table order (fvar parity checks).
    public var designAxisTags: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case source, readiness, axes
        case statValues = "stat_values"
        case compoundStatValues = "compound_stat_values"
        case instancesExisting = "instances_existing"
        case instancesExistingMeta = "instances_existing_meta"
        case nameAudit = "name_audit"
        case windowsNameTable = "windows_name_table"
        case inferred
        case designAxisTags = "design_axis_tags"
    }

    public struct SourceInfo: Codable, Equatable, Sendable {
        public var path: String
        public var format: String
        public var familyName: String
        public var fullName: String
        public var postscriptName: String?
        public var isVariable: Bool
        /// nameID 25 — Variations PostScript Name Prefix.
        public var familyPSPrefix: String?

        enum CodingKeys: String, CodingKey {
            case path, format
            case familyName = "family_name"
            case fullName = "full_name"
            case postscriptName = "postscript_name"
            case isVariable = "is_variable"
            case familyPSPrefix = "family_ps_prefix"
        }
    }

    public struct Readiness: Codable, Equatable, Sendable {
        public var hasFvar: Bool
        public var hasStat: Bool
        public var hasDesignAxisRecord: Bool
        public var writable: Bool
        public var blockers: [String]

        enum CodingKeys: String, CodingKey {
            case hasFvar = "has_fvar"
            case hasStat = "has_stat"
            case hasDesignAxisRecord = "has_design_axis_record"
            case writable, blockers
        }
    }

    public struct AnalyzedAxis: Codable, Equatable, Sendable, Identifiable {
        public var tag: String
        public var displayName: String
        public var min: Double
        public var `default`: Double
        public var max: Double
        public var ordering: Int?
        public var roleInferred: AxisRole
        public var variesInExistingInstances: Bool
        public var valuesExisting: [StatValueSnapshot]
        public var fvarHidden: Bool?

        public var id: String { tag }

        enum CodingKeys: String, CodingKey {
            case tag
            case displayName = "display_name"
            case min, `default`, max, ordering
            case roleInferred = "role_inferred"
            case variesInExistingInstances = "varies_in_existing_instances"
            case valuesExisting = "values_existing"
            case fvarHidden = "fvar_hidden"
        }
    }

    public struct StatValueSnapshot: Codable, Equatable, Sendable {
        public var format: Int?
        public var value: Double?
        public var name: String
        public var elidable: Bool?
        public var olderSibling: Bool?
        public var linkedValue: Double?
        public var rangeMin: Double?
        public var rangeMax: Double?
        public var nominal: Double?

        enum CodingKeys: String, CodingKey {
            case format, value, name, elidable
            case olderSibling = "older_sibling"
            case linkedValue = "linked_value"
            case rangeMin = "range_min"
            case rangeMax = "range_max"
            case nominal
        }
    }

    public struct StatValueRecord: Codable, Equatable, Sendable {
        public var format: Int
        public var tag: String
        public var name: String
        public var elidable: Bool
        public var olderSibling: Bool
        public var nameID: Int?
        public var value: Double?
        public var linkedValue: Double?
        public var rangeMin: Double?
        public var rangeMax: Double?
        public var nominal: Double?

        enum CodingKeys: String, CodingKey {
            case format, tag, name, elidable
            case olderSibling = "older_sibling"
            case nameID = "name_id"
            case value
            case linkedValue = "linked_value"
            case rangeMin = "range_min"
            case rangeMax = "range_max"
            case nominal
        }

        public init(
            format: Int,
            tag: String,
            name: String,
            elidable: Bool,
            olderSibling: Bool = false,
            nameID: Int? = nil,
            value: Double? = nil,
            linkedValue: Double? = nil,
            rangeMin: Double? = nil,
            rangeMax: Double? = nil,
            nominal: Double? = nil
        ) {
            self.format = format
            self.tag = tag
            self.name = name
            self.elidable = elidable
            self.olderSibling = olderSibling
            self.nameID = nameID
            self.value = value
            self.linkedValue = linkedValue
            self.rangeMin = rangeMin
            self.rangeMax = rangeMax
            self.nominal = nominal
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            format = try c.decode(Int.self, forKey: .format)
            tag = try c.decode(String.self, forKey: .tag)
            name = try c.decode(String.self, forKey: .name)
            elidable = try c.decode(Bool.self, forKey: .elidable)
            olderSibling = try c.decodeIfPresent(Bool.self, forKey: .olderSibling) ?? false
            nameID = try c.decodeIfPresent(Int.self, forKey: .nameID)
            value = try c.decodeIfPresent(Double.self, forKey: .value)
            linkedValue = try c.decodeIfPresent(Double.self, forKey: .linkedValue)
            rangeMin = try c.decodeIfPresent(Double.self, forKey: .rangeMin)
            rangeMax = try c.decodeIfPresent(Double.self, forKey: .rangeMax)
            nominal = try c.decodeIfPresent(Double.self, forKey: .nominal)
        }
    }

    public struct CompoundStatRecord: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var coords: [String: Double]
        public var axisIndices: [Int]
        public var axisValues: [Double]
        public var name: String
        public var elidable: Bool
        public var olderSibling: Bool
        public var nameID: Int?

        enum CodingKeys: String, CodingKey {
            case id, coords, name, elidable
            case axisIndices = "axis_indices"
            case axisValues = "axis_values"
            case olderSibling = "older_sibling"
            case nameID = "name_id"
        }

        public init(
            id: String,
            coords: [String: Double],
            axisIndices: [Int],
            axisValues: [Double],
            name: String,
            elidable: Bool,
            olderSibling: Bool = false,
            nameID: Int? = nil
        ) {
            self.id = id
            self.coords = coords
            self.axisIndices = axisIndices
            self.axisValues = axisValues
            self.name = name
            self.elidable = elidable
            self.olderSibling = olderSibling
            self.nameID = nameID
        }
    }

    public struct ExistingInstance: Codable, Equatable, Sendable {
        public var key: String
        public var composedName: String
        public var coords: [String: Double]
        public var subfamilyNameID: Int
        public var postscriptNameID: Int

        enum CodingKeys: String, CodingKey {
            case key
            case composedName = "composed_name"
            case coords
            case subfamilyNameID = "subfamily_name_id"
            case postscriptNameID = "postscript_name_id"
        }
    }

    public struct InstancesMeta: Codable, Equatable, Sendable {
        public var total: Int
        public var sampleCount: Int

        enum CodingKeys: String, CodingKey {
            case total
            case sampleCount = "sample_count"
        }
    }

    public struct NameAudit: Codable, Equatable, Sendable {
        public var freeStart: Int
        public var used: [NameIDUse]
        public var elidedFallbackID: Int?
        public var elidedFallbackName: String?

        enum CodingKeys: String, CodingKey {
            case freeStart = "free_start"
            case used
            case elidedFallbackID = "elided_fallback_id"
            case elidedFallbackName = "elided_fallback_name"
        }

        public struct NameIDUse: Codable, Equatable, Sendable {
            public var id: Int
            public var description: String
            /// Resolved name-table string when available.
            public var string: String?
            public var protected: Bool?

            public init(id: Int, description: String, string: String? = nil, protected: Bool? = nil) {
                self.id = id
                self.description = description
                self.string = string
                self.protected = protected
            }
        }
    }

    public struct InferredAnalysis: Codable, Equatable, Sendable {
        public var isItalicFont: Bool
        public var gridAxisTags: [String]
        public var namingOrderSuggested: [String]
        /// post.italicAngle when present (counter-clockwise degrees; matches slnt scale).
        public var postItalicAngle: Double?

        enum CodingKeys: String, CodingKey {
            case isItalicFont = "is_italic_font"
            case gridAxisTags = "grid_axis_tags"
            case namingOrderSuggested = "naming_order_suggested"
            case postItalicAngle = "post_italic_angle"
        }
    }

    public init(
        schemaVersion: Int,
        source: SourceInfo,
        readiness: Readiness,
        axes: [AnalyzedAxis],
        statValues: [StatValueRecord],
        compoundStatValues: [CompoundStatRecord] = [],
        instancesExisting: [ExistingInstance],
        instancesExistingMeta: InstancesMeta? = nil,
        nameAudit: NameAudit,
        windowsNameTable: [WindowsNameRecord] = [],
        inferred: InferredAnalysis,
        designAxisTags: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.source = source
        self.readiness = readiness
        self.axes = axes
        self.statValues = statValues
        self.compoundStatValues = compoundStatValues
        self.instancesExisting = instancesExisting
        self.instancesExistingMeta = instancesExistingMeta
        self.nameAudit = nameAudit
        self.windowsNameTable = windowsNameTable
        self.inferred = inferred
        self.designAxisTags = designAxisTags
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        source = try c.decode(SourceInfo.self, forKey: .source)
        readiness = try c.decode(Readiness.self, forKey: .readiness)
        axes = try c.decode([AnalyzedAxis].self, forKey: .axes)
        statValues = try c.decode([StatValueRecord].self, forKey: .statValues)
        compoundStatValues = try c.decodeIfPresent([CompoundStatRecord].self, forKey: .compoundStatValues) ?? []
        instancesExisting = try c.decode([ExistingInstance].self, forKey: .instancesExisting)
        instancesExistingMeta = try c.decodeIfPresent(InstancesMeta.self, forKey: .instancesExistingMeta)
        nameAudit = try c.decode(NameAudit.self, forKey: .nameAudit)
        windowsNameTable = try c.decodeIfPresent([WindowsNameRecord].self, forKey: .windowsNameTable) ?? []
        inferred = try c.decode(InferredAnalysis.self, forKey: .inferred)
        designAxisTags = try c.decodeIfPresent([String].self, forKey: .designAxisTags) ?? []
    }
}

