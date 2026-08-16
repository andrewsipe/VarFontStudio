import Foundation

/// Effective OpenType feature label rows for the Names panel.
public enum OTFeatureLabelEditing {
    public struct Row: Equatable, Sendable, Identifiable {
        public var table: String
        public var featureTag: String
        public var field: String
        public var nameID: Int?
        /// True when `nameID` is a preview allocation (not yet in the font).
        public var isProvisionalNameID: Bool
        public var value: String
        public var isOverride: Bool
        public var isAddition: Bool
        public var suggestedString: String?

        public var id: String {
            OTFeatureLabelSite.key(table: table, featureTag: featureTag, field: field)
        }

        public var label: String {
            Self.displayLabel(for: featureTag)
        }

        /// Human label matching Names-panel style (e.g. "Stylistic Set 01").
        public static func displayLabel(for featureTag: String) -> String {
            let tag = featureTag.lowercased()
            if tag.count == 4,
               tag.hasPrefix("ss"),
               let n = Int(tag.dropFirst(2)) {
                return String(format: "Stylistic Set %02d", n)
            }
            if tag.count == 4,
               tag.hasPrefix("cv"),
               let n = Int(tag.dropFirst(2)) {
                return String(format: "Character Variant %02d", n)
            }
            if tag == "size" {
                return "Optical Size"
            }
            return featureTag
        }
    }

    public static func overrideKey(table: String, featureTag: String, field: String) -> String {
        OTFeatureLabelSite.key(table: table, featureTag: featureTag, field: field)
    }

    public static func populatedRows(
        labels: [OTFeatureLabelRecord],
        unlabeled: [OTFeatureUnlabeled],
        overrides: [String: String],
        additions: [OTFeatureLabelAddition],
        nameidStrategy: NameIDStrategy = .preserve
    ) -> [Row] {
        var rows: [Row] = []
        var coveredTags = Set<String>()
        var seenSites = Set<String>()
        var uniqueExistingSites: [OTFeatureLabelRecord] = []

        for label in labels {
            let key = label.siteKey
            if !seenSites.insert(key).inserted { continue }
            uniqueExistingSites.append(label)
            coveredTags.insert("\(label.table)|\(label.featureTag)")
            if let overridden = overrides[key] {
                rows.append(
                    Row(
                        table: label.table,
                        featureTag: label.featureTag,
                        field: label.field,
                        nameID: label.nameID,
                        isProvisionalNameID: false,
                        value: overridden,
                        isOverride: overridden != label.string,
                        isAddition: false,
                        suggestedString: nil
                    )
                )
            } else {
                rows.append(
                    Row(
                        table: label.table,
                        featureTag: label.featureTag,
                        field: label.field,
                        nameID: label.nameID,
                        isProvisionalNameID: false,
                        value: label.string,
                        isOverride: false,
                        isAddition: false,
                        suggestedString: nil
                    )
                )
            }
        }

        let provisional = provisionalNameIDs(
            existingLabels: uniqueExistingSites,
            additions: additions,
            nameidStrategy: nameidStrategy
        )

        for addition in additions {
            let tagKey = "\(addition.table)|\(addition.featureTag)"
            coveredTags.insert(tagKey)
            let field = "UINameID"
            let key = overrideKey(table: addition.table, featureTag: addition.featureTag, field: field)
            let value = overrides[key] ?? addition.string
            rows.append(
                Row(
                    table: addition.table,
                    featureTag: addition.featureTag,
                    field: field,
                    nameID: provisional[key],
                    isProvisionalNameID: provisional[key] != nil,
                    value: value,
                    isOverride: true,
                    isAddition: true,
                    suggestedString: nil
                )
            )
        }

        for item in unlabeled {
            let tagKey = "\(item.table)|\(item.featureTag)"
            if coveredTags.contains(tagKey) { continue }
            rows.append(
                Row(
                    table: item.table,
                    featureTag: item.featureTag,
                    field: "UINameID",
                    nameID: nil,
                    isProvisionalNameID: false,
                    value: "",
                    isOverride: false,
                    isAddition: false,
                    suggestedString: item.suggestedString
                )
            )
        }

        return rows.sorted {
            if $0.table != $1.table { return $0.table < $1.table }
            if $0.featureTag != $1.featureTag { return $0.featureTag < $1.featureTag }
            return $0.field < $1.field
        }
    }

    /// Preview nameIDs for pending ss## additions, matching vfcommit allocation intent.
    ///
    /// - `preserve`: continue after the highest existing OT label nameID (the preserved
    ///   sequence). Falls back to 256 when the font has no OT labels yet.
    /// - `reflow`: existing OT labels are treated as occupying 256..<256+N; additions follow.
    public static func provisionalNameIDs(
        existingLabels: [OTFeatureLabelRecord],
        additions: [OTFeatureLabelAddition],
        nameidStrategy: NameIDStrategy
    ) -> [String: Int] {
        var used = Set(existingLabels.map(\.nameID).filter { $0 > 0 })
        let start: Int
        switch nameidStrategy {
        case .reflow:
            let siteCount = Set(existingLabels.map(\.siteKey)).count
            if siteCount > 0 {
                used.formUnion(256..<(256 + siteCount))
            }
            start = 256
        case .preserve:
            // Keep new labels in the preserved OT block rather than jumping back to 256.
            let maxExisting = existingLabels.map(\.nameID).filter { $0 > 0 }.max()
            start = max(256, (maxExisting ?? 255) + 1)
        }

        var next = start
        var assigned: [String: Int] = [:]
        let ordered = additions.sorted {
            if $0.table != $1.table { return $0.table < $1.table }
            return $0.featureTag < $1.featureTag
        }
        for addition in ordered {
            let key = overrideKey(table: addition.table, featureTag: addition.featureTag, field: "UINameID")
            while used.contains(next) {
                next += 1
            }
            assigned[key] = next
            used.insert(next)
            next += 1
        }
        return assigned
    }

    public static func canRevert(
        table: String,
        featureTag: String,
        field: String,
        labels: [OTFeatureLabelRecord],
        overrides: [String: String],
        additions: [OTFeatureLabelAddition]
    ) -> Bool {
        let key = overrideKey(table: table, featureTag: featureTag, field: field)
        guard overrides[key] != nil || additions.contains(where: {
            $0.table == table && $0.featureTag == featureTag
        }) else {
            return false
        }
        let baseline = labels.first {
            $0.table == table && $0.featureTag == featureTag && $0.field == field
        }?.string
        if let override = overrides[key], override != baseline {
            return true
        }
        return additions.contains { $0.table == table && $0.featureTag == featureTag }
    }

    /// Patches for existing FeatureParams sites that differ from analysis.
    /// Empty `string` means remove the name-table label (feature + lookups stay).
    public static func commitPatches(
        labels: [OTFeatureLabelRecord],
        overrides: [String: String]
    ) -> [OTFeatureLabelPatch] {
        // Fonts may register the same FeatureParams site more than once (duplicate
        // FeatureRecords). Keep the first and ignore later collisions.
        let byKey = Dictionary(labels.map { ($0.siteKey, $0) }, uniquingKeysWith: { first, _ in first })
        var patches: [OTFeatureLabelPatch] = []
        for (key, value) in overrides {
            guard let parts = OTFeatureLabelSite.parse(key),
                  let baseline = byKey[key] else {
                continue
            }
            if baseline.string == value { continue }
            patches.append(
                OTFeatureLabelPatch(
                    table: parts.table,
                    featureTag: parts.featureTag,
                    field: parts.field,
                    string: value,
                    nameID: baseline.nameID
                )
            )
        }
        return patches.sorted {
            if $0.table != $1.table { return $0.table < $1.table }
            if $0.featureTag != $1.featureTag { return $0.featureTag < $1.featureTag }
            return $0.field < $1.field
        }
    }

    /// Additions whose string is non-empty (export-ready).
    public static func commitAdditions(
        additions: [OTFeatureLabelAddition],
        overrides: [String: String]
    ) -> [OTFeatureLabelAddition] {
        additions.compactMap { addition in
            let key = overrideKey(table: addition.table, featureTag: addition.featureTag, field: "UINameID")
            let value = (overrides[key] ?? addition.string)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return OTFeatureLabelAddition(table: addition.table, featureTag: addition.featureTag, string: value)
        }
        .sorted {
            if $0.table != $1.table { return $0.table < $1.table }
            return $0.featureTag < $1.featureTag
        }
    }
}
