import Foundation

/// Hybrid name-policy fills for the Names panel.
///
/// - **1 / 4 / 16 / 17:** FontCore variable-filename slot builders
/// - **3 / 6:** FontNameID defaults (sanitized on-disk filename stem)
/// - **2:** RIBBI from OS/2, head, post, and registration cues
/// - **5:** `Version x.xxx` from head.fontRevision (with name-table fallbacks)
/// - **0 / 7:** Attribution derived from IDs 8/9 and family metadata
/// - **25:** Studio `familyPSPrefix` (FontNameID has no ID25 replacer)
public enum NamePolicies {
    public struct FillContext: Equatable, Sendable {
        public var sourcePath: String
        public var isVariable: Bool
        public var isItalic: Bool
        public var familyName: String
        public var typographicFamily: String?
        public var familyPSPrefix: String?
        public var postscriptName: String?
        public var versionString: String?
        public var uniqueID: String?
        public var vendorID: String
        public var copyright: String?
        public var manufacturer: String?
        public var designer: String?
        public var fontRevision: Double?
        public var headCreatedYear: Int?
        public var fsSelection: UInt16?
        public var usWeightClass: UInt16?
        public var headMacStyle: UInt16?
        public var slots: VariableFilenameSlots?
        /// `file_stat_registration["ital"]` when ital is a registration axis for this file.
        public var italRegistrationValue: Double?
        /// `post.italicAngle` (counter-clockwise degrees).
        public var postItalicAngle: Double?
        /// True when this file registers an italic-like slope stop (legacy name kept for FillContext API).
        public var hasSlopeClarifier: Bool

        public init(
            sourcePath: String,
            isVariable: Bool,
            isItalic: Bool = false,
            familyName: String,
            typographicFamily: String? = nil,
            familyPSPrefix: String? = nil,
            postscriptName: String? = nil,
            versionString: String? = nil,
            uniqueID: String? = nil,
            vendorID: String = "UKWN",
            copyright: String? = nil,
            manufacturer: String? = nil,
            designer: String? = nil,
            fontRevision: Double? = nil,
            headCreatedYear: Int? = nil,
            fsSelection: UInt16? = nil,
            usWeightClass: UInt16? = nil,
            headMacStyle: UInt16? = nil,
            slots: VariableFilenameSlots? = nil,
            italRegistrationValue: Double? = nil,
            postItalicAngle: Double? = nil,
            hasSlopeClarifier: Bool = false
        ) {
            self.sourcePath = sourcePath
            self.isVariable = isVariable
            self.isItalic = isItalic
            self.familyName = familyName
            self.typographicFamily = typographicFamily
            self.familyPSPrefix = familyPSPrefix
            self.postscriptName = postscriptName
            self.versionString = versionString
            self.uniqueID = uniqueID
            self.vendorID = vendorID
            self.copyright = copyright
            self.manufacturer = manufacturer
            self.designer = designer
            self.fontRevision = fontRevision
            self.headCreatedYear = headCreatedYear
            self.fsSelection = fsSelection
            self.usWeightClass = usWeightClass
            self.headMacStyle = headMacStyle
            self.slots = slots ?? VariableFilenameSlots.parse(filenameOrPath: sourcePath)
            self.italRegistrationValue = italRegistrationValue
            self.postItalicAngle = postItalicAngle
            self.hasSlopeClarifier = hasSlopeClarifier
        }

        public static func from(
            analysis: FontAnalysis,
            font: FontDocument
        ) -> FillContext {
            let byID = Dictionary(
                uniqueKeysWithValues: analysis.windowsNameTable.map { ($0.nameID, $0.string) }
            )
            func effectiveName(_ nameID: Int) -> String? {
                let key = WindowsNameTableEditing.overrideKey(nameID)
                if let override = font.windowsNameOverrides[key] {
                    let value = override.trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
                return byID[nameID]
            }
            let hasItalRegistrationAxis = font.axes.contains {
                $0.tag == "ital" && $0.isDesignRecordOnly
            }
            let italReg: Double? = {
                guard hasItalRegistrationAxis else { return nil }
                return font.fileStatRegistration["ital"]
            }()
            let slopeFromRegistration: Bool = {
                if let italReg, AxisCoordinate.valuesEqual(italReg, 1) { return true }
                if let slnt = font.fileStatRegistration["slnt"],
                   let axis = font.axes.first(where: { $0.tag == "slnt" && $0.isDesignRecordOnly }),
                   let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: slnt),
                   RegistrationAxisSupport.isItalicLikeStopName(stop.name) {
                    return true
                }
                return false
            }()
            return FillContext(
                sourcePath: analysis.source.path,
                isVariable: analysis.source.isVariable,
                isItalic: analysis.inferred.isItalicFont,
                familyName: effectiveName(1) ?? analysis.source.familyName,
                typographicFamily: effectiveName(16),
                familyPSPrefix: font.options.familyPSPrefix ?? analysis.source.familyPSPrefix,
                postscriptName: effectiveName(6) ?? analysis.source.postscriptName,
                versionString: effectiveName(5),
                uniqueID: effectiveName(3),
                vendorID: analysis.inferred.vendorID
                    ?? vendorFromUniqueID(effectiveName(3))
                    ?? "UKWN",
                copyright: effectiveName(0),
                manufacturer: effectiveName(8),
                designer: effectiveName(9),
                fontRevision: analysis.inferred.fontRevision,
                headCreatedYear: analysis.inferred.headCreatedYear,
                fsSelection: analysis.inferred.fsSelection,
                usWeightClass: analysis.inferred.usWeightClass,
                headMacStyle: analysis.inferred.headMacStyle,
                italRegistrationValue: italReg,
                postItalicAngle: analysis.inferred.postItalicAngle,
                hasSlopeClarifier: slopeFromRegistration
            )
        }

        /// Backward-compatible helper when only analysis + PS prefix are available.
        public static func from(
            analysis: FontAnalysis,
            familyPSPrefix: String?
        ) -> FillContext {
            let byID = Dictionary(
                uniqueKeysWithValues: analysis.windowsNameTable.map { ($0.nameID, $0.string) }
            )
            return FillContext(
                sourcePath: analysis.source.path,
                isVariable: analysis.source.isVariable,
                isItalic: analysis.inferred.isItalicFont,
                familyName: analysis.source.familyName,
                typographicFamily: byID[16],
                familyPSPrefix: familyPSPrefix ?? analysis.source.familyPSPrefix,
                postscriptName: analysis.source.postscriptName ?? byID[6],
                versionString: byID[5],
                uniqueID: byID[3],
                vendorID: analysis.inferred.vendorID ?? vendorFromUniqueID(byID[3]) ?? "UKWN",
                copyright: byID[0],
                manufacturer: byID[8],
                designer: byID[9],
                fontRevision: analysis.inferred.fontRevision,
                headCreatedYear: analysis.inferred.headCreatedYear,
                fsSelection: analysis.inferred.fsSelection,
                usWeightClass: analysis.inferred.usWeightClass,
                headMacStyle: analysis.inferred.headMacStyle,
                postItalicAngle: analysis.inferred.postItalicAngle
            )
        }
    }

    public struct Suggestion: Equatable, Sendable {
        public var nameID: Int
        public var value: String
        public var source: String
    }

    public static func suggestions(for context: FillContext) -> [Suggestion] {
        var out: [Suggestion] = []

        out.append(Suggestion(
            nameID: 0,
            value: buildID0(context),
            source: "ID0: head.created + name IDs 8/9"
        ))

        out.append(Suggestion(
            nameID: 2,
            value: buildID2(context),
            source: id2Source(context)
        ))

        if context.isVariable {
            if let id1 = buildID1(context), !id1.isEmpty {
                out.append(Suggestion(nameID: 1, value: id1, source: "VF slots → ID1 (root; no Variable)"))
            }
            if let id4 = buildID4(context), !id4.isEmpty {
                out.append(Suggestion(nameID: 4, value: id4, source: "VF slots → ID4 (root + Variable)"))
            }
            if let id16 = buildID16(context), !id16.isEmpty {
                out.append(Suggestion(nameID: 16, value: id16, source: "VF slots → ID16 ({root} Variable)"))
            }
            out.append(Suggestion(
                nameID: 17,
                value: buildID17(context),
                source: "VF slots → ID17"
            ))
        }

        if let version = formattedVersion(from: context) {
            out.append(Suggestion(
                nameID: 5,
                value: version,
                source: "build_id5_version_string"
            ))
            let stem = filenameStemSanitized(context)
            if !stem.isEmpty {
                let verNum = versionNumberOnly(version)
                out.append(Suggestion(
                    nameID: 3,
                    value: "\(verNum);\(paddedVendor(context.vendorID));\(stem)",
                    source: "FontNameID ID3: version; vendor; filename stem"
                ))
            }
        }

        if let id6 = buildID6(context), !id6.isEmpty {
            out.append(Suggestion(
                nameID: 6,
                value: id6,
                source: "FontNameID ID6: sanitized filename stem"
            ))
        }

        if let id7 = buildID7(context), !id7.isEmpty {
            out.append(Suggestion(
                nameID: 7,
                value: id7,
                source: "ID7: family + name IDs 8/9"
            ))
        }

        if let prefix = inferredPSPrefix(context), !prefix.isEmpty {
            out.append(Suggestion(
                nameID: 25,
                value: prefix,
                source: "Infer ID 25 / family PS prefix"
            ))
        }

        return out.sorted { $0.nameID < $1.nameID }
    }

    public static func suggestion(nameID: Int, context: FillContext) -> Suggestion? {
        suggestions(for: context).first { $0.nameID == nameID }
    }

    // MARK: - Builders

    public static func buildID0(_ context: FillContext) -> String {
        let year = context.headCreatedYear
            ?? copyrightYear(in: context.copyright)
            ?? Calendar.current.component(.year, from: Date())
        return "Copyright © \(year) by \(rightsHolder(context)). All rights reserved."
    }

    /// FontNameID ID2 RIBBI mapping from binary metrics and registration cues.
    public static func buildID2(_ context: FillContext) -> String {
        let bold = context.usWeightClass == 700
        let italic = isFixedItalicFile(context)
        switch (bold, italic) {
        case (true, true): return "Bold Italic"
        case (true, false): return "Bold"
        case (false, true): return "Italic"
        case (false, false): return "Regular"
        }
    }

    /// `build_id1_from_variable_slots`: root + optical + width (no Variable).
    public static func buildID1(_ context: FillContext) -> String? {
        if let slots = context.slots {
            return joinNonEmpty(slots.rootFamily, slots.optical, slots.width)
        }
        let root = displayRootFamily(context)
        return root.isEmpty ? nil : root
    }

    /// `build_id4_from_variable_slots`: ID1 + Variable + bespoke + non-elided slope.
    public static func buildID4(_ context: FillContext) -> String? {
        guard let base = buildID1(context), !base.isEmpty else { return nil }
        if let slots = context.slots {
            let slope = VariableFilenameSlots.isElidableSlope(slots.slope) ? nil : slots.slope
            return joinNonEmpty(base, "Variable", slots.bespoke, slope)
        }
        let slope = isFixedItalicFile(context) ? "Italic" : nil
        return joinNonEmpty(base, "Variable", slope)
    }

    /// `build_id16_from_variable_slots`: `{root} Variable`.
    public static func buildID16(_ context: FillContext) -> String? {
        let root = context.slots?.rootFamily ?? displayRootFamily(context)
        guard !root.isEmpty else { return nil }
        return joinNonEmpty(root, "Variable")
    }

    /// `build_id17_from_variable_slots`: optical + width + bespoke + slope, else Regular.
    public static func buildID17(_ context: FillContext) -> String {
        if let slots = context.slots {
            let slope = VariableFilenameSlots.isElidableSlope(slots.slope) ? nil : slots.slope
            let out = joinNonEmpty(slots.optical, slots.width, slots.bespoke, slope)
            return out.isEmpty ? "Regular" : out
        }
        return isFixedItalicFile(context) ? "Italic" : "Regular"
    }

    /// FontNameID ID6 default: sanitized on-disk filename stem.
    public static func buildID6(_ context: FillContext) -> String? {
        let stem = filenameStemSanitized(context)
        return stem.isEmpty ? nil : stem
    }

    public static func buildID7(_ context: FillContext) -> String? {
        let family = displayRootFamily(context)
        let fallback = URL(fileURLWithPath: context.sourcePath)
            .deletingPathExtension().lastPathComponent
        let resolved = family.isEmpty
            ? (PostScriptNaming.stripVariableTokens(fallback) ?? fallback)
            : family
        guard !resolved.isEmpty else { return nil }
        return "\(resolved) is a trademark of \(rightsHolder(context))."
    }

    // MARK: - Italic detection (ID2)

    /// Fixed-italic VF / file cues used for ID2 (and fallbacks for 4/17 without slots).
    public static func isFixedItalicFile(_ context: FillContext) -> Bool {
        if let ital = context.italRegistrationValue {
            return AxisCoordinate.valuesEqual(ital, 1)
        }
        if ((context.fsSelection ?? 0) & 0x0001) != 0 {
            return true
        }
        if ((context.headMacStyle ?? 0) & 0x0002) != 0 {
            return true
        }
        if let angle = context.postItalicAngle, abs(angle) > 0.01 {
            return true
        }
        if context.hasSlopeClarifier {
            return true
        }
        return false
    }

    private static func id2Source(_ context: FillContext) -> String {
        if context.usWeightClass == 700, isFixedItalicFile(context) {
            return "ID2: OS/2 weight 700 + italic metrics → Bold Italic"
        }
        if context.usWeightClass == 700 {
            return "ID2: OS/2 weight 700 → Bold"
        }
        if let ital = context.italRegistrationValue, AxisCoordinate.valuesEqual(ital, 1) {
            return "ID2: ital registration = 1 → Italic"
        }
        if ((context.fsSelection ?? 0) & 0x0001) != 0 {
            return "ID2: OS/2.fsSelection italic → Italic"
        }
        if ((context.headMacStyle ?? 0) & 0x0002) != 0 {
            return "ID2: head.macStyle italic → Italic"
        }
        if context.italRegistrationValue == nil,
           let angle = context.postItalicAngle, abs(angle) > 0.01 {
            return "ID2: post.italicAngle ≠ 0 → Italic"
        }
        if context.italRegistrationValue == nil, context.hasSlopeClarifier {
            return "ID2: Slope registration → Italic"
        }
        return "ID2: Regular"
    }

    // MARK: - Helpers

    private static func displayRootFamily(_ context: FillContext) -> String {
        if let root = context.slots?.rootFamily, !root.isEmpty { return root }
        let raw = context.typographicFamily?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? context.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return PostScriptNaming.stripVariableTokens(raw) ?? raw
    }

    private static func inferredPSPrefix(_ context: FillContext) -> String? {
        if let prefix = context.familyPSPrefix?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prefix.isEmpty {
            return PostScriptNaming.sanitizePostscript(prefix)
        }
        return PostScriptPrefixInference.infer(
            nameID25: nil,
            postscriptName: context.postscriptName,
            typographicFamilyName: context.typographicFamily,
            familyName: context.familyName
        )
    }

    /// FontNameID-style third field / ID6: sanitize the basename stem as-is.
    private static func filenameStemSanitized(_ context: FillContext) -> String {
        let url = URL(fileURLWithPath: context.sourcePath)
        let stem = url.deletingPathExtension().lastPathComponent
        return PostScriptNaming.sanitizePostscript(stem)
    }

    private static func formattedVersion(from context: FillContext) -> String? {
        if let revision = context.fontRevision {
            return "Version \(String(format: "%.3f", revision))"
        }
        if let raw = context.versionString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if raw.lowercased().hasPrefix("version") {
                return raw
            }
            return "Version \(formatVersionNumber(raw))"
        }
        if let unique = context.uniqueID, let first = unique.split(separator: ";").first {
            return "Version \(formatVersionNumber(String(first)))"
        }
        return nil
    }

    private static func versionNumberOnly(_ versionString: String) -> String {
        var s = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("version") {
            s = String(s.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return formatVersionNumber(s)
    }

    private static func formatVersionNumber(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(trimmed) else { return trimmed.isEmpty ? "1.000" : trimmed }
        return String(format: "%.3f", number)
    }

    private static func paddedVendor(_ vendor: String) -> String {
        let cleaned = String(vendor.replacingOccurrences(of: "\0", with: " ").prefix(4))
        return cleaned.padding(toLength: 4, withPad: " ", startingAt: 0)
    }

    private static func vendorFromUniqueID(_ unique: String?) -> String? {
        guard let parts = unique?.split(separator: ";"), parts.count >= 2 else { return nil }
        let vendor = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return vendor.isEmpty ? nil : vendor
    }

    private static func rightsHolder(_ context: FillContext) -> String {
        let manufacturer = context.manufacturer?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let designer = context.designer?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !manufacturer.isEmpty, !designer.isEmpty {
            return manufacturer.caseInsensitiveCompare(designer) == .orderedSame
                ? manufacturer
                : "\(manufacturer) & \(designer)"
        }
        if !manufacturer.isEmpty { return manufacturer }
        if !designer.isEmpty { return designer }
        return "designer"
    }

    private static func copyrightYear(in value: String?) -> Int? {
        guard let value,
              let regex = try? NSRegularExpression(
                pattern: "(?i)(?:©|\\(c\\)|copyright)\\s*(?:\\([^)]*\\)\\s*)?(\\d{4})"
              ) else {
            return nil
        }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let yearRange = Range(match.range(at: 1), in: value) else {
            return nil
        }
        return Int(value[yearRange])
    }

    private static func joinNonEmpty(_ parts: String?...) -> String {
        parts.compactMap { part -> String? in
            guard let part, !part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return part.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .joined(separator: " ")
    }
}
