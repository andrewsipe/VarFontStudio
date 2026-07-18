import Foundation

/// Effective Windows name-table rows for the Names panel (IDs 0–25).
public enum WindowsNameTableEditing {
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

    /// Present rows: analysis records plus any override keys (including empty draft adds).
    /// ID 25 uses `familyPSPrefix` when set, else analysis ID 25 / inferred prefix.
    public static func populatedRows(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        familyPSPrefix: String?
    ) -> [Row] {
        var ids = Set(windowsNameTable.map(\.nameID))
        for key in overrides.keys {
            if let id = Int(key), OpenTypeNameTable.editableLowNameIDs.contains(id), id != 25 {
                ids.insert(id)
            }
        }
        let prefix = familyPSPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !prefix.isEmpty || analysisString(nameID: 25, windowsNameTable: windowsNameTable) != nil {
            ids.insert(25)
        }

        return ids.sorted().compactMap { nameID -> Row? in
            guard OpenTypeNameTable.editableLowNameIDs.contains(nameID) else { return nil }
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
        familyPSPrefix: String?
    ) -> [Int] {
        let present = Set(populatedRows(
            windowsNameTable: windowsNameTable,
            overrides: overrides,
            familyPSPrefix: familyPSPrefix
        ).map(\.nameID))
        return OpenTypeNameTable.editableLowNameIDs.filter { !present.contains($0) }
    }

    /// Patches for commit: IDs 0–24 that differ from analysis (including deletes as empty string).
    public static func commitPatches(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String]
    ) -> [WindowsNameRecord] {
        var patches: [WindowsNameRecord] = []
        let analysisByID = Dictionary(uniqueKeysWithValues: windowsNameTable.map { ($0.nameID, $0.string) })
        for (key, value) in overrides {
            guard let nameID = Int(key), (0...24).contains(nameID), nameID != 15 else { continue }
            let baseline = analysisByID[nameID]
            if baseline == value { continue }
            if baseline == nil, value.isEmpty { continue }
            patches.append(WindowsNameRecord(nameID: nameID, string: value))
        }
        return patches.sorted { $0.nameID < $1.nameID }
    }
}
