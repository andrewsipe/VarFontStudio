import Foundation

/// Merges shared Windows name IDs from the master font onto sibling project files.
public enum NameTableMerge {
    /// Windows name IDs copied 1:1 from master to secondary files (credits / shared metadata).
    public static let pushableNameIDs: [Int] = [0, 7, 8, 9, 10, 11, 12, 13, 14]

    public enum MasterNameIntent: Equatable, Sendable {
        case set(String)
        case remove
        /// Master has no effective row for this ID — leave the target file unchanged.
        case leaveTarget
    }

    /// Effective push intent per shared ID from the master font.
    public static func masterIntents(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int]
    ) -> [Int: MasterNameIntent] {
        var intents: [Int: MasterNameIntent] = [:]
        for nameID in pushableNameIDs {
            if removals.contains(nameID) {
                intents[nameID] = .remove
                continue
            }
            let key = WindowsNameTableEditing.overrideKey(nameID)
            if let override = overrides[key] {
                intents[nameID] = .set(override)
                continue
            }
            if let analysis = WindowsNameTableEditing.analysisString(
                nameID: nameID,
                windowsNameTable: windowsNameTable
            ) {
                intents[nameID] = .set(analysis)
                continue
            }
            intents[nameID] = .leaveTarget
        }
        return intents
    }

    public static func mergeIntoTarget(
        masterIntents: [Int: MasterNameIntent],
        targetOverrides: [String: String],
        targetRemovals: [Int],
        targetWindowsNameTable: [WindowsNameRecord]
    ) -> (overrides: [String: String], removals: [Int]) {
        var overrides = targetOverrides
        var removals = targetRemovals

        for nameID in pushableNameIDs {
            guard let intent = masterIntents[nameID] else { continue }
            let key = WindowsNameTableEditing.overrideKey(nameID)
            switch intent {
            case .leaveTarget:
                break
            case .remove:
                overrides.removeValue(forKey: key)
                if !removals.contains(nameID) {
                    removals.append(nameID)
                    removals.sort()
                }
            case .set(let value):
                removals.removeAll { $0 == nameID }
                let baseline = WindowsNameTableEditing.analysisString(
                    nameID: nameID,
                    windowsNameTable: targetWindowsNameTable
                )
                if baseline == value {
                    overrides.removeValue(forKey: key)
                } else {
                    overrides[key] = value
                }
            }
        }

        return (overrides, removals)
    }

    // MARK: - OpenType feature labels

    /// Effective push intent per OpenType FeatureParams site (`table|tag|field`).
    /// Unlabeled master features with no pending addition are omitted (leave the target).
    public static func otMasterIntents(
        labels: [OTFeatureLabelRecord],
        overrides: [String: String],
        additions: [OTFeatureLabelAddition]
    ) -> [String: MasterNameIntent] {
        var intents: [String: MasterNameIntent] = [:]
        var covered = Set<String>()

        for label in labels {
            let key = label.siteKey
            if !covered.insert(key).inserted { continue }
            if let override = overrides[key] {
                intents[key] = .set(override)
            } else {
                intents[key] = .set(label.string)
            }
        }

        for addition in additions {
            let key = OTFeatureLabelEditing.overrideKey(
                table: addition.table,
                featureTag: addition.featureTag,
                field: "UINameID"
            )
            if covered.contains(key) { continue }
            covered.insert(key)
            let value = overrides[key] ?? addition.string
            intents[key] = .set(value)
        }

        return intents
    }

    public static func mergeOTIntoTarget(
        masterIntents: [String: MasterNameIntent],
        targetLabels: [OTFeatureLabelRecord],
        targetUnlabeled: [OTFeatureUnlabeled],
        targetOverrides: [String: String],
        targetAdditions: [OTFeatureLabelAddition]
    ) -> (overrides: [String: String], additions: [OTFeatureLabelAddition]) {
        var overrides = targetOverrides
        var additions = targetAdditions
        let labelsByKey = Dictionary(
            targetLabels.map { ($0.siteKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let unlabeledTags = Set(targetUnlabeled.map { "\($0.table)|\($0.featureTag)" })

        for (key, intent) in masterIntents {
            guard case .set(let value) = intent else { continue }
            guard let site = OTFeatureLabelSite.parse(key) else { continue }
            let tagKey = "\(site.table)|\(site.featureTag)"
            let hasLabeled = labelsByKey[key] != nil
            let hasUnlabeled = site.field == "UINameID" && unlabeledTags.contains(tagKey)
            let hasAddition = additions.contains {
                $0.table == site.table && $0.featureTag == site.featureTag
            }
            guard hasLabeled || hasUnlabeled || hasAddition else { continue }

            if hasLabeled {
                additions.removeAll {
                    $0.table == site.table && $0.featureTag == site.featureTag
                }
                let baseline = labelsByKey[key]?.string
                if baseline == value {
                    overrides.removeValue(forKey: key)
                } else {
                    overrides[key] = value
                }
                continue
            }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                overrides.removeValue(forKey: key)
                additions.removeAll {
                    $0.table == site.table && $0.featureTag == site.featureTag
                }
            } else {
                overrides[key] = trimmed
                upsertAddition(
                    table: site.table,
                    featureTag: site.featureTag,
                    string: trimmed,
                    into: &additions
                )
            }
        }

        return (overrides, additions)
    }

    private static func upsertAddition(
        table: String,
        featureTag: String,
        string: String,
        into additions: inout [OTFeatureLabelAddition]
    ) {
        if let index = additions.firstIndex(where: {
            $0.table == table && $0.featureTag == featureTag
        }) {
            additions[index].string = string
        } else {
            additions.append(
                OTFeatureLabelAddition(table: table, featureTag: featureTag, string: string)
            )
        }
        additions.sort {
            if $0.table != $1.table { return $0.table < $1.table }
            return $0.featureTag < $1.featureTag
        }
    }
}
