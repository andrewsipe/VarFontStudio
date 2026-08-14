import Foundation

/// Detects Univers-style classification codes glued to fvar instance names.
///
/// Codes are a naming strategy, not a STAT field. Import never writes `stop.code`
/// or enables `@code`. Detection is for (1) telling the user and (2) stripping the
/// prefix so peeled stop names stay `Condensed`, not `211 Condensed`.
public enum InstanceCodedNaming {
    public struct Detection: Equatable, Sendable {
        /// Distinct prefixes found, sorted, capped for display.
        public var prefixes: [String]
        public var matchedCount: Int
        public var namedCount: Int

        public var message: String {
            let shown = prefixes.prefix(4).joined(separator: ", ")
            let ellipsis = prefixes.count > 4 ? "…" : ""
            return "Instance names look coded (\(shown)\(ellipsis)). "
                + "Stop names were seeded without that prefix. "
                + "Recreate codes with the Code tool if you want them in composed instance names."
        }
    }

    /// True when most named instances share a short digit-bearing prefix that varies.
    public static func detect(names: [String]) -> Detection? {
        let named = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard named.count >= 2 else { return nil }

        let prefixes = named.compactMap(leadingCodePrefix)
        guard prefixes.count * 2 >= named.count else { return nil }

        let unique = Array(Set(prefixes)).sorted()
        guard unique.count >= 2 else { return nil }

        return Detection(
            prefixes: Array(unique.prefix(8)),
            matchedCount: prefixes.count,
            namedCount: named.count
        )
    }

    public static func detect(instances: [FontAnalysis.ExistingInstance]) -> Detection? {
        detect(names: instances.map(\.composedName))
    }

    /// Drop a detected code prefix. Returns the original string when none is present
    /// or when stripping would leave nothing.
    public static func stripPrefix(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = leadingCodePrefix(trimmed),
              trimmed.hasPrefix(prefix) else { return trimmed }
        let rest = String(trimmed.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? trimmed : rest
    }

    /// Copy of `analysis` whose instance composed names have code prefixes removed.
    /// Used only for peeling / clustering — STAT records and the callout keep originals.
    public static func peelAnalysis(
        _ analysis: FontAnalysis,
        detection: Detection?
    ) -> FontAnalysis {
        guard detection != nil else { return analysis }
        var copy = analysis
        copy.instancesExisting = analysis.instancesExisting.map { instance in
            var next = instance
            next.composedName = stripPrefix(instance.composedName)
            return next
        }
        return copy
    }

    /// 1–4 alphanumeric characters containing a digit, then whitespace + a letter
    /// (`211 Condensed`), or 1–4 leading digits glued to a letter (`211Condensed`).
    static func leadingCodePrefix(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let space = trimmed.firstIndex(of: " ") {
            let token = String(trimmed[..<space])
            let rest = trimmed[trimmed.index(after: space)...]
                .trimmingCharacters(in: .whitespaces)
            if isCodeToken(token), rest.first?.isLetter == true {
                return token
            }
        }
        let digits = trimmed.prefix { $0.isNumber }
        if (1...4).contains(digits.count),
           digits.count < trimmed.count {
            let next = trimmed[trimmed.index(trimmed.startIndex, offsetBy: digits.count)]
            if next.isLetter {
                return String(digits)
            }
        }
        return nil
    }

    private static func isCodeToken(_ token: String) -> Bool {
        guard (1...4).contains(token.count) else { return false }
        guard token.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        return token.contains(where: \.isNumber)
    }
}
