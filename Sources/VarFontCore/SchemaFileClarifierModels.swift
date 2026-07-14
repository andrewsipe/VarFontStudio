import Foundation

// MARK: - File clarifiers (per-font family identity)

public enum FileClarifierCategory: String, Codable, Sendable, CaseIterable {
    case slope
    case width
    case optical
    case custom
}

public enum FileRoleKind: String, Codable, Sendable {
    case master
    case variant
}

public struct FileClarifier: Codable, Equatable, Sendable, Identifiable {
    public var category: FileClarifierCategory
    public var label: String

    public var id: FileClarifierCategory { category }

    enum CodingKeys: String, CodingKey {
        case category, label
    }

    public init(category: FileClarifierCategory, label: String) {
        self.category = category
        self.label = label
    }
}

public struct FileRole: Codable, Equatable, Sendable {
    public var kind: FileRoleKind
    public var masterFontID: String?
    public var clarifiers: [FileClarifier]
    public var elidedFallbackOverride: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case masterFontID = "master_font_id"
        case clarifiers
        case elidedFallbackOverride = "elided_fallback_override"
    }

    public init(
        kind: FileRoleKind = .master,
        masterFontID: String? = nil,
        clarifiers: [FileClarifier] = [],
        elidedFallbackOverride: String? = nil
    ) {
        self.kind = kind
        self.masterFontID = masterFontID
        self.clarifiers = clarifiers
        self.elidedFallbackOverride = elidedFallbackOverride
    }

    public func label(for category: FileClarifierCategory) -> String? {
        clarifiers.first { $0.category == category }?.label
    }

    public static func master() -> FileRole {
        FileRole(kind: .master)
    }

    public static func variant(masterFontID: String, clarifiers: [FileClarifier] = [], elidedFallbackOverride: String? = nil) -> FileRole {
        FileRole(
            kind: .variant,
            masterFontID: masterFontID,
            clarifiers: clarifiers,
            elidedFallbackOverride: elidedFallbackOverride
        )
    }
}

public enum NameIDStrategy: String, Codable, Equatable, Sendable {
    case preserve
    case reflow
}

public struct CommitOptions: Codable, Equatable, Sendable {
    public var fixFvarDefault: Bool
    public var allocatePostscriptNames: Bool
    public var preserveStatFormat3: Bool?
    /// nameID 25 — prefix for fvar instance PostScript names (e.g. FamilyVariable).
    public var familyPSPrefix: String?
    /// How OpenType feature label nameIDs (ss/cv/size) are handled on save.
    public var nameidStrategy: NameIDStrategy

    enum CodingKeys: String, CodingKey {
        case fixFvarDefault = "fix_fvar_default"
        case allocatePostscriptNames = "allocate_postscript_names"
        case preserveStatFormat3 = "preserve_stat_format_3"
        case familyPSPrefix = "family_ps_prefix"
        case nameidStrategy = "nameid_strategy"
    }

    public init(
        fixFvarDefault: Bool = false,
        allocatePostscriptNames: Bool = true,
        preserveStatFormat3: Bool? = true,
        familyPSPrefix: String? = nil,
        nameidStrategy: NameIDStrategy = .preserve
    ) {
        self.fixFvarDefault = fixFvarDefault
        self.allocatePostscriptNames = allocatePostscriptNames
        self.preserveStatFormat3 = preserveStatFormat3
        self.familyPSPrefix = familyPSPrefix
        self.nameidStrategy = nameidStrategy
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fixFvarDefault = try c.decodeIfPresent(Bool.self, forKey: .fixFvarDefault) ?? false
        allocatePostscriptNames = try c.decodeIfPresent(Bool.self, forKey: .allocatePostscriptNames) ?? true
        preserveStatFormat3 = try c.decodeIfPresent(Bool.self, forKey: .preserveStatFormat3)
        familyPSPrefix = try c.decodeIfPresent(String.self, forKey: .familyPSPrefix)
        nameidStrategy = try c.decodeIfPresent(NameIDStrategy.self, forKey: .nameidStrategy) ?? .preserve
    }
}

