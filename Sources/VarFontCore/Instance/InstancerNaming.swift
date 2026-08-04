import Foundation

// MARK: - Axis defaults & ordering (DesignAxisRecord-ish)

/// Known OpenType axis defaults used when an instance omits an axis key.
public enum InstancerAxisDefaults {
    public static let values: [String: Double] = [
        "opsz": 0,
        "wdth": 100,
        "wght": 400,
        "slnt": 0,
        "ital": 0,
    ]

    public static func value(for tag: String) -> Double {
        values[tag] ?? 0
    }
}

/// Sort priority matching DesignAxisRecord convention: opsz → wdth → wght → slope/ital.
public enum InstancerAxisOrder {
    private static let known = ["opsz", "wdth", "wght", "slnt", "ital"]

    public static func priority(_ tag: String) -> Int {
        known.firstIndex(of: tag) ?? known.count
    }

    public static func sortedTags<S: Sequence>(_ tags: S) -> [String] where S.Element == String {
        Array(tags).sorted { a, b in
            let pa = priority(a), pb = priority(b)
            if pa != pb { return pa < pb }
            return a < b
        }
    }
}

// MARK: - Collision / naming status

public enum InstancerCollisionKind: String, Equatable, Sendable, Comparable {
    /// Different coordinates, same resolved name — filename overwrite risk.
    case collision
    /// Same coordinates, different names — identical designs under different labels.
    case identical
    /// Same coordinates and same name — plain duplication.
    case exact

    private var rank: Int {
        switch self {
        case .collision: return 1
        case .identical: return 2
        case .exact: return 3
        }
    }

    public static func < (lhs: InstancerCollisionKind, rhs: InstancerCollisionKind) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum InstancerRowOrigin: String, Equatable, Sendable {
    case source
    case custom
}

/// One editable/static-output row in the Instancer window.
public struct InstancerRow: Equatable, Identifiable, Sendable {
    public var id: String
    public var origin: InstancerRowOrigin
    /// fvar subfamily string when present / usable.
    public var fvarName: String?
    /// Whether `fvarName` is considered usable (non-empty after trim).
    public var fvarUsable: Bool
    /// Composed STAT Axis Value name at this location, if resolvable.
    public var statName: String?
    public var coords: [String: Double]
    public var isBold: Bool
    public var isItalic: Bool
    /// Session-only name override (static file scoped).
    public var nameOverride: String?

    public init(
        id: String,
        origin: InstancerRowOrigin = .source,
        fvarName: String?,
        fvarUsable: Bool,
        statName: String?,
        coords: [String: Double],
        isBold: Bool,
        isItalic: Bool,
        nameOverride: String? = nil
    ) {
        self.id = id
        self.origin = origin
        self.fvarName = fvarName
        self.fvarUsable = fvarUsable
        self.statName = statName
        self.coords = coords
        self.isBold = isBold
        self.isItalic = isItalic
        self.nameOverride = nameOverride
    }
}

public enum InstancerRIBBI: String, Equatable, Sendable {
    case regular = "Regular"
    case italic = "Italic"
    case bold = "Bold"
    case boldItalic = "Bold Italic"
}

public enum InstancerNaming {
    /// fvar-first; override wins; STAT silent fallback; last resort nil (caller treats as will-fail).
    public static func resolvedName(for row: InstancerRow) -> String? {
        if let override = row.nameOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            return override
        }
        if row.fvarUsable, let fvar = row.fvarName?.trimmingCharacters(in: .whitespacesAndNewlines), !fvar.isEmpty {
            return fvar
        }
        if let stat = row.statName?.trimmingCharacters(in: .whitespacesAndNewlines), !stat.isEmpty {
            return stat
        }
        return nil
    }

    public static func usesSTATFallback(_ row: InstancerRow) -> Bool {
        guard row.nameOverride == nil else { return false }
        if row.fvarUsable { return false }
        guard let stat = row.statName?.trimmingCharacters(in: .whitespacesAndNewlines), !stat.isEmpty else {
            return false
        }
        return true
    }

    /// No usable fvar and no STAT Axis Value coverage — fontTools `updateFontNames` would raise.
    public static func willFail(_ row: InstancerRow) -> Bool {
        resolvedName(for: row) == nil
    }

    public static func ribbi(isBold: Bool, isItalic: Bool) -> InstancerRIBBI {
        switch (isBold, isItalic) {
        case (true, true): return .boldItalic
        case (true, false): return .bold
        case (false, true): return .italic
        case (false, false): return .regular
        }
    }

    public static func ribbi(for row: InstancerRow) -> InstancerRIBBI {
        ribbi(isBold: row.isBold, isItalic: row.isItalic)
    }

    /// Filename stem style token (spaces stripped), e.g. `SemiBold`.
    public static func outputStyleToken(for row: InstancerRow) -> String? {
        resolvedName(for: row)?.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }

    public static func outputFileName(psPrefix: String, row: InstancerRow, ext: String = "ttf") -> String? {
        guard let style = outputStyleToken(for: row) else { return nil }
        let prefix = psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return "\(style).\(ext)" }
        return "\(prefix)-\(style).\(ext)"
    }

    /// Fully specified coordinate fingerprint across `axisTags` (defaults fill missing keys).
    public static func coordsKey(_ coords: [String: Double], axisTags: [String]) -> String {
        axisTags.map { tag in
            let value = coords[tag] ?? InstancerAxisDefaults.value(for: tag)
            return "\(tag)=\(formatCoord(value))"
        }.joined(separator: ",")
    }

    public static func formatCoord(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%g", value)
    }

    public static func compareRows(_ a: InstancerRow, _ b: InstancerRow, axisTags: [String]) -> Bool {
        for tag in axisTags {
            let av = a.coords[tag] ?? InstancerAxisDefaults.value(for: tag)
            let bv = b.coords[tag] ?? InstancerAxisDefaults.value(for: tag)
            if !AxisCoordinate.valuesEqual(av, bv) {
                return av < bv
            }
        }
        return a.id < b.id
    }

    /// Worst collision kind per row id among the given rows.
    /// Groups by coordinate fingerprint and resolved name (near-linear; not pairwise n²).
    public static func classifyCollisions(rows: [InstancerRow], axisTags: [String]) -> [String: InstancerCollisionKind] {
        var result: [String: InstancerCollisionKind] = [:]
        guard rows.count > 1 else { return result }

        func raise(_ id: String, _ kind: InstancerCollisionKind) {
            if let existing = result[id] {
                result[id] = max(existing, kind)
            } else {
                result[id] = kind
            }
        }

        var byCoords: [String: [InstancerRow]] = [:]
        var byName: [String: [InstancerRow]] = [:]
        byCoords.reserveCapacity(rows.count)
        byName.reserveCapacity(rows.count)

        for row in rows {
            let coords = coordsKey(row.coords, axisTags: axisTags)
            byCoords[coords, default: []].append(row)
            if let name = resolvedName(for: row) {
                byName[name, default: []].append(row)
            }
        }

        for group in byCoords.values where group.count > 1 {
            for i in 0..<group.count {
                for j in (i + 1)..<group.count {
                    let a = group[i], b = group[j]
                    let nameA = resolvedName(for: a)
                    let nameB = resolvedName(for: b)
                    let kind: InstancerCollisionKind =
                        (nameA != nil && nameA == nameB) ? .exact : .identical
                    raise(a.id, kind)
                    raise(b.id, kind)
                }
            }
        }

        for group in byName.values where group.count > 1 {
            var distinctCoords = Set<String>()
            distinctCoords.reserveCapacity(group.count)
            for row in group {
                distinctCoords.insert(coordsKey(row.coords, axisTags: axisTags))
                if distinctCoords.count > 1 { break }
            }
            // Same name across different coordinates → filename overwrite risk.
            if distinctCoords.count > 1 {
                for row in group {
                    raise(row.id, .collision)
                }
            }
        }

        return result
    }

    /// First occurrence of each name and each coordinate wins; later matches start deselected.
    public static func defaultSelectedIDs(rows: [InstancerRow], axisTags: [String]) -> Set<String> {
        var seenNames = Set<String>()
        var seenCoords = Set<String>()
        var selected = Set<String>()
        let ordered = rows.sorted { compareRows($0, $1, axisTags: axisTags) }
        for row in ordered {
            let name = resolvedName(for: row) ?? "\u{0}\(row.id)"
            let coords = coordsKey(row.coords, axisTags: axisTags)
            if !seenNames.contains(name) && !seenCoords.contains(coords) {
                selected.insert(row.id)
            }
            seenNames.insert(name)
            seenCoords.insert(coords)
        }
        return selected
    }

    public static func isBlocking(row: InstancerRow, collisions: [String: InstancerCollisionKind]) -> Bool {
        willFail(row) || collisions[row.id] != nil
    }
}

// MARK: - Build from FontAnalysis

public enum InstancerSessionBuilder {
    public struct BuiltSession: Equatable, Sendable {
        public var axisTags: [String]
        public var rows: [InstancerRow]
        public var inferredPSPrefix: String
        /// Typographic family for static name IDs 1/16/4 (Variable/VF tokens stripped).
        public var inferredFamilyName: String
        public var sourceDisplayName: String
        /// Format 3 weight-link target used for Bold RIBBI (nil when the font has no bold style link).
        public var boldLinkedWght: Double?
    }

    public static func build(from analysis: FontAnalysis) -> BuiltSession {
        let axisTags = InstancerAxisOrder.sortedTags(
            Set(analysis.axes.filter { $0.roleInferred != .designRecordOnly }.map(\.tag))
                .union(analysis.instancesExisting.flatMap(\.coords.keys))
        )
        let boldLinkedWght = boldLinkedWeight(from: analysis.statValues)

        let rows: [InstancerRow] = analysis.instancesExisting.enumerated().map { index, instance in
            let fvar = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fvarUsable = !fvar.isEmpty
            let filledCoords = filledCoordinates(instance.coords, axisTags: axisTags, axes: analysis.axes)
            let statName = composeSTATName(coords: filledCoords, analysis: analysis, axisTags: axisTags)
            let (bold, italic) = inferStyleBits(
                coords: filledCoords,
                boldLinkedWght: boldLinkedWght
            )
            return InstancerRow(
                id: instance.key.isEmpty ? "fvar-\(index)" : instance.key,
                origin: .source,
                fvarName: fvar.isEmpty ? nil : fvar,
                fvarUsable: fvarUsable,
                statName: statName,
                coords: filledCoords,
                isBold: bold,
                isItalic: italic
            )
        }

        let inferredPS =
            analysis.source.familyPSPrefix?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
            ?? PostScriptPrefixInference.infer(
                nameID25: nil,
                postscriptName: nil,
                typographicFamilyName: nil,
                familyName: analysis.source.familyName
            )
            ?? "Font"

        let displayName = URL(fileURLWithPath: analysis.source.path).lastPathComponent
        return BuiltSession(
            axisTags: axisTags,
            rows: rows,
            inferredPSPrefix: inferredPS,
            inferredFamilyName: inferredFamilyName(from: analysis),
            sourceDisplayName: displayName.isEmpty ? analysis.source.path : displayName,
            boldLinkedWght: boldLinkedWght
        )
    }

    /// Prefer name ID 16, else ID 1; strip Variable/VF/GX/Flex tokens for static family names.
    public static func inferredFamilyName(from analysis: FontAnalysis) -> String {
        let typo = analysis.windowsNameTable
            .first(where: { $0.nameID == 16 })?
            .string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let family1 = analysis.source.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw: String = {
            if let typo, !typo.isEmpty { return typo }
            return family1
        }()
        guard !raw.isEmpty else { return "Font" }
        let stripped = PostScriptNaming.stripVariableTokens(raw) ?? raw
        let collapsed = stripped
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return collapsed.isEmpty ? raw : collapsed
    }

    public static func filledCoordinates(
        _ coords: [String: Double],
        axisTags: [String],
        axes: [FontAnalysis.AnalyzedAxis]
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        for tag in axisTags {
            if let value = coords[tag] {
                result[tag] = value
            } else if let axis = axes.first(where: { $0.tag == tag }) {
                result[tag] = axis.default
            } else {
                result[tag] = InstancerAxisDefaults.value(for: tag)
            }
        }
        return result
    }

    /// Compose non-elidable STAT Axis Value names at `coords` (DesignAxisRecord order).
    /// Format 4 compounds replace covered axes and emit at the earliest covered tag.
    public static func composeSTATName(
        coords: [String: Double],
        analysis: FontAnalysis,
        axisTags: [String]
    ) -> String? {
        let compounds = analysis.compoundStatValues.map { record in
            CompoundStatValue(
                id: record.id,
                coords: record.coords,
                axisIndices: record.axisIndices,
                axisValues: record.axisValues,
                name: record.name,
                elidable: record.elidable,
                olderSibling: record.olderSibling
            )
        }
        let selected = CompoundStatNaming.selectedMatches(compounds: compounds, coords: coords)
        let plan = CompoundStatNaming.emitPlan(selected: selected, namingOrder: axisTags)

        var parts: [String] = []
        for tag in axisTags {
            if let compound = plan.emitAtTag[tag] {
                guard !compound.elidable else { continue }
                let name = compound.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { parts.append(name) }
                continue
            }
            if plan.claimedTags.contains(tag) { continue }

            guard let target = coords[tag] else { continue }
            guard let record = matchingStatRecord(
                tag: tag,
                value: target,
                in: analysis.statValues
            ), !record.elidable else { continue }
            let name = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                parts.append(name)
            }
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    private static func matchingStatRecord(
        tag: String,
        value: Double,
        in records: [FontAnalysis.StatValueRecord]
    ) -> FontAnalysis.StatValueRecord? {
        records.first { record in
            guard record.tag == tag else { return false }
            if let v = record.value { return AxisCoordinate.valuesEqual(v, value) }
            if let n = record.nominal { return AxisCoordinate.valuesEqual(n, value) }
            if let min = record.rangeMin, let max = record.rangeMax {
                return value + AxisCoordinate.tolerance >= min && value - AxisCoordinate.tolerance <= max
            }
            return false
        }
    }

    public static func inferStyleBits(
        coords: [String: Double],
        boldLinkedWght: Double?
    ) -> (bold: Bool, italic: Bool) {
        let ital = coords["ital"].map { AxisCoordinate.valuesEqual($0, 1) } ?? false
        let slnt = coords["slnt"].map { abs($0) > 0.1 } ?? false
        let italic = ital || slnt

        let wght = coords["wght"] ?? InstancerAxisDefaults.value(for: "wght")
        let bold = boldLinkedWght.map { AxisCoordinate.valuesEqual(wght, $0) } ?? false
        return (bold, italic)
    }

    public static func inferStyleBits(
        coords: [String: Double],
        statValues: [FontAnalysis.StatValueRecord]
    ) -> (bold: Bool, italic: Bool) {
        inferStyleBits(coords: coords, boldLinkedWght: boldLinkedWeight(from: statValues))
    }

    /// Format 3 `wght` link target — the only weight that maps to Bold RIBBI.
    public static func boldLinkedWeight(from statValues: [FontAnalysis.StatValueRecord]) -> Double? {
        for record in statValues where record.tag == "wght" && record.format == 3 {
            if let linked = record.linkedValue { return linked }
        }
        return nil
    }

    /// Bold RIBBI applies only when this weight is the Format 3 link target on `wght`.
    public static func isBoldLinkedWeight(
        _ wght: Double,
        statValues: [FontAnalysis.StatValueRecord]
    ) -> Bool {
        guard let linked = boldLinkedWeight(from: statValues) else { return false }
        return AxisCoordinate.valuesEqual(wght, linked)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
