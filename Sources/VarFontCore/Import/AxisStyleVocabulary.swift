import Foundation

/// OpenType style-token families used to detect cross-axis misattribution
/// (e.g. STAT `wght=399 "Wide"`, `slnt=0 "Condensed"`).
///
/// Unknown / custom tokens are treated as compatible — this gate only rejects
/// clear family mismatches so assertive seeding for custom axes stays intact.
public enum AxisStyleVocabulary {
    public enum Family: Equatable, Sendable {
        case weight
        case width
        case slope
        case optical
        case unknown
    }

    /// Elidable neutrals that are axis-specific defaults, not cross-family errors.
    private static let neutrals: Set<String> = [
        "regular", "normal", "roman", "upright", "standard",
    ]

    private static let weightBases: Set<String> = [
        "hairline", "thin", "extralight", "ultralight", "light", "semilight", "demilight",
        "book", "medium", "semibold", "demibold", "bold", "extrabold", "ultrabold",
        "black", "heavy", "extrablack", "ultrablack", "fat",
    ]

    private static let widthBases: Set<String> = [
        "condensed", "compressed", "compact", "narrow", "tight",
        "extended", "expanded", "wide", "extracondensed", "ultracondensed",
        "semicondensed", "semiexpanded", "extraexpanded", "ultraexpanded",
        "extrawide", "ultrawide",
    ]

    private static let slopeBases: Set<String> = [
        "italic", "oblique", "slanted", "slant", "inclined",
        "backslanted", "backslant", "retalic", "cursive", "kursiv",
    ]

    private static let opticalBases: Set<String> = [
        "caption", "display", "text", "poster", "headline", "subhead",
        "title", "deck", "micro", "banner",
    ]

    private static let modifiers: Set<String> = [
        "semi", "demi", "extra", "ultra", "super",
    ]

    public static func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    public static func family(for name: String) -> Family {
        let key = normalize(name)
        guard !key.isEmpty, !neutrals.contains(key) else { return .unknown }

        if matches(key, bases: widthBases) { return .width }
        if matches(key, bases: weightBases) { return .weight }
        if matches(key, bases: slopeBases) { return .slope }
        if matches(key, bases: opticalBases) { return .optical }
        return .unknown
    }

    /// True when `name` is a known style token that does not belong on `axisTag`.
    /// Custom axes are never gated — only standalone OT naming tags (`wght`, `wdth`, …).
    public static func mismatchesAxis(_ name: String, tag: String) -> Bool {
        guard CompoundStatNaming.standaloneNamingTags.contains(tag) else { return false }
        let fam = family(for: name)
        guard fam != .unknown else { return false }
        return !isCompatible(family: fam, withAxisTag: tag)
    }

    public static func isCompatible(_ name: String, withAxisTag tag: String) -> Bool {
        let fam = family(for: name)
        if fam == .unknown { return true }
        return isCompatible(family: fam, withAxisTag: tag)
    }

    public static func isCompatible(family: Family, withAxisTag tag: String) -> Bool {
        switch (family, tag) {
        case (.weight, "wght"): return true
        case (.width, "wdth"): return true
        case (.slope, "slnt"), (.slope, "ital"): return true
        case (.optical, "opsz"): return true
        case (.unknown, _): return true
        default: return false
        }
    }

    /// Span small enough to treat as positional fuzz (off-by-one Regular / Bold drift),
    /// not opsz-compensated shear. Overlapping neighbor clusters are never fuzz.
    public static func isPositionalFuzz(
        span: Double,
        nearestForeignDistance: Double?,
        axisRange: Double
    ) -> Bool {
        guard span > 0 else { return true }
        if let foreign = nearestForeignDistance, foreign.isFinite, foreign <= span {
            return false
        }
        let range = max(axisRange, 1)
        if span <= 2 { return true }
        return (span / range) <= 0.05
    }

    public static func isPositionalFuzz(
        _ cluster: AxisStopClustering.Cluster,
        axisRange: Double
    ) -> Bool {
        isPositionalFuzz(
            span: cluster.span,
            nearestForeignDistance: cluster.nearestForeignDistance,
            axisRange: axisRange
        )
    }

    private static func matches(_ key: String, bases: Set<String>) -> Bool {
        if bases.contains(key) { return true }
        for base in bases {
            guard key.hasSuffix(base), key.count > base.count else { continue }
            let prefix = String(key.dropLast(base.count))
            if modifiers.contains(prefix) { return true }
            // Glued doubles: "ultracondensed", "extralight"
            if bases.contains(prefix) { return true }
            if modifiers.contains(where: { prefix.hasPrefix($0) && bases.contains(String(prefix.dropFirst($0.count))) }) {
                return true
            }
        }
        return false
    }
}
