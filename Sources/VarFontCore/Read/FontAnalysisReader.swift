import CoreText
import Foundation

public enum FontAnalysisReaderError: Error, Sendable {
    case unreadableFont(URL)
    case missingFvar
}

/// How much of the font to parse — heavier scopes feed Save Review; Instancer skips the name audit.
public enum FontAnalysisScope: Sendable {
    /// Import / browse: capped instance sample + full name audit.
    case sample
    /// Save Review / commit diff: all fvar instances + full name audit.
    case commitDiff
    /// Instancer list: all fvar instances + STAT naming, no name-table audit.
    case instancer
}

public enum FontAnalysisReader {
    private static let parametricTags: Set<String> = [
        "XOPQ", "YOPQ", "XTRA", "YTUC", "YTLC", "YTAS", "YTDE", "YTFI",
    ]

    private static let fvarTag = OpenTypeBinary.tag("fvar")
    private static let statTag = OpenTypeBinary.tag("STAT")
    private static let postTag = OpenTypeBinary.tag("post")
    private static let headTag = OpenTypeBinary.tag("head")
    private static let os2Tag = OpenTypeBinary.tag("OS/2")

    public static func analyze(url: URL) throws -> FontAnalysis {
        try analyze(url: url, scope: .sample)
    }

    /// Full fvar instance list for save-time diff (no 5-instance sample cap).
    public static func analyzeForCommitDiff(url: URL) throws -> FontAnalysis {
        try analyze(url: url, scope: .commitDiff)
    }

    /// Instancer-only parse: all named instances and STAT labels, without the name-table audit.
    public static func analyzeForInstancer(url: URL) throws -> FontAnalysis {
        try analyze(url: url, scope: .instancer)
    }

    private static func analyze(url: URL, scope: FontAnalysisScope) throws -> FontAnalysis {
        let includeAllInstances = scope != .sample
        let lightweight = scope == .instancer
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first else {
            throw FontAnalysisReaderError.unreadableFont(url)
        }

        let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
        let ext = url.pathExtension.lowercased()
        let familyName = OpenTypeNameTable.name(id: 1, from: font) ?? ""
        let fullName = OpenTypeNameTable.name(id: 4, from: font) ?? ""
        let postscriptName = OpenTypeNameTable.name(id: 6, from: font)
        let nameID25 = OpenTypeNameTable.name(id: 25, from: font)
        let typographicFamilyName = OpenTypeNameTable.name(id: 16, from: font)
        let familyPSPrefix = PostScriptPrefixInference.infer(
            nameID25: nameID25,
            postscriptName: postscriptName,
            typographicFamilyName: typographicFamilyName,
            familyName: familyName
        )

        let fvarData = CTFontCopyTable(font, fvarTag, []) as Data?
        let statData = CTFontCopyTable(font, statTag, []) as Data?
        let postData = CTFontCopyTable(font, postTag, []) as Data?
        let headData = CTFontCopyTable(font, headTag, []) as Data?
        let os2Data = CTFontCopyTable(font, os2Tag, []) as Data?

        let fontRevision = headData.flatMap { data in
            data.count >= 8 ? OpenTypeBinary.readFixed(data, 4) : nil
        }
        let headCreatedYear = headData.flatMap { data in
            data.count >= 28 ? calendarYear(macEpochSeconds: OpenTypeBinary.readUInt64(data, 20)) : nil
        }
        let headMacStyle = headData.flatMap { data in
            data.count >= 46 ? OpenTypeBinary.readUInt16(data, 44) : nil
        }
        let usWeightClass = os2Data.flatMap { data in
            data.count >= 6 ? OpenTypeBinary.readUInt16(data, 4) : nil
        }
        let vendorID = os2Data.flatMap { data -> String? in
            guard data.count >= 62 else { return nil }
            let value = OpenTypeBinary.readTag(data, 58)
                .replacingOccurrences(of: "\0", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let fsSelection = os2Data.flatMap { data in
            data.count >= 64 ? OpenTypeBinary.readUInt16(data, 62) : nil
        }

        var isItalicFont = false
        var postItalicAngle: Double?
        if let postData, postData.count >= 8 {
            let angle = OpenTypeBinary.readFixed(postData, 4)
            postItalicAngle = angle
            isItalicFont = abs(angle) > 0.5
        }
        isItalicFont = isItalicFont
            || ((fsSelection ?? 0) & 0x0001) != 0
            || ((headMacStyle ?? 0) & 0x0002) != 0

        var blockers: [String] = []
        let hasFvar = fvarData != nil
        let hasStat = statData != nil
        var hasDesignAxisRecord = false

        guard let fvarData, let fvar = FvarParser.parse(fvarData) else {
            if !hasFvar { blockers.append("No fvar table") }
            return emptyAnalysis(
                url: url,
                ext: ext,
                familyName: familyName,
                fullName: fullName,
                isItalicFont: isItalicFont,
                postItalicAngle: postItalicAngle,
                fontRevision: fontRevision,
                headCreatedYear: headCreatedYear,
                vendorID: vendorID,
                fsSelection: fsSelection,
                usWeightClass: usWeightClass,
                headMacStyle: headMacStyle,
                blockers: blockers + ["No fvar table"]
            )
        }

        let stat = statData.flatMap { StatParser.parse($0) }
        if hasStat {
            hasDesignAxisRecord = !(stat?.designAxes.isEmpty ?? true)
        }

        if !hasStat {
            blockers.append("No STAT table")
        } else if !hasDesignAxisRecord {
            blockers.append("STAT has no DesignAxisRecord")
        }

        let idxToTag = Dictionary(
            uniqueKeysWithValues: (stat?.designAxes ?? []).enumerated().map { ($0.offset, $0.element.tag) }
        )
        let orderMap = Dictionary(
            uniqueKeysWithValues: (stat?.designAxes ?? []).map { ($0.tag, $0.ordering) }
        )

        var vary: [String: Set<Double>] = [:]
        for instance in fvar.instances {
            for (tag, value) in instance.coordinates {
                vary[tag, default: []].insert(value)
            }
        }
        let gridAxisTags = vary.filter { $0.value.count > 1 }.map(\.key).sorted()

        var statValues: [FontAnalysis.StatValueRecord] = []
        for value in stat?.values ?? [] {
            let tag = idxToTag[value.axisIndex] ?? "?"
            let rec = FontAnalysis.StatValueRecord(
                format: value.format,
                tag: tag,
                name: OpenTypeNameTable.name(id: value.nameID, from: font) ?? "",
                elidable: value.elidable,
                olderSibling: value.olderSibling,
                nameID: value.nameID,
                value: value.value,
                linkedValue: value.linkedValue,
                rangeMin: value.rangeMin,
                rangeMax: value.rangeMax,
                nominal: value.nominal
            )
            statValues.append(rec)
        }

        var compoundStatValues: [FontAnalysis.CompoundStatRecord] = []
        for compound in stat?.compoundValues ?? [] {
            var coords: [String: Double] = [:]
            for (index, axisValue) in zip(compound.axisIndices, compound.axisValues) {
                let tag = idxToTag[index] ?? "?"
                coords[tag] = axisValue
            }
            compoundStatValues.append(
                FontAnalysis.CompoundStatRecord(
                    id: "compound-\(UUID().uuidString.prefix(8))",
                    coords: coords,
                    axisIndices: compound.axisIndices,
                    axisValues: compound.axisValues,
                    name: OpenTypeNameTable.name(id: compound.nameID, from: font) ?? "",
                    elidable: compound.elidable,
                    olderSibling: compound.olderSibling,
                    nameID: compound.nameID
                )
            )
        }

        let statByTag = Dictionary(grouping: statValues, by: \.tag)

        var axes: [FontAnalysis.AnalyzedAxis] = []
        for axis in fvar.axes {
            let role: AxisRole
            if gridAxisTags.contains(axis.tag) {
                role = .instance
            } else if parametricTags.contains(axis.tag) {
                role = .parametric
            } else {
                role = .statOnly
            }

            let valuesExisting: [FontAnalysis.StatValueSnapshot]
            if lightweight {
                valuesExisting = []
            } else {
                valuesExisting = (statByTag[axis.tag] ?? []).map { statValue in
                    FontAnalysis.StatValueSnapshot(
                        format: statValue.format,
                        value: statValue.value,
                        name: statValue.name,
                        elidable: statValue.elidable,
                        olderSibling: statValue.olderSibling,
                        linkedValue: statValue.linkedValue,
                        rangeMin: statValue.rangeMin,
                        rangeMax: statValue.rangeMax,
                        nominal: statValue.nominal
                    )
                }
            }

            let observed: [Double]
            if lightweight {
                observed = []
            } else {
                observed = (vary[axis.tag] ?? []).map(AxisCoordinateFormat.canonical).sorted()
            }
            axes.append(
                FontAnalysis.AnalyzedAxis(
                    tag: axis.tag,
                    displayName: lightweight
                        ? axis.tag
                        : (OpenTypeNameTable.name(id: axis.nameID, from: font) ?? axis.tag),
                    min: axis.min,
                    default: axis.defaultValue,
                    max: axis.max,
                    ordering: orderMap[axis.tag],
                    roleInferred: role,
                    variesInExistingInstances: gridAxisTags.contains(axis.tag),
                    valuesExisting: valuesExisting,
                    fvarValuesObserved: observed,
                    fvarHidden: axis.isHidden
                )
            )
        }

        // Design-record-only axes are unused by InstancerSessionBuilder (filtered out).
        if !lightweight {
            let fvarTags = Set(fvar.axes.map(\.tag))
            for designAxis in stat?.designAxes ?? [] where !fvarTags.contains(designAxis.tag) {
                let valuesExisting = (statByTag[designAxis.tag] ?? []).map { statValue in
                    FontAnalysis.StatValueSnapshot(
                        format: statValue.format,
                        value: statValue.value,
                        name: statValue.name,
                        elidable: statValue.elidable,
                        linkedValue: statValue.linkedValue,
                        rangeMin: statValue.rangeMin,
                        rangeMax: statValue.rangeMax,
                        nominal: statValue.nominal
                    )
                }

                axes.append(
                    FontAnalysis.AnalyzedAxis(
                        tag: designAxis.tag,
                        displayName: OpenTypeNameTable.name(id: designAxis.nameID, from: font) ?? designAxis.tag,
                        min: 0,
                        default: 0,
                        max: 0,
                        ordering: orderMap[designAxis.tag],
                        roleInferred: .designRecordOnly,
                        variesInExistingInstances: false,
                        valuesExisting: valuesExisting
                    )
                )
            }
        }

        axes.sort { lhs, rhs in
            let leftOrder = lhs.ordering ?? Int.max
            let rightOrder = rhs.ordering ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            return lhs.tag < rhs.tag
        }

        let instanceSlice = includeAllInstances ? fvar.instances : Array(fvar.instances.prefix(min(5, fvar.instances.count)))
        let sampleCount = includeAllInstances ? fvar.instances.count : min(5, fvar.instances.count)
        let instancesExisting = instanceSlice.map { instance in
            FontAnalysis.ExistingInstance(
                key: InstanceKeyBuilder.makeKey(coords: instance.coordinates),
                composedName: OpenTypeNameTable.name(id: instance.subfamilyNameID, from: font) ?? "",
                coords: instance.coordinates,
                subfamilyNameID: instance.subfamilyNameID,
                postscriptNameID: instance.postscriptNameID
            )
        }

        let elidedFallbackID = stat?.elidedFallbackNameID
        let elidedFallbackName = lightweight
            ? nil
            : elidedFallbackID.flatMap { OpenTypeNameTable.name(id: $0, from: font) }

        let namingOrderSuggested: [String]
        if lightweight {
            namingOrderSuggested = NamingOrderInference.canonicalAxisOrder
        } else {
            namingOrderSuggested = NamingOrderInference.suggest(
                designAxes: stat?.designAxes ?? [],
                fvarAxisTags: fvar.axes.map(\.tag)
            )
        }

        let nameAudit: FontAnalysis.NameAudit
        if lightweight {
            nameAudit = FontAnalysis.NameAudit(
                freeStart: 256,
                used: [],
                elidedFallbackID: elidedFallbackID,
                elidedFallbackName: nil
            )
        } else {
            nameAudit = buildNameAudit(
                font: font,
                fvar: fvar,
                designAxes: stat?.designAxes ?? [],
                statValues: statValues,
                elidedFallbackID: elidedFallbackID,
                elidedFallbackName: elidedFallbackName
            )
        }
        // Instancer only needs name ID 16 (typographic family); low Windows names are cheap.
        let windowsNameTable = OpenTypeNameTable.windowsEnglishLowNames(from: font)

        return FontAnalysis(
            schemaVersion: 1,
            source: FontAnalysis.SourceInfo(
                path: url.path,
                format: ext,
                familyName: familyName,
                fullName: fullName,
                postscriptName: postscriptName,
                isVariable: true,
                familyPSPrefix: familyPSPrefix
            ),
            readiness: FontAnalysis.Readiness(
                hasFvar: true,
                hasStat: hasStat,
                hasDesignAxisRecord: hasDesignAxisRecord,
                writable: hasStat && hasDesignAxisRecord,
                blockers: blockers
            ),
            axes: axes,
            statValues: statValues,
            compoundStatValues: compoundStatValues,
            instancesExisting: instancesExisting,
            instancesExistingMeta: FontAnalysis.InstancesMeta(
                total: fvar.instances.count,
                sampleCount: sampleCount
            ),
            nameAudit: nameAudit,
            windowsNameTable: windowsNameTable,
            inferred: FontAnalysis.InferredAnalysis(
                isItalicFont: isItalicFont,
                gridAxisTags: gridAxisTags,
                namingOrderSuggested: namingOrderSuggested,
                postItalicAngle: postItalicAngle,
                fontRevision: fontRevision,
                headCreatedYear: headCreatedYear,
                vendorID: vendorID,
                fsSelection: fsSelection,
                usWeightClass: usWeightClass,
                headMacStyle: headMacStyle
            ),
            designAxisTags: (stat?.designAxes ?? []).map(\.tag)
        )
    }

    private static func buildNameAudit(
        font: CTFont,
        fvar: (axes: [FvarAxis], instances: [FvarInstance]),
        designAxes: [StatDesignAxis],
        statValues: [FontAnalysis.StatValueRecord],
        elidedFallbackID: Int?,
        elidedFallbackName: String?
    ) -> FontAnalysis.NameAudit {
        let nameData = CTFontCopyTable(font, OpenTypeBinary.tag("name"), []) as Data?
        let usedIDs = nameData.map { OpenTypeNameTable.uniqueNameIDs(in: $0) } ?? []

        var labels: [Int: String] = [:]
        for id in usedIDs {
            if let label = OpenTypeNameTable.standardNameLabel(for: id) {
                labels[id] = label
            }
        }
        for axis in fvar.axes {
            labels[axis.nameID] = "fvar axis \(axis.tag)"
        }
        for designAxis in designAxes {
            labels[designAxis.nameID] = "STAT DesignAxisRecord [\(designAxis.tag)] AxisNameID"
        }
        for instance in fvar.instances {
            labels[instance.subfamilyNameID] = "fvar instance subfamily"
            if instance.postscriptNameID > 0, instance.postscriptNameID != 0xFFFF {
                labels[instance.postscriptNameID] = "fvar instance PostScript"
            }
        }
        for statValue in statValues {
            if let nameID = statValue.nameID {
                labels[nameID] = "STAT \(statValue.tag)"
            }
        }
        if let elidedFallbackID {
            labels[elidedFallbackID] = "STAT elided fallback"
        }

        let used = usedIDs.sorted().map { id in
            let string = nameData.flatMap { OpenTypeNameTable.bestName(id: id, in: $0) }
            return FontAnalysis.NameAudit.NameIDUse(
                id: id,
                description: labels[id] ?? "name table record",
                string: string,
                protected: (0...25).contains(id) ? true : nil
            )
        }

        return FontAnalysis.NameAudit(
            freeStart: OpenTypeNameTable.firstFreeNameID(used: usedIDs),
            used: used,
            elidedFallbackID: elidedFallbackID,
            elidedFallbackName: elidedFallbackName
        )
    }

    private static func emptyAnalysis(
        url: URL,
        ext: String,
        familyName: String,
        fullName: String,
        isItalicFont: Bool,
        postItalicAngle: Double?,
        fontRevision: Double?,
        headCreatedYear: Int?,
        vendorID: String?,
        fsSelection: UInt16?,
        usWeightClass: UInt16?,
        headMacStyle: UInt16?,
        blockers: [String]
    ) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: FontAnalysis.SourceInfo(
                path: url.path,
                format: ext,
                familyName: familyName,
                fullName: fullName,
                isVariable: false
            ),
            readiness: FontAnalysis.Readiness(
                hasFvar: false,
                hasStat: false,
                hasDesignAxisRecord: false,
                writable: false,
                blockers: blockers
            ),
            axes: [],
            statValues: [],
            compoundStatValues: [],
            instancesExisting: [],
            instancesExistingMeta: FontAnalysis.InstancesMeta(total: 0, sampleCount: 0),
            nameAudit: FontAnalysis.NameAudit(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            inferred: FontAnalysis.InferredAnalysis(
                isItalicFont: isItalicFont,
                gridAxisTags: [],
                namingOrderSuggested: NamingOrderInference.canonicalAxisOrder,
                postItalicAngle: postItalicAngle,
                fontRevision: fontRevision,
                headCreatedYear: headCreatedYear,
                vendorID: vendorID,
                fsSelection: fsSelection,
                usWeightClass: usWeightClass,
                headMacStyle: headMacStyle
            )
        )
    }

    private static func calendarYear(macEpochSeconds: UInt64) -> Int? {
        guard macEpochSeconds > 0 else { return nil }
        let unixSeconds = Double(macEpochSeconds) - 2_082_844_800
        let date = Date(timeIntervalSince1970: unixSeconds)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let year = calendar.component(.year, from: date)
        return year >= 1904 ? year : nil
    }
}
