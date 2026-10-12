import Foundation

/// A name-table string that carries no information. A lone period is filler, the same as blank.
/// A real family such as "HT" is left alone.
public enum NameFiller {
    public static func isFiller(_ raw: String) -> Bool {
        meaningful(raw) == nil
    }

    public static func meaningful(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "." else { return nil }
        return trimmed
    }
}

/// `{Family}-Variable` filenames: one hyphen means the family is the stub before it.
/// No hyphen, or more than one, leaves the name table in charge.
public enum FilenameFamily {
    public static func singleHyphenStub(filenameOrPath: String) -> String? {
        let stem = URL(fileURLWithPath: filenameOrPath).deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { return nil }
        let stub = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        return stub.isEmpty ? nil : stub
    }

    /// Filename stub when the stem has exactly one hyphen; otherwise the recorded family.
    public static func preferred(filenameOrPath: String, recordedFamily: String?) -> String? {
        if let stub = singleHyphenStub(filenameOrPath: filenameOrPath) {
            return stub
        }
        return NameFiller.meaningful(recordedFamily)
    }

    public struct ImportNaming: Equatable, Sendable {
        public var overrides: [String: String]
        public var familyPSPrefix: String?
    }

    /// Name IDs 1 and 16, and the PS prefix, follow the filename stub when it wins.
    /// A distinct name ID 25 is left alone.
    public static func importNaming(analysis: FontAnalysis, sourceURL: URL) -> ImportNaming {
        var overrides = NamePolicies.fillerStyleOverrides(for: analysis)
        var prefix = analysis.source.familyPSPrefix
        guard let stub = singleHyphenStub(filenameOrPath: sourceURL.path) else {
            return ImportNaming(overrides: overrides, familyPSPrefix: prefix)
        }
        let byID = Dictionary(
            uniqueKeysWithValues: analysis.windowsNameTable.map { ($0.nameID, $0.string) }
        )
        let recorded = NameFiller.meaningful(analysis.source.familyName)
        if recorded != stub {
            overrides[WindowsNameTableEditing.overrideKey(1)] = stub
        }
        let recorded16 = NameFiller.meaningful(byID[16])
        if recorded16 == nil || recorded16 == recorded {
            overrides[WindowsNameTableEditing.overrideKey(16)] = stub
        }
        let explicit25 = NameFiller.meaningful(byID[25])
        let recordedPrefix = recorded.map { PostScriptNaming.sanitizePostscript($0) } ?? ""
        let explicitIsDistinct = explicit25.map { value in
            let sanitized = PostScriptNaming.sanitizePostscript(value)
            return sanitized != recordedPrefix && value != recorded && sanitized != stub
        } ?? false
        if !explicitIsDistinct {
            let sanitized = PostScriptNaming.sanitizePostscript(stub)
            if !sanitized.isEmpty {
                prefix = sanitized
            }
        }
        return ImportNaming(overrides: overrides, familyPSPrefix: prefix)
    }
}

/// English name for a registered axis whose name ID is blank or filler.
public enum RegisteredAxisNames {
    public static func displayName(tag: String, recorded: String?) -> String {
        if let recorded = NameFiller.meaningful(recorded) {
            return recorded
        }
        switch tag {
        case "wght": return "Weight"
        case "wdth": return "Width"
        case "ital": return "Italic"
        case "slnt": return "Slant"
        case "opsz": return "Optical Size"
        default: return tag
        }
    }
}

/// `post.italicAngle` inside (−2, 2) is upright. Exactly ±2° and beyond is italic.
public enum ItalicAngle {
    public static let uprightLimit = 2.0

    public static func isUpright(_ angle: Double) -> Bool {
        abs(angle) < uprightLimit
    }

    public static func indicatesItalic(_ angle: Double) -> Bool {
        abs(angle) >= uprightLimit
    }
}

/// Names an empty `ital` stop. A real recorded name is kept.
/// A file that is only the italic cut is named Italic even when its single stop sits at 0.
public enum ItalicStopNaming {
    public static func importedName(
        recorded: String,
        value: Double,
        fileIsItalic: Bool,
        stopCount: Int
    ) -> String {
        if let kept = NameFiller.meaningful(recorded) { return kept }
        let atZero = AxisCoordinate.valuesEqual(value, 0)
        let atOne = AxisCoordinate.valuesEqual(value, 1)
        if stopCount <= 1, fileIsItalic {
            return "Italic"
        }
        if atZero { return "Roman" }
        if atOne { return "Italic" }
        return ""
    }

    /// An empty binary stop style-links to its counterpart. A name already in the file is left alone.
    public static func assumedStyleLink(
        recorded: String,
        value: Double,
        format: Int,
        linkedValue: Double?
    ) -> (format: Int, linkedValue: Double?) {
        guard NameFiller.isFiller(recorded) else {
            return (format, linkedValue)
        }
        if AxisCoordinate.valuesEqual(value, 0) {
            return (3, linkedValue ?? 1)
        }
        if AxisCoordinate.valuesEqual(value, 1) {
            return (3, linkedValue ?? 0)
        }
        return (format, linkedValue)
    }
}

/// Weight-stop names taken from the file, plus the registered scale for stops that have none.
public enum WeightStopNaming {
    /// CSS / usWeightClass stops. Off-scale coordinates (250, 275) are not in this table.
    public static let scale: [(value: Double, name: String)] = [
        (100, "Thin"),
        (200, "Extralight"),
        (300, "Light"),
        (400, "Regular"),
        (500, "Medium"),
        (600, "Semibold"),
        (700, "Bold"),
        (800, "Extrabold"),
        (900, "Black"),
    ]

    /// Abbreviations the foundry already wrote. The stop keeps this spelling.
    /// The canonical form is only a suggestion.
    private static let spellingAliases: [String: String] = [
        "xlight": "Extralight",
        "xlt": "Extralight",
        "xbold": "Extrabold",
        "semibold": "Semibold",
    ]

    public static func scaleName(for value: Double) -> String? {
        scale.first { AxisCoordinate.valuesEqual($0.value, value) }?.name
    }

    /// Name to store on import. A name the font already has is kept, including XLight.
    /// A filler name on a registered coordinate becomes that scale name. Elision is not touched.
    public static func importedName(recorded: String, value: Double, tag: String) -> String {
        if let kept = NameFiller.meaningful(recorded) {
            return kept
        }
        guard tag == "wght", let scaleName = scaleName(for: value) else {
            return ""
        }
        return scaleName
    }

    /// Canonical spelling when `name` is an abbreviation, otherwise nil.
    public static func canonicalSpelling(for name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        guard let canonical = spellingAliases[key], canonical != trimmed else { return nil }
        return canonical
    }

    /// Registered weights that sit in a gap between stops this axis already has.
    /// Nothing outside that span is offered, and nothing is inserted by itself.
    public static func missingScaleStops(on axis: AxisDefinition) -> [(value: Double, name: String)] {
        guard axis.tag == "wght", axis.role == .instance else { return [] }
        let existing = axis.values.map(\.value).sorted()
        guard let first = existing.first, let last = existing.last, last > first else { return [] }
        return scale.compactMap { entry in
            guard entry.value > first + AxisCoordinate.tolerance,
                  entry.value < last - AxisCoordinate.tolerance else { return nil }
            guard !existing.contains(where: { AxisCoordinate.valuesEqual($0, entry.value) }) else { return nil }
            if let min = axis.min, entry.value < min - AxisCoordinate.tolerance { return nil }
            if let max = axis.max, entry.value > max + AxisCoordinate.tolerance { return nil }
            return (entry.value, entry.name)
        }
    }

    public static func aliasWarnings(on axis: AxisDefinition) -> [PlanWarning] {
        guard axis.tag == "wght" else { return [] }
        return axis.values.compactMap { stop in
            guard let canonical = canonicalSpelling(for: stop.name) else { return nil }
            return PlanWarning(
                code: "weight_name_alias",
                axis: axis.tag,
                name: canonical,
                stopIDs: [stop.id],
                message: "\(axisLabel(axis)) \(format(stop.value)) is named \(stop.name). The usual spelling is \(canonical).",
                hint: "\(stop.name) stays unless you choose \(canonical)."
            )
        }
    }

    public static func gapWarning(on axis: AxisDefinition) -> PlanWarning? {
        let missing = missingScaleStops(on: axis)
        guard !missing.isEmpty else { return nil }
        let list = missing.map { "\($0.name) (\(format($0.value)))" }.joined(separator: ", ")
        return PlanWarning(
            code: "weight_scale_gap",
            axis: axis.tag,
            stopIDs: [],
            message: "\(axisLabel(axis)) is missing \(list) between the stops it already has.",
            hint: "Add \(list) only if that design should include \(missing.count == 1 ? "it" : "them"). The axis range stays as it is."
        )
    }

    private static func axisLabel(_ axis: AxisDefinition) -> String {
        let name = axis.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? axis.tag : name
    }

    private static func format(_ value: Double) -> String {
        AxisCoordinateFormat.format(value)
    }
}

/// Copies a finished file's weight names onto stops that are still empty,
/// and a recorded family onto a file whose family is blank or a period.
public enum SiblingStopNames {
    public static func shareEmptyWeightNames(in fonts: inout [FontDocument]) {
        var named: [String: String] = [:]
        for font in fonts {
            guard let axis = font.axes.first(where: { $0.tag == "wght" }) else { continue }
            for stop in axis.values {
                guard let name = NameFiller.meaningful(stop.name) else { continue }
                let key = AxisCoordinateFormat.format(stop.value)
                if named[key] == nil {
                    named[key] = name
                }
            }
        }
        guard !named.isEmpty else { return }
        for fontIndex in fonts.indices {
            guard let axisIndex = fonts[fontIndex].axes.firstIndex(where: { $0.tag == "wght" }) else { continue }
            for stopIndex in fonts[fontIndex].axes[axisIndex].values.indices {
                let stop = fonts[fontIndex].axes[axisIndex].values[stopIndex]
                guard NameFiller.isFiller(stop.name) else { continue }
                let key = AxisCoordinateFormat.format(stop.value)
                if let name = named[key] {
                    fonts[fontIndex].axes[axisIndex].values[stopIndex].name = name
                }
            }
        }
    }

    public static func warnings(for font: FontDocument, siblings: [FontDocument]) -> [PlanWarning] {
        guard let axis = font.axes.first(where: { $0.tag == "wght" }) else { return [] }
        var named: [String: String] = [:]
        for sibling in siblings {
            guard let siblingAxis = sibling.axes.first(where: { $0.tag == "wght" }) else { continue }
            for stop in siblingAxis.values {
                guard let name = NameFiller.meaningful(stop.name) else { continue }
                let key = AxisCoordinateFormat.format(stop.value)
                if named[key] == nil {
                    named[key] = name
                }
            }
        }
        return axis.values.compactMap { stop in
            guard NameFiller.isFiller(stop.name) else { return nil }
            let key = AxisCoordinateFormat.format(stop.value)
            guard let name = named[key] else { return nil }
            return PlanWarning(
                code: "sibling_stop_name",
                axis: axis.tag,
                name: name,
                stopIDs: [stop.id],
                message: "Weight \(key) has no name. Another file in this project calls it \(name).",
                hint: "Use \(name) here. The family name is left as it is."
            )
        }
    }

    /// A filler family takes a sibling family that was actually in a name table.
    /// A recorded family such as HT is never replaced. A project label that is just a
    /// filename is not treated as a family.
    public static func shareFamilyName(
        in project: inout ProjectDocument,
        incomingFamily: String?,
        incomingFontID: String
    ) {
        guard let incomingIndex = project.fonts.firstIndex(where: { $0.id == incomingFontID }) else { return }
        let incoming = NameFiller.meaningful(incomingFamily)

        if let incoming {
            guard familyLabelIsFilename(project.familyLabel, in: project) else { return }
            project.familyLabel = incoming
            for index in project.fonts.indices where project.fonts[index].id != incomingFontID {
                fillFamily(incoming, on: &project.fonts[index])
            }
            return
        }

        guard let recorded = NameFiller.meaningful(project.familyLabel),
              !familyLabelIsFilename(recorded, in: project) else { return }
        fillFamily(recorded, on: &project.fonts[incomingIndex])
    }

    private static func familyLabelIsFilename(_ label: String, in project: ProjectDocument) -> Bool {
        guard NameFiller.meaningful(label) != nil else { return true }
        return project.fonts.contains { font in
            URL(fileURLWithPath: font.sourcePath).deletingPathExtension().lastPathComponent == label
        }
    }

    private static func fillFamily(_ family: String, on font: inout FontDocument) {
        let familyKey = WindowsNameTableEditing.overrideKey(1)
        let typographicKey = WindowsNameTableEditing.overrideKey(16)
        if font.windowsNameOverrides[familyKey] == nil {
            font.windowsNameOverrides[familyKey] = family
        }
        if font.windowsNameOverrides[typographicKey] == nil {
            font.windowsNameOverrides[typographicKey] = family
        }
    }
}

/// Reflow when name IDs the font points at do not resolve. A finished name table stays on preserve.
public enum NameIDStrategyInference {
    public static func prefersReflow(analysis: FontAnalysis) -> Bool {
        var referenced: [Int] = []
        for value in analysis.statValues {
            if let id = value.nameID { referenced.append(id) }
        }
        for compound in analysis.compoundStatValues {
            if let id = compound.nameID { referenced.append(id) }
        }
        if let id = analysis.nameAudit.elidedFallbackID {
            referenced.append(id)
        }
        for instance in analysis.instancesExisting {
            referenced.append(instance.subfamilyNameID)
            if instance.postscriptNameID > 0, instance.postscriptNameID != 0xFFFF {
                referenced.append(instance.postscriptNameID)
            }
        }
        let high = referenced.filter { $0 >= 256 }
        guard !high.isEmpty else { return false }
        let resolved = Dictionary(uniqueKeysWithValues: analysis.nameAudit.used.map { ($0.id, $0.string ?? "") })
        return high.contains { NameFiller.meaningful(resolved[$0]) == nil }
    }

    /// Sets reflow on a font whose name IDs do not resolve.
    /// A one-font project follows that font. Adding a file does not change the others.
    public static func applyDanglingReflow(
        to project: inout ProjectDocument,
        analysis: FontAnalysis,
        fontID: String?
    ) {
        guard prefersReflow(analysis: analysis) else { return }
        if project.fonts.count == 1 {
            project.nameidStrategy = .reflow
            project.syncNameIDStrategyToFonts()
            return
        }
        guard let fontID,
              let index = project.fonts.firstIndex(where: { $0.id == fontID }) else { return }
        project.fonts[index].options.nameidStrategy = .reflow
    }
}

extension NamePolicies {
    /// Style records that are missing or filler. Family and credits are not filled in.
    public static func fillerStyleOverrides(for analysis: FontAnalysis) -> [String: String] {
        let byID = Dictionary(
            uniqueKeysWithValues: analysis.windowsNameTable.map { ($0.nameID, $0.string) }
        )
        let context = FillContext.from(
            analysis: analysis,
            familyPSPrefix: analysis.source.familyPSPrefix
        )
        var overrides: [String: String] = [:]
        if NameFiller.isFiller(byID[2] ?? "") {
            overrides[WindowsNameTableEditing.overrideKey(2)] = buildID2(context)
        }
        if analysis.source.isVariable, NameFiller.isFiller(byID[17] ?? "") {
            overrides[WindowsNameTableEditing.overrideKey(17)] = buildID17(context)
        }
        return overrides
    }
}
