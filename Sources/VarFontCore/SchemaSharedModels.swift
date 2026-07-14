import Foundation

// MARK: - Shared (axes, naming)

public enum AxisRole: String, Codable, Sendable, CaseIterable {
    case instance
    case statOnly = "stat_only"
    case parametric
    /// STAT DesignAxisRecord axis with no corresponding fvar scale.
    case designRecordOnly = "design_record_only"
}

public struct AxisValue: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var value: Double
    public var name: String
    public var elidable: Bool
    public var olderSibling: Bool
    public var statFormat: Int
    public var rangeMin: Double?
    public var rangeMax: Double?
    public var linkedValue: Double?

    enum CodingKeys: String, CodingKey {
        case id, value, name, elidable
        case olderSibling = "older_sibling"
        case statFormat = "stat_format"
        case rangeMin = "range_min"
        case rangeMax = "range_max"
        case linkedValue = "linked_value"
    }

    public init(
        id: String,
        value: Double,
        name: String,
        elidable: Bool,
        olderSibling: Bool = false,
        statFormat: Int = 1,
        rangeMin: Double? = nil,
        rangeMax: Double? = nil,
        linkedValue: Double? = nil
    ) {
        self.id = id
        self.value = value
        self.name = name
        self.elidable = elidable
        self.olderSibling = olderSibling
        self.statFormat = statFormat
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
        self.linkedValue = linkedValue
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        value = try c.decode(Double.self, forKey: .value)
        name = try c.decode(String.self, forKey: .name)
        elidable = try c.decode(Bool.self, forKey: .elidable)
        olderSibling = try c.decodeIfPresent(Bool.self, forKey: .olderSibling) ?? false
        statFormat = try c.decodeIfPresent(Int.self, forKey: .statFormat) ?? 1
        rangeMin = try c.decodeIfPresent(Double.self, forKey: .rangeMin)
        rangeMax = try c.decodeIfPresent(Double.self, forKey: .rangeMax)
        linkedValue = try c.decodeIfPresent(Double.self, forKey: .linkedValue)
    }
}

/// STAT format 4 compound multi-axis entry preserved from source font.
public struct CompoundStatValue: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var coords: [String: Double]
    public var axisIndices: [Int]
    public var axisValues: [Double]
    public var name: String
    public var elidable: Bool
    public var olderSibling: Bool

    enum CodingKeys: String, CodingKey {
        case id, coords, name, elidable
        case axisIndices = "axis_indices"
        case axisValues = "axis_values"
        case olderSibling = "older_sibling"
    }

    public init(
        id: String,
        coords: [String: Double],
        axisIndices: [Int],
        axisValues: [Double],
        name: String,
        elidable: Bool,
        olderSibling: Bool = false
    ) {
        self.id = id
        self.coords = coords
        self.axisIndices = axisIndices
        self.axisValues = axisValues
        self.name = name
        self.elidable = elidable
        self.olderSibling = olderSibling
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        coords = try c.decode([String: Double].self, forKey: .coords)
        axisIndices = try c.decodeIfPresent([Int].self, forKey: .axisIndices) ?? []
        axisValues = try c.decodeIfPresent([Double].self, forKey: .axisValues) ?? []
        name = try c.decode(String.self, forKey: .name)
        elidable = try c.decode(Bool.self, forKey: .elidable)
        olderSibling = try c.decodeIfPresent(Bool.self, forKey: .olderSibling) ?? false
    }
}

public struct AxisDefinition: Codable, Equatable, Sendable, Identifiable {
    public var tag: String
    public var displayName: String?
    public var min: Double?
    public var `default`: Double?
    public var max: Double?
    public var role: AxisRole
    /// Role inferred at import; used by Restore in the naming chain footer.
    public var roleInferred: AxisRole?
    public var values: [AxisValue]
    public var referenceMapping: ReferenceMappingKind?
    public var referenceMappingInferred: ReferenceMappingKind?
    public var referenceAnchors: [ReferenceAnchor]
    /// fvar HIDDEN_AXIS flag from source (recommend axis stay out of user-facing UIs).
    public var fvarHidden: Bool

    public var id: String { tag }

    enum CodingKeys: String, CodingKey {
        case tag
        case displayName = "display_name"
        case min, `default`, max, role
        case roleInferred = "role_inferred"
        case values
        case referenceMapping = "reference_mapping"
        case referenceMappingInferred = "reference_mapping_inferred"
        case referenceAnchors = "reference_anchors"
        case fvarHidden = "fvar_hidden"
    }

    public init(
        tag: String,
        displayName: String? = nil,
        min: Double? = nil,
        default: Double? = nil,
        max: Double? = nil,
        role: AxisRole = .instance,
        roleInferred: AxisRole? = nil,
        values: [AxisValue] = [],
        referenceMapping: ReferenceMappingKind? = nil,
        referenceMappingInferred: ReferenceMappingKind? = nil,
        referenceAnchors: [ReferenceAnchor] = [],
        fvarHidden: Bool = false
    ) {
        self.tag = tag
        self.displayName = displayName
        self.min = min
        self.default = `default`
        self.max = max
        self.role = role
        self.roleInferred = roleInferred
        self.values = values
        self.referenceMapping = referenceMapping
        self.referenceMappingInferred = referenceMappingInferred
        self.referenceAnchors = referenceAnchors
        self.fvarHidden = fvarHidden
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tag = try c.decode(String.self, forKey: .tag)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        min = try c.decodeIfPresent(Double.self, forKey: .min)
        `default` = try c.decodeIfPresent(Double.self, forKey: .default)
        max = try c.decodeIfPresent(Double.self, forKey: .max)
        role = try c.decodeIfPresent(AxisRole.self, forKey: .role) ?? .instance
        roleInferred = try c.decodeIfPresent(AxisRole.self, forKey: .roleInferred)
        values = try c.decodeIfPresent([AxisValue].self, forKey: .values) ?? []
        referenceMapping = try c.decodeIfPresent(ReferenceMappingKind.self, forKey: .referenceMapping)
        referenceMappingInferred = try c.decodeIfPresent(ReferenceMappingKind.self, forKey: .referenceMappingInferred)
        referenceAnchors = try c.decodeIfPresent([ReferenceAnchor].self, forKey: .referenceAnchors) ?? []
        fvarHidden = try c.decodeIfPresent(Bool.self, forKey: .fvarHidden) ?? false
    }

    /// True when this axis exists only in STAT DesignAxisRecord (no fvar scale).
    public var isDesignRecordOnly: Bool { role == .designRecordOnly }

    /// True when fvar min/default/max apply to this axis.
    public var hasFvarScale: Bool { min != nil }
}

public struct NamingPolicy: Codable, Equatable, Sendable {
    public var order: [String]
    /// STAT-inferred order captured at import; used by Restore in the naming chain footer.
    public var inferredOrder: [String]?
    public var elidedFallback: String

    enum CodingKeys: String, CodingKey {
        case order
        case inferredOrder = "inferred_order"
        case elidedFallback = "elided_fallback"
    }

    public static let clarifierTokenWidth = "@width"
    public static let clarifierTokenSlope = "@slope"
    public static let clarifierTokenOptical = "@optical"
    public static let clarifierTokenCustom = "@custom"
    public static let postscriptHyphenToken = "@pshyphen"

    public static let defaultClarifierTokens: [String] = [
        clarifierTokenWidth,
        clarifierTokenSlope,
        clarifierTokenOptical,
        clarifierTokenCustom
    ]

    public init(order: [String], inferredOrder: [String]? = nil, elidedFallback: String = "Regular") {
        self.order = order
        self.inferredOrder = inferredOrder
        self.elidedFallback = elidedFallback
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        order = try c.decode([String].self, forKey: .order)
        inferredOrder = try c.decodeIfPresent([String].self, forKey: .inferredOrder)
        elidedFallback = try c.decodeIfPresent(String.self, forKey: .elidedFallback) ?? "Regular"
    }

    /// Appends default clarifier tokens to axis order when missing.
    public static func orderWithDefaultClarifiers(axisOrder: [String]) -> [String] {
        var result = axisOrder.filter { !NamingToken.isSpecialToken($0) }
        for token in defaultClarifierTokens where !result.contains(token) {
            result.append(token)
        }
        return ensurePostscriptHyphen(in: result)
    }

    /// Ensures exactly one PS hyphen marker exists (default: first in the chain).
    public static func ensurePostscriptHyphen(in order: [String]) -> [String] {
        let without = order.filter { $0 != postscriptHyphenToken }
        if let originalIndex = order.firstIndex(of: postscriptHyphenToken) {
            var result = without
            let insertAt = min(originalIndex, result.count)
            result.insert(postscriptHyphenToken, at: insertAt)
            return result
        }
        var result = without
        result.insert(postscriptHyphenToken, at: 0)
        return result
    }

    /// Restore helper — PS hyphen returns to the default first position.
    public static func resetPostscriptHyphenToDefault(in order: [String]) -> [String] {
        ensurePostscriptHyphen(in: order.filter { $0 != postscriptHyphenToken })
    }

    /// Project naming order filtered to axes present in this file plus clarifier tokens.
    public static func mergedOrder(projectOrder: [String], axisTags: [String]) -> [String] {
        var result: [String] = []
        var seenAxes = Set<String>()
        var seenClarifiers = Set<String>()
        var hasHyphen = false

        for token in projectOrder {
            if NamingToken.isPostscriptHyphen(token) {
                if !hasHyphen {
                    result.append(postscriptHyphenToken)
                    hasHyphen = true
                }
                continue
            }
            if NamingToken.isClarifier(token) {
                guard !seenClarifiers.contains(token) else { continue }
                result.append(token)
                seenClarifiers.insert(token)
            } else if axisTags.contains(token), !seenAxes.contains(token) {
                result.append(token)
                seenAxes.insert(token)
            }
        }

        for tag in axisTags where !seenAxes.contains(tag) {
            result.append(tag)
        }
        for token in defaultClarifierTokens where !seenClarifiers.contains(token) {
            result.append(token)
        }
        if !hasHyphen {
            result.insert(postscriptHyphenToken, at: 0)
        }
        return result
    }
}

public enum NamingToken {
    public static func isPostscriptHyphen(_ token: String) -> Bool {
        token == NamingPolicy.postscriptHyphenToken
    }

    public static func isSpecialToken(_ token: String) -> Bool {
        isPostscriptHyphen(token) || isClarifier(token)
    }

    public static func isClarifier(_ token: String) -> Bool {
        guard !isPostscriptHyphen(token) else { return false }
        return token.hasPrefix("@")
    }

    public static func clarifierCategory(for token: String) -> FileClarifierCategory? {
        switch token {
        case NamingPolicy.clarifierTokenWidth: return .width
        case NamingPolicy.clarifierTokenSlope: return .slope
        case NamingPolicy.clarifierTokenOptical: return .optical
        case NamingPolicy.clarifierTokenCustom: return .custom
        default: return nil
        }
    }

    public static func token(for category: FileClarifierCategory) -> String {
        switch category {
        case .width: return NamingPolicy.clarifierTokenWidth
        case .slope: return NamingPolicy.clarifierTokenSlope
        case .optical: return NamingPolicy.clarifierTokenOptical
        case .custom: return NamingPolicy.clarifierTokenCustom
        }
    }

    public static func clarifierPillLabel(for category: FileClarifierCategory) -> String {
        switch category {
        case .width: return "Width"
        case .slope: return "Slope"
        case .optical: return "Optical"
        case .custom: return "Custom"
        }
    }

    public static var clarifierDisplayName: [String: String] {
        [
            NamingPolicy.clarifierTokenWidth: "width",
            NamingPolicy.clarifierTokenSlope: "slope",
            NamingPolicy.clarifierTokenOptical: "optical",
            NamingPolicy.clarifierTokenCustom: "custom"
        ]
    }
}

