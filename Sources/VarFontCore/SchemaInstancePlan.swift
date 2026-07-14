import Foundation

// MARK: - InstancePlan

public struct InstancePlan: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var fontID: String
    public var formula: PlanFormula
    public var instances: [PlannedInstance]
    public var warnings: [PlanWarning]
    public var namePlanSummary: NamePlanSummary?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case fontID = "font_id"
        case formula, instances, warnings
        case namePlanSummary = "name_plan_summary"
    }
}

public struct PlanFormula: Codable, Equatable, Sendable {
    public var parts: [Int]
    public var totalGenerated: Int
    public var totalIncluded: Int
    public var totalExcluded: Int

    enum CodingKeys: String, CodingKey {
        case parts
        case totalGenerated = "total_generated"
        case totalIncluded = "total_included"
        case totalExcluded = "total_excluded"
    }
}

public struct PlannedInstance: Codable, Equatable, Sendable, Identifiable {
    public var key: String
    public var composedName: String
    public var coords: [String: Double]
    public var included: Bool
    public var duplicate: Bool
    public var namingChain: [NamingChainLink]

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key
        case composedName = "composed_name"
        case coords, included, duplicate
        case namingChain = "naming_chain"
    }
}

public struct NamingChainLink: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case axis
        case registration
        case clarifier
    }

    public var kind: Kind
    public var tag: String
    public var name: String
    public var elided: Bool

    enum CodingKeys: String, CodingKey {
        case kind, tag, name, elided
    }

    public init(kind: Kind = .axis, tag: String, name: String, elided: Bool) {
        self.kind = kind
        self.tag = tag
        self.name = name
        self.elided = elided
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .axis
        tag = try c.decode(String.self, forKey: .tag)
        name = try c.decode(String.self, forKey: .name)
        elided = try c.decodeIfPresent(Bool.self, forKey: .elided) ?? false
    }
}

public struct PlanWarning: Codable, Equatable, Sendable {
    public var code: String
    public var axis: String?
    public var name: String?
    public var keys: [String]?
    /// Axis stop IDs involved in this warning (for axis-tree navigation).
    public var stopIDs: [String]?
    public var message: String
    /// Short guidance on how to resolve the warning in the axis tree.
    public var hint: String?

    public init(
        code: String,
        axis: String? = nil,
        name: String? = nil,
        keys: [String]? = nil,
        stopIDs: [String]? = nil,
        message: String,
        hint: String? = nil
    ) {
        self.code = code
        self.axis = axis
        self.name = name
        self.keys = keys
        self.stopIDs = stopIDs
        self.message = message
        self.hint = hint
    }
}

public struct NamePlanSummary: Codable, Equatable, Sendable {
    public var familyPSPrefix: String?
    public var newIDRange: [Int]?
    public var instanceCount: Int?
    public var note: String?

    enum CodingKeys: String, CodingKey {
        case familyPSPrefix = "family_ps_prefix"
        case newIDRange = "new_id_range"
        case instanceCount = "instance_count"
        case note
    }
}

