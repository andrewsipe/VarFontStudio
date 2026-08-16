import Foundation

// MARK: - OpenType feature label inventory / patches

/// One FeatureParams-linked name string (ss/cv/size).
public struct OTFeatureLabelRecord: Codable, Equatable, Sendable, Identifiable {
    public var table: String
    public var featureTag: String
    public var field: String
    public var nameID: Int
    public var string: String

    public var id: String { siteKey }

    public var siteKey: String {
        OTFeatureLabelSite.key(table: table, featureTag: featureTag, field: field)
    }

    enum CodingKeys: String, CodingKey {
        case table
        case featureTag = "feature_tag"
        case field
        case nameID = "name_id"
        case string
    }

    public init(table: String, featureTag: String, field: String, nameID: Int, string: String) {
        self.table = table
        self.featureTag = featureTag
        self.field = field
        self.nameID = nameID
        self.string = string
    }
}

/// An ss## feature lacking a primary UI label.
public struct OTFeatureUnlabeled: Codable, Equatable, Sendable, Identifiable {
    public var table: String
    public var featureTag: String
    /// Clear-only Fill suggestion; nil when the lookup walk is ambiguous.
    public var suggestedString: String?

    public var id: String { "\(table)|\(featureTag)" }

    enum CodingKeys: String, CodingKey {
        case table
        case featureTag = "feature_tag"
        case suggestedString = "suggested_string"
    }

    public init(table: String, featureTag: String, suggestedString: String? = nil) {
        self.table = table
        self.featureTag = featureTag
        self.suggestedString = suggestedString
    }
}

/// Site key helpers for project overrides (table|tag|field).
public enum OTFeatureLabelSite {
    public static func key(table: String, featureTag: String, field: String) -> String {
        "\(table)|\(featureTag)|\(field)"
    }

    public static func parse(_ key: String) -> (table: String, featureTag: String, field: String)? {
        let parts = key.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        return (String(parts[0]), String(parts[1]), String(parts[2]))
    }
}

/// CommitRequest / CommitDiff patch for an existing FeatureParams site.
public struct OTFeatureLabelPatch: Codable, Equatable, Sendable, Identifiable {
    public var table: String
    public var featureTag: String
    public var field: String
    public var string: String
    public var nameID: Int?

    public var id: String {
        OTFeatureLabelSite.key(table: table, featureTag: featureTag, field: field)
    }

    enum CodingKeys: String, CodingKey {
        case table
        case featureTag = "feature_tag"
        case field, string
        case nameID = "name_id"
    }

    public init(table: String, featureTag: String, field: String, string: String, nameID: Int? = nil) {
        self.table = table
        self.featureTag = featureTag
        self.field = field
        self.string = string
        self.nameID = nameID
    }
}

/// Pending ss## FeatureParams creation.
public struct OTFeatureLabelAddition: Codable, Equatable, Sendable, Identifiable {
    public var table: String
    public var featureTag: String
    public var string: String

    public var id: String { "\(table)|\(featureTag)" }

    enum CodingKeys: String, CodingKey {
        case table
        case featureTag = "feature_tag"
        case string
    }

    public init(table: String, featureTag: String, string: String) {
        self.table = table
        self.featureTag = featureTag
        self.string = string
    }
}

/// Payload from vfcommit `op: analyze_ot_features`.
public struct OTFeatureAnalysisResult: Codable, Equatable, Sendable {
    public var ok: Bool
    public var otFeatureLabels: [OTFeatureLabelRecord]
    public var otFeaturesUnlabeled: [OTFeatureUnlabeled]
    public var error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case otFeatureLabels = "ot_feature_labels"
        case otFeaturesUnlabeled = "ot_features_unlabeled"
        case error
    }

    public init(
        ok: Bool,
        otFeatureLabels: [OTFeatureLabelRecord] = [],
        otFeaturesUnlabeled: [OTFeatureUnlabeled] = [],
        error: String? = nil
    ) {
        self.ok = ok
        self.otFeatureLabels = otFeatureLabels
        self.otFeaturesUnlabeled = otFeaturesUnlabeled
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        otFeatureLabels = try c.decodeIfPresent([OTFeatureLabelRecord].self, forKey: .otFeatureLabels) ?? []
        otFeaturesUnlabeled = try c.decodeIfPresent([OTFeatureUnlabeled].self, forKey: .otFeaturesUnlabeled) ?? []
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}
