import Foundation

/// Slim port of FontCore `VariableFilenameSlots` for VF name-policy fills.
public struct VariableFilenameSlots: Equatable, Sendable {
    public var rootFamily: String
    public var optical: String?
    public var width: String?
    public var slope: String?
    public var bespoke: String?

    public init(
        rootFamily: String,
        optical: String? = nil,
        width: String? = nil,
        slope: String? = nil,
        bespoke: String? = nil
    ) {
        self.rootFamily = rootFamily
        self.optical = optical
        self.width = width
        self.slope = slope
        self.bespoke = bespoke
    }

    /// Parse a variable-font filename or path into semantic slots. Returns nil when no VF marker.
    public static func parse(filenameOrPath: String) -> VariableFilenameSlots? {
        let url = URL(fileURLWithPath: filenameOrPath)
        var stem = url.deletingPathExtension().lastPathComponent
        if stem == filenameOrPath || stem.isEmpty {
            stem = (filenameOrPath as NSString).deletingPathExtension
            stem = (stem as NSString).lastPathComponent
        }
        guard containsVariableMarker(stem) else { return nil }

        // Inverted dialect: FamilyVariable-Regular (Variable in family, not subfamily).
        if let inverted = parseInverted(stem: stem) {
            return inverted
        }

        let (familyRaw, subfamilyRaw) = splitFamilySubfamily(stem)
        guard containsVariableMarker(subfamilyRaw) || subfamilyRaw.isEmpty else {
            // Marker only in family stem without inverted pattern — treat whole stem.
            return nil
        }

        let (before, after) = splitOnVariable(subfamilyRaw)
        let width = formatPascalWords(before)
        let root = formatPascalWords(familyRaw) ?? familyRaw
        let (slope, bespoke) = classifyAfterVariable(after)

        return VariableFilenameSlots(
            rootFamily: root.isEmpty ? familyRaw : root,
            optical: nil,
            width: width,
            slope: slope,
            bespoke: bespoke
        )
    }

    public static func isElidableSlope(_ slope: String?) -> Bool {
        guard let slope, !slope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        return elidableDisplaySlopes.contains(slope.lowercased())
    }

    // MARK: - Internals

    private static let elidableDisplaySlopes: Set<String> = [
        "regular", "roman", "normal", "plain", "standard", "upright",
    ]

    private static let slopeCanonical: [String: String] = [
        "italic": "Italic",
        "oblique": "Oblique",
        "slanted": "Slanted",
        "slant": "Slanted",
        "inclined": "Inclined",
        "upright": "Upright",
        "roman": "Roman",
    ]

    private static func containsVariableMarker(_ text: String) -> Bool {
        if text.range(of: "variable", options: .caseInsensitive) != nil { return true }
        if text.range(of: #"\b(?:VF|GX|Flex)\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func splitFamilySubfamily(_ stem: String) -> (String, String) {
        guard let dash = stem.firstIndex(of: "-") else { return (stem, "") }
        let family = String(stem[..<dash])
        let sub = String(stem[stem.index(after: dash)...])
        return (family, sub)
    }

    private static func parseInverted(stem: String) -> VariableFilenameSlots? {
        let (familyRaw, subfamilyRaw) = splitFamilySubfamily(stem)
        guard containsVariableMarker(familyRaw), !containsVariableMarker(subfamilyRaw) else {
            return nil
        }
        var rootRaw = familyRaw
        if let regex = try? NSRegularExpression(pattern: #"(?i)variable"#) {
            let range = NSRange(rootRaw.startIndex..<rootRaw.endIndex, in: rootRaw)
            rootRaw = regex.stringByReplacingMatches(in: rootRaw, range: range, withTemplate: "")
        }
        rootRaw = rootRaw.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        let root = formatPascalWords(rootRaw) ?? rootRaw
        return VariableFilenameSlots(rootFamily: root.isEmpty ? familyRaw : root)
    }

    private static func splitOnVariable(_ subfamily: String) -> (String, String) {
        var s = subfamily.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: #"\b(VF|GX|Flex)\b"#, options: .caseInsensitive) {
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "Variable")
        }
        s = s.replacingOccurrences(of: "-", with: "")
        guard let match = s.range(of: "Variable", options: .caseInsensitive) else {
            return (s, "")
        }
        return (String(s[..<match.lowerBound]), String(s[match.upperBound...]))
    }

    private static func classifyAfterVariable(_ after: String) -> (slope: String?, bespoke: String?) {
        let formatted = formatPascalWords(after) ?? after.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !formatted.isEmpty else { return (nil, nil) }
        let words = formatted.split(separator: " ").map(String.init)
        if words.count == 1 {
            let token = words[0]
            if let canon = slopeCanonical[token.lowercased()] {
                return (canon, nil)
            }
            if elidableDisplaySlopes.contains(token.lowercased()) {
                return (nil, nil)
            }
            return (nil, token)
        }
        if let first = slopeCanonical[words[0].lowercased()], words.count == 1 {
            return (first, nil)
        }
        return (nil, formatted)
    }

    /// Lightweight PascalCase / underscore → spaced words (FontCore `format_pascal_words` subset).
    public static func formatPascalWords(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var result = ""
        let chars = Array(trimmed)
        for (index, ch) in chars.enumerated() {
            if ch == "_" || ch == "-" {
                if !result.hasSuffix(" ") { result.append(" ") }
                continue
            }
            if ch.isUppercase, index > 0 {
                let prev = chars[index - 1]
                let nextIsLower = index + 1 < chars.count && chars[index + 1].isLowercase
                if prev.isLowercase || prev.isNumber || (prev.isUppercase && nextIsLower) {
                    if !result.hasSuffix(" ") { result.append(" ") }
                }
            }
            result.append(ch)
        }
        let collapsed = result
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }
}
