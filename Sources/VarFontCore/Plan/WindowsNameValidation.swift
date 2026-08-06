import Foundation

/// Empty / placeholder detection for Windows name-table values.
///
/// Mirrors FontCore `coerce_usable_nametable_string`: a value counts as real content only
/// when it still holds a letter or digit after invisible marks are stripped. That catches
/// the cases fonts ship by accident — a lone `.`, a DEL or zero-width character, or a
/// leftover word like "Untitled".
public enum WindowsNameValidation {
    /// IDs a shipping font needs; same set the panel protects from removal.
    public static var requiredNameIDs: Set<Int> { WindowsNameTableEditing.protectedFromRemoval }

    /// Whole-value words that mean "nobody filled this in".
    static let placeholderWords: Set<String> = [
        "?", "n/a", "na", "none", "null", "nil", "unknown", "undefined",
        "untitled", "unnamed", "new font", "myfont", "my font", "font",
        "placeholder", "sample", "test", "todo", "tbd", "xxx", ".notdef",
    ]

    public enum Problem: String, Equatable, Sendable {
        /// Required ID absent from the name table.
        case missing
        /// Required ID exists in the file but was cleared, so save would delete it.
        case cleared
        /// Present but blank once trimmed.
        case empty
        /// Non-blank but carries no real content (punctuation-only or a placeholder word).
        case placeholder
        /// Real content, but with control / zero-width characters embedded.
        case controlCharacters
    }

    public struct Issue: Equatable, Sendable, Identifiable {
        public var nameID: Int
        public var problem: Problem
        public var isRequired: Bool
        public var label: String
        public var message: String

        public var id: Int { nameID }

        public init(nameID: Int, problem: Problem, isRequired: Bool, label: String, message: String) {
            self.nameID = nameID
            self.problem = problem
            self.isRequired = isRequired
            self.label = label
            self.message = message
        }
    }

    /// Control, DEL, and zero-width marks that read as blank but survive round-trips.
    private static let invisibles: CharacterSet = {
        var set = CharacterSet.controlCharacters
        set.insert(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}")
        return set
    }()

    /// Value with invisible marks removed and outer whitespace trimmed.
    public static func normalized(_ raw: String) -> String {
        raw.components(separatedBy: invisibles)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func containsInvisibleCharacters(_ raw: String) -> Bool {
        raw.rangeOfCharacter(from: invisibles) != nil
    }

    /// True when the string carries content a user would recognize as a real name.
    public static func isUsable(_ raw: String) -> Bool {
        let value = normalized(raw)
        guard !value.isEmpty else { return false }
        guard value.rangeOfCharacter(from: .alphanumerics) != nil else { return false }
        return !placeholderWords.contains(value.lowercased())
    }

    public static func classify(_ raw: String) -> Problem? {
        let value = normalized(raw)
        if value.isEmpty {
            return .empty
        }
        if value.rangeOfCharacter(from: .alphanumerics) == nil
            || placeholderWords.contains(value.lowercased()) {
            return .placeholder
        }
        return containsInvisibleCharacters(raw) ? .controlCharacters : nil
    }

    public static func message(for problem: Problem, nameID: Int, isRequired: Bool) -> String {
        switch problem {
        case .missing:
            return "Required record is missing — nameID \(nameID) will not be in the exported font."
        case .cleared:
            return "Required record was cleared — saving deletes nameID \(nameID) from the font."
        case .empty:
            let tail = isRequired
                ? "Required record is empty"
                : "Value is empty"
            return "\(tail) — nameID \(nameID) will not be written on save."
        case .placeholder:
            return "Value has no letters or digits — looks like placeholder content, not a real name."
        case .controlCharacters:
            return "Value contains invisible or control characters that should be removed."
        }
    }

    /// Issues across the panel's current state: unusable values on visible rows, plus any
    /// required ID that is gone — either never in the file (`missing`) or cleared by an
    /// edit that would delete it on save (`cleared`). Required issues sort first.
    public static func issues(
        windowsNameTable: [WindowsNameRecord],
        overrides: [String: String],
        removals: [Int],
        familyPSPrefix: String?
    ) -> [Issue] {
        let rows = WindowsNameTableEditing.populatedRows(
            windowsNameTable: windowsNameTable,
            overrides: overrides,
            removals: removals,
            familyPSPrefix: familyPSPrefix
        )
        var issues = rows.compactMap { row -> Issue? in
            guard let problem = classify(row.value) else { return nil }
            return makeIssue(nameID: row.nameID, problem: problem, label: row.label)
        }

        let present = Set(rows.map(\.nameID))
        for nameID in requiredNameIDs.sorted() where !present.contains(nameID) {
            let wasCleared = WindowsNameTableEditing.analysisString(
                nameID: nameID,
                windowsNameTable: windowsNameTable
            ) != nil
            issues.append(makeIssue(nameID: nameID, problem: wasCleared ? .cleared : .missing))
        }

        return issues.sorted { lhs, rhs in
            if lhs.isRequired != rhs.isRequired { return lhs.isRequired }
            return lhs.nameID < rhs.nameID
        }
    }

    private static func makeIssue(nameID: Int, problem: Problem, label: String? = nil) -> Issue {
        let isRequired = requiredNameIDs.contains(nameID)
        return Issue(
            nameID: nameID,
            problem: problem,
            isRequired: isRequired,
            label: label ?? OpenTypeNameTable.standardNameLabel(for: nameID) ?? "nameID \(nameID)",
            message: message(for: problem, nameID: nameID, isRequired: isRequired)
        )
    }
}
