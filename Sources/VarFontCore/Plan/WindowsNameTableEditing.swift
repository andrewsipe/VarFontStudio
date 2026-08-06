import Foundation

/// Effective Windows name-table rows for the Names panel (IDs 0–25).
public enum WindowsNameTableEditing {
    /// Required family identity records — never removable from the Names panel.
    public static let protectedFromRemoval: Set<Int> = [1, 2, 4, 6]

    /// Safe to remove, but important enough that the UI should discourage it.
    public static let removalDiscouraged: Set<Int> = [3, 5, 16, 17]

    public struct Row: Equatable, Sendable, Identifiable {
        public var nameID: Int
        public var label: String
        public var value: String
        public var isOverride: Bool
        public var isLinkedToPSPrefix: Bool

        public var id: Int { nameID }
    }

    public static func analysisString(
        nameID: Int,
        windowsNameTable: [WindowsNameRecord]
    ) -> String? {
        windowsNameTable.first(where: { $0.nameID == nameID })?.string
    }

    public static func overrideKey(_ nameID: Int) -> String { String(nameID) }

    public static func canRemove(nameID: Int) -> Bool {
        OpenTypeNameTable.editableLowNameIDs.contains(nameID)
            && !protectedFromRemoval.contains(nameID)
    }

    /// Tooltip / confirmation copy for the remove control.
    public static func removeHelp(nameID: Int) -> String {
        switch nameID {
        case 3:
            return """
            Not recommended — Unique ID is used by installers and font managers to \
            distinguish this face. Remove nameID 3 only if you are sure.
            """
        case 5:
            return """
            Not recommended — Version string is how apps and validators report revision. \
            Remove nameID 5 only if you are sure.
            """
        case 16:
            return """
            Not recommended — Typographic Family groups non-RIBBI styles in menus. \
            Remove nameID 16 only if you are sure.
            """
        case 17:
            return """
            Not recommended — Typographic Subfamily pairs with ID 16 for style naming. \
            Remove nameID 17 only if you are sure.
            """
        case 25:
            return """
            Remove nameID 25 from the exported font. Studio keeps the PostScript prefix \
            for file naming.
            """
        default:
            return "Remove nameID \(nameID) from the name table"
        }
    }

    public static func isRemovalDiscouraged(nameID: Int) -> Bool {
        removalDiscouraged.contains(nameID)
    }

    /// Removal is explicit: only the remove control puts an ID here. Clearing a field
    /// leaves an empty override instead, so the row stays on screen to be retyped.
    public static func isPendingRemoval(nameID: Int, removals: [Int]) -> Bool {
        removals.contains(nameID)
    }

    /// Present rows: analysis records plus any override keys (including empty draft adds).
    /// ID 25 uses `familyPSPrefix` when set, unless it was removed from the export.
    public static func populatedRows(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int],
        familyPSPrefix: String?
    ) -> [Row] {
        var ids = Set(windowsNameTable.map(\.nameID))
        for key in overrides.keys {
            if let id = Int(key), OpenTypeNameTable.editableLowNameIDs.contains(id) {
                ids.insert(id)
            }
        }
        let prefix = familyPSPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasFileID25 = analysisString(nameID: 25, windowsNameTable: windowsNameTable) != nil
        if !removals.contains(25), !prefix.isEmpty || hasFileID25 {
            ids.insert(25)
        }

        return ids.sorted().compactMap { nameID -> Row? in
            guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return nil }
            if isPendingRemoval(nameID: nameID, removals: removals) { return nil }
            if nameID == 25 {
                let analysis = analysisString(nameID: 25, windowsNameTable: windowsNameTable) ?? ""
                let value = prefix.isEmpty ? analysis : prefix
                guard !value.isEmpty || familyPSPrefix != nil else { return nil }
                return Row(
                    nameID: 25,
                    label: OpenTypeNameTable.standardNameLabel(for: 25) ?? "Variations PS Prefix",
                    value: familyPSPrefix ?? analysis,
                    isOverride: familyPSPrefix != nil,
                    isLinkedToPSPrefix: true
                )
            }
            let key = overrideKey(nameID)
            if let overridden = overrides[key] {
                return Row(
                    nameID: nameID,
                    label: OpenTypeNameTable.standardNameLabel(for: nameID) ?? "nameID \(nameID)",
                    value: overridden,
                    isOverride: true,
                    isLinkedToPSPrefix: false
                )
            }
            guard let analysis = analysisString(nameID: nameID, windowsNameTable: windowsNameTable) else {
                return nil
            }
            return Row(
                nameID: nameID,
                label: OpenTypeNameTable.standardNameLabel(for: nameID) ?? "nameID \(nameID)",
                value: analysis,
                isOverride: false,
                isLinkedToPSPrefix: false
            )
        }
    }

    public static func missingNameIDs(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int],
        familyPSPrefix: String?
    ) -> [Int] {
        let present = Set(populatedRows(
            windowsNameTable: windowsNameTable,
            overrides: overrides,
            removals: removals,
            familyPSPrefix: familyPSPrefix
        ).map(\.nameID))
        return OpenTypeNameTable.editableLowNameIDs.filter { !present.contains($0) }
    }

    /// True when a row holds a pending edit that can be discarded in favor of the font file.
    /// Removals are excluded — those rows are gone from the list, and Add ID restores them.
    public static func canRevert(
        nameID: Int,
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int]
    ) -> Bool {
        if removals.contains(nameID) { return false }
        // ID 25's row value comes from `familyPSPrefix`, so its override is never the
        // thing being reverted.
        guard nameID != 25, let override = overrides[overrideKey(nameID)] else { return false }
        return override != analysisString(nameID: nameID, windowsNameTable: windowsNameTable)
    }

    /// Patches for commit: IDs 0–25 that differ from analysis, with deletes as an empty string.
    /// A removal and a cleared value both delete the record — you cannot write an empty name.
    /// ID 25 appears only as an omit (`""`); non-empty ID 25 values come from `familyPSPrefix`.
    public static func commitPatches(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int]
    ) -> [WindowsNameRecord] {
        var patches: [WindowsNameRecord] = []
        let analysisByID = Dictionary(uniqueKeysWithValues: windowsNameTable.map { ($0.nameID, $0.string) })

        for nameID in Set(removals) where OpenTypeNameTable.editableLowNameIDs.contains(nameID) {
            if nameID == 25 || analysisByID[nameID] != nil {
                patches.append(WindowsNameRecord(nameID: nameID, string: ""))
            }
        }

        for (key, value) in overrides {
            guard let nameID = Int(key),
                  OpenTypeNameTable.editableLowNameIDs.contains(nameID),
                  !removals.contains(nameID),
                  nameID != 25 else {
                continue
            }
            let baseline = analysisByID[nameID]
            if baseline == value { continue }
            if baseline == nil, value.isEmpty { continue }
            patches.append(WindowsNameRecord(nameID: nameID, string: value))
        }
        return patches.sorted { $0.nameID < $1.nameID }
    }
}
