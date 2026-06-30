import Foundation

/// Derives fvar instance PostScript prefix (name ID 25) from the name table.
public enum PostScriptPrefixInference {
    /// Priority: explicit ID 25 → ID 6 stem before first hyphen → family name (ID 1).
    public static func infer(
        nameID25: String?,
        postscriptName: String?,
        familyName: String?
    ) -> String? {
        if let from25 = cleaned(nameID25), isUsablePrefix(from25) {
            return sanitize(from25)
        }
        if let from6 = stemFromPostScriptName(postscriptName), isUsablePrefix(from6) {
            return sanitize(from6)
        }
        if let fromFamily = cleaned(familyName), isUsablePrefix(fromFamily) {
            return sanitize(fromFamily)
        }
        return nil
    }

    private static func stemFromPostScriptName(_ raw: String?) -> String? {
        guard let trimmed = cleaned(raw) else { return nil }
        guard isUsablePrefix(trimmed) else { return nil }
        if let hyphen = trimmed.firstIndex(of: "-") {
            let stem = String(trimmed[..<hyphen])
            return stem.isEmpty ? nil : stem
        }
        return trimmed
    }

    private static func isUsablePrefix(_ value: String) -> Bool {
        if value.isEmpty { return false }
        if value.contains("?") || value.contains(".") { return false }
        return true
    }

    private static func cleaned(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sanitize(_ value: String) -> String {
        let compact = value.replacingOccurrences(of: " ", with: "")
        guard let regex = try? NSRegularExpression(pattern: #"[^A-Za-z0-9\-._?!&*]"#) else {
            return compact
        }
        let range = NSRange(compact.startIndex..<compact.endIndex, in: compact)
        return regex.stringByReplacingMatches(in: compact, range: range, withTemplate: "-")
    }
}
