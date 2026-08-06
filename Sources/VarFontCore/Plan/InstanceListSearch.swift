import Foundation

/// Search / filter parsing and match helpers for the Instances list.
public enum InstanceListSearch {
    public enum Query: Equatable, Sendable {
        /// `wdth+wght` / `width+weight+italic` — focus these axis pills (and keep matching instances).
        case axisSet([String])
        /// `wght=400 weight=100` (semantic tags allowed).
        case tagEquals([(tag: String, value: Double)])
        /// Free-text substring against names, key, chain tokens, and captions.
        case text(String)

        public static func == (lhs: Query, rhs: Query) -> Bool {
            switch (lhs, rhs) {
            case (.axisSet(let a), .axisSet(let b)):
                return a == b
            case (.tagEquals(let a), .tagEquals(let b)):
                return a.map(\.tag) == b.map(\.tag)
                    && zip(a, b).allSatisfy { AxisCoordinate.valuesEqual($0.value, $1.value) }
            case (.text(let a), .text(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    /// Built-in OpenType tag aliases (lowercase). Caller-supplied display names layer on top.
    public static let builtInAliases: [String: String] = [
        "weight": "wght",
        "width": "wdth",
        "optical": "opsz",
        "opticalsize": "opsz",
        "optical size": "opsz",
        "size": "opsz",
        "slant": "slnt",
        "italic": "ital",
        "grade": "GRAD",
        "softness": "SOFT",
    ]

    public static func parse(
        _ raw: String,
        displayNameByTag: [String: String] = [:]
    ) -> Query? {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        if query.contains("+"), !query.contains("=") {
            let parts = query.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
            let tags = parts.compactMap { resolveAxisToken(String($0), displayNameByTag: displayNameByTag) }
            if tags.count == parts.count, !tags.isEmpty {
                return .axisSet(tags)
            }
        }

        let eqParts = query.split(whereSeparator: \.isWhitespace).map(String.init)
        if !eqParts.isEmpty {
            var parsed: [(tag: String, value: Double)] = []
            var allEq = true
            for part in eqParts {
                guard let eq = part.firstIndex(of: "=") else {
                    allEq = false
                    break
                }
                let token = String(part[..<eq]).trimmingCharacters(in: .whitespaces)
                let valueText = String(part[part.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                guard let tag = resolveAxisToken(token, displayNameByTag: displayNameByTag),
                      let value = Double(valueText) else {
                    allEq = false
                    break
                }
                parsed.append((tag, value))
            }
            if allEq, !parsed.isEmpty {
                return .tagEquals(parsed)
            }
        }

        return .text(query)
    }

    public static func resolveAxisToken(
        _ raw: String,
        displayNameByTag: [String: String] = [:]
    ) -> String? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }
        let lower = token.lowercased()

        // Exact OpenType tag (case-insensitive for registered lowercase tags; preserve GRAD etc.)
        if token.count == 4, token.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
            if let builtIn = builtInAliases[lower] { return builtIn }
            // Prefer canonical casing from display-name map keys when present.
            if let exact = displayNameByTag.keys.first(where: { $0.caseInsensitiveCompare(token) == .orderedSame }) {
                return exact
            }
            return token
        }

        if let builtIn = builtInAliases[lower] { return builtIn }

        for (tag, name) in displayNameByTag {
            if name.lowercased() == lower { return tag }
        }
        return nil
    }

    /// Whether `instance` matches the parsed query.
    public static func matches(
        _ instance: PlannedInstance,
        query: Query,
        coordCaption: String? = nil
    ) -> Bool {
        switch query {
        case .axisSet(let tags):
            return tags.allSatisfy { instance.coords[$0] != nil }
        case .tagEquals(let preds):
            return preds.allSatisfy { pred in
                guard let value = instance.coords[pred.tag] else { return false }
                return AxisCoordinate.valuesEqual(value, pred.value)
            }
        case .text(let text):
            let q = text.lowercased()
            if instance.composedName.lowercased().contains(q) { return true }
            if instance.key.lowercased().contains(q) { return true }
            if let caption = coordCaption?.lowercased(), caption.contains(q) { return true }
            if instance.namingChain.contains(where: { $0.name.lowercased().contains(q) }) { return true }
            // Also allow tag=value fragments against live coords.
            for (tag, value) in instance.coords {
                let pair = "\(tag)=\(AxisCoordinateFormat.format(value))".lowercased()
                if pair.contains(q) { return true }
            }
            return false
        }
    }

    /// Tags focused by an axis-set query (for narrowing pills); nil otherwise.
    public static func axisFocus(for query: Query?) -> [String]? {
        guard case .axisSet(let tags) = query else { return nil }
        return tags
    }
}

/// Helpers for Instances list coordinate pills.
public enum InstanceCoordPresentation {
    /// Axes whose values are equal across every instance in the group (among `enabledTags`).
    public static func groupSharedAxes(
        instances: [PlannedInstance],
        enabledTags: [String]
    ) -> [String] {
        guard let first = instances.first, !enabledTags.isEmpty else { return [] }
        return enabledTags.filter { tag in
            guard let baseline = first.coords[tag] else { return false }
            return instances.allSatisfy { instance in
                guard let value = instance.coords[tag] else { return false }
                return AxisCoordinate.valuesEqual(value, baseline)
            }
        }
    }

    /// How many fixed-width pills fit in `availableWidth` (including inter-pill gaps).
    public static func pillBudget(
        availableWidth: Double,
        pillWidth: Double,
        gap: Double = 4
    ) -> Int {
        guard availableWidth > 0, pillWidth > 0 else { return 0 }
        if availableWidth < pillWidth { return 0 }
        return max(1, Int(floor((availableWidth + gap) / (pillWidth + gap))))
    }

    /// Ordered pill tags for a row: enabled − shared, intersected with optional search focus.
    public static func rowAxisTags(
        enabledTags: [String],
        sharedTags: [String],
        searchFocus: [String]?
    ) -> [String] {
        let shared = Set(sharedTags)
        let base = enabledTags.filter { !shared.contains($0) }
        guard let focus = searchFocus, !focus.isEmpty else { return base }
        let focusSet = Set(focus)
        return base.filter { focusSet.contains($0) }
    }
}
