import XCTest
@testable import VarFontCore

final class InstancerNamingTests: XCTestCase {
    private func row(
        id: String,
        fvar: String?,
        fvarUsable: Bool = true,
        stat: String? = nil,
        coords: [String: Double],
        bold: Bool = false,
        italic: Bool = false,
        override: String? = nil,
        custom: Bool = false
    ) -> InstancerRow {
        InstancerRow(
            id: id,
            origin: custom ? .custom : .source,
            fvarName: fvar,
            fvarUsable: fvarUsable,
            statName: stat,
            coords: coords,
            isBold: bold,
            isItalic: italic,
            nameOverride: override
        )
    }

    private let axes = ["wdth", "wght", "ital"]

    func testResolvedNamePrefersOverrideThenFvarThenSTAT() {
        let base = row(id: "1", fvar: "Regular", fvarUsable: true, stat: "STAT Reg", coords: ["wght": 400])
        XCTAssertEqual(InstancerNaming.resolvedName(for: base), "Regular")

        var fallback = base
        fallback.fvarUsable = false
        XCTAssertEqual(InstancerNaming.resolvedName(for: fallback), "STAT Reg")
        XCTAssertTrue(InstancerNaming.usesSTATFallback(fallback))

        var overridden = fallback
        overridden.nameOverride = "Custom"
        XCTAssertEqual(InstancerNaming.resolvedName(for: overridden), "Custom")
        XCTAssertFalse(InstancerNaming.usesSTATFallback(overridden))
    }

    func testWillFailWhenNoNameSources() {
        let row = row(id: "1", fvar: nil, fvarUsable: false, stat: nil, coords: ["wght": 400])
        XCTAssertTrue(InstancerNaming.willFail(row))
        XCTAssertNil(InstancerNaming.resolvedName(for: row))
    }

    func testCollisionShapes() {
        let a = row(id: "a", fvar: "Regular", coords: ["wght": 400, "wdth": 100, "ital": 0])
        let b = row(id: "b", fvar: "Regular", coords: ["wght": 700, "wdth": 100, "ital": 0]) // name collision
        let c = row(id: "c", fvar: "Medium", coords: ["wght": 400, "wdth": 100, "ital": 0]) // identical design
        let d = row(id: "d", fvar: "Regular", coords: ["wght": 400, "wdth": 100, "ital": 0]) // exact dup of a

        let kinds = InstancerNaming.classifyCollisions(rows: [a, b, c, d], axisTags: axes)
        XCTAssertEqual(kinds["a"], .exact) // a↔d exact beats a↔b collision / a↔c identical
        XCTAssertEqual(kinds["d"], .exact)
        XCTAssertEqual(kinds["b"], .collision)
        XCTAssertEqual(kinds["c"], .identical)
    }

    func testClassifyCollisionsScalesPastPairwisePathologicalCase() {
        // Many unique rows should stay cheap; still detects a single name collision.
        var rows: [InstancerRow] = (0..<400).map { i in
            row(
                id: "r\(i)",
                fvar: "Style\(i)",
                coords: ["wght": Double(100 + i), "wdth": 100, "ital": 0]
            )
        }
        rows.append(row(id: "dup", fvar: "Style0", coords: ["wght": 900, "wdth": 100, "ital": 0]))
        let kinds = InstancerNaming.classifyCollisions(rows: rows, axisTags: axes)
        XCTAssertEqual(kinds["r0"], .collision)
        XCTAssertEqual(kinds["dup"], .collision)
        XCTAssertNil(kinds["r1"])
    }

    func testCoordsKeyUsesDefaultsForMissingAxes() {
        let sparse: [String: Double] = ["wght": 400]
        let key = InstancerNaming.coordsKey(sparse, axisTags: axes)
        XCTAssertEqual(key, "wdth=100,wght=400,ital=0")
    }

    func testDefaultSelectionSkipsLaterNameOrCoordMatches() {
        let rows = [
            row(id: "1", fvar: "Regular", coords: ["wght": 400, "wdth": 100, "ital": 0]),
            row(id: "2", fvar: "Regular", coords: ["wght": 700, "wdth": 100, "ital": 0]),
            row(id: "3", fvar: "Other", coords: ["wght": 400, "wdth": 100, "ital": 0]),
        ]
        let selected = InstancerNaming.defaultSelectedIDs(rows: rows, axisTags: axes)
        XCTAssertEqual(selected, ["1"])
    }

    func testRIBBIFold() {
        XCTAssertEqual(InstancerNaming.ribbi(isBold: false, isItalic: false), .regular)
        XCTAssertEqual(InstancerNaming.ribbi(isBold: true, isItalic: false), .bold)
        XCTAssertEqual(InstancerNaming.ribbi(isBold: false, isItalic: true), .italic)
        XCTAssertEqual(InstancerNaming.ribbi(isBold: true, isItalic: true), .boldItalic)
    }

    func testBoldRIBBIUsesWeightFormat3LinkTargetOnly() {
        let boldLinked = InstancerSessionBuilder.inferStyleBits(
            coords: ["wght": 600, "ital": 0],
            boldLinkedWght: 600
        )
        XCTAssertTrue(boldLinked.bold)
        XCTAssertFalse(boldLinked.italic)

        let extraboldItalic = InstancerSessionBuilder.inferStyleBits(
            coords: ["wght": 700, "ital": 1],
            boldLinkedWght: 600
        )
        XCTAssertFalse(extraboldItalic.bold)
        XCTAssertTrue(extraboldItalic.italic)
        XCTAssertEqual(
            InstancerNaming.ribbi(isBold: extraboldItalic.bold, isItalic: extraboldItalic.italic),
            .italic
        )
    }

    func testWghtLinkTargetsPreferNamedBoldStop() {
        let axis = AxisDefinition(
            tag: "wght",
            min: 100,
            role: .instance,
            values: [
                AxisValue(id: "light", value: 300, name: "Light", elidable: false, statFormat: 1),
                AxisValue(id: "regular", value: 400, name: "Regular", elidable: true, statFormat: 3, linkedValue: 600),
                AxisValue(id: "medium", value: 500, name: "Medium", elidable: false, statFormat: 1),
                AxisValue(id: "bold", value: 600, name: "Bold", elidable: false, statFormat: 1),
                AxisValue(id: "black", value: 800, name: "Black", elidable: false, statFormat: 1),
            ]
        )
        XCTAssertEqual(StatFormat3Pairing.format3LinkedValue(for: 400, axis: axis), 600)
        let targets = StatFormat3Pairing.linkTargets(for: axis, stopValue: 400, excludingStopID: "regular")
        XCTAssertFalse(targets.contains { $0.label == "700 (Bold)" })
        XCTAssertTrue(targets.contains { $0.label == "Bold" && AxisCoordinate.valuesEqual($0.value, 600) })
    }

    func testOutputFileName() {
        let row = row(id: "1", fvar: "Semi Bold", coords: ["wght": 600])
        XCTAssertEqual(
            InstancerNaming.outputFileName(psPrefix: "MullerNext", row: row),
            "MullerNext-SemiBold.ttf"
        )
        XCTAssertEqual(
            InstancerNaming.outputFileName(
                psPrefix: "Interchange",
                row: row,
                composedPostscriptName: "InterchangeTitle-Thin"
            ),
            "InterchangeTitle-Thin.ttf"
        )
    }

    func testSortInterleavesItalicUnderUpright() {
        let rows = [
            row(id: "b", fvar: "Medium", coords: ["wght": 500, "wdth": 100, "ital": 0]),
            row(id: "a", fvar: "Regular", coords: ["wght": 400, "wdth": 100, "ital": 0]),
            row(id: "ai", fvar: "Italic", coords: ["wght": 400, "wdth": 100, "ital": 1], italic: true),
        ]
        let sorted = rows.sorted { InstancerNaming.compareRows($0, $1, axisTags: axes) }
        XCTAssertEqual(sorted.map(\.id), ["a", "ai", "b"])
    }

    func testAxisOrderPrefersSTATOverHardcodedKnownPriority() {
        // Regression: custom axes with low STAT AxisOrdering must precede wght in headers.
        let candidates: Set = ["wght", "insd", "ousd", "ital"]
        let statOrder = ["insd", "ousd", "wght", "ital"]
        XCTAssertEqual(
            InstancerAxisOrder.orderedTags(
                candidates: candidates,
                analysisAxesOrder: statOrder
            ),
            ["insd", "ousd", "wght", "ital"]
        )
        // Hardcoded fallback alone would put wght first — that must not win when STAT order exists.
        XCTAssertEqual(
            InstancerAxisOrder.sortedTags(candidates),
            ["wght", "ital", "insd", "ousd"]
        )
    }

    func testSessionBuilderUsesAnalysisAxesOrderForHeaders() {
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(
                path: "/Fase.ttf",
                format: "ttf",
                familyName: "Fase",
                fullName: "Fase",
                isVariable: true
            ),
            readiness: .init(
                hasFvar: true,
                hasStat: true,
                hasDesignAxisRecord: true,
                writable: true,
                blockers: []
            ),
            axes: [
                .init(
                    tag: "insd",
                    displayName: "Inside Corners",
                    min: 0,
                    default: 0,
                    max: 100,
                    ordering: 0,
                    roleInferred: .instance,
                    variesInExistingInstances: true,
                    valuesExisting: []
                ),
                .init(
                    tag: "ousd",
                    displayName: "Outside Corners",
                    min: 0,
                    default: 0,
                    max: 100,
                    ordering: 1,
                    roleInferred: .instance,
                    variesInExistingInstances: true,
                    valuesExisting: []
                ),
                .init(
                    tag: "wght",
                    displayName: "Weight",
                    min: 100,
                    default: 400,
                    max: 900,
                    ordering: 2,
                    roleInferred: .instance,
                    variesInExistingInstances: true,
                    valuesExisting: []
                ),
                .init(
                    tag: "ital",
                    displayName: "Italic",
                    min: 0,
                    default: 0,
                    max: 0,
                    ordering: 3,
                    roleInferred: .designRecordOnly,
                    variesInExistingInstances: false,
                    valuesExisting: []
                ),
            ],
            statValues: [
                .init(format: 1, tag: "ital", name: "Roman", elidable: true, value: 0),
            ],
            instancesExisting: [
                .init(
                    key: "regular",
                    composedName: "Regular",
                    coords: ["insd": 0, "ousd": 0, "wght": 100],
                    subfamilyNameID: 2,
                    postscriptNameID: 0
                ),
            ],
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            windowsNameTable: [],
            inferred: .init(isItalicFont: false, gridAxisTags: [], namingOrderSuggested: []),
            designAxisTags: ["insd", "ousd", "wght", "ital"]
        )
        let built = InstancerSessionBuilder.build(from: analysis)
        XCTAssertEqual(built.axisTags, ["insd", "ousd", "wght", "ital"])
        XCTAssertEqual(built.fvarAxisTags, ["insd", "ousd", "wght"])
        XCTAssertEqual(built.rows.first?.coords["ital"], 0)
    }

    func testInferredFamilyNameStripsVariablePreferringNameID16() {
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(
                path: "/BlackPack-Variable.ttf",
                format: "ttf",
                familyName: "Black Pack Niu Variable Expanded",
                fullName: "Black Pack Niu Variable",
                isVariable: true
            ),
            readiness: .init(
                hasFvar: true,
                hasStat: true,
                hasDesignAxisRecord: true,
                writable: true,
                blockers: []
            ),
            axes: [],
            statValues: [],
            instancesExisting: [],
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            windowsNameTable: [
                WindowsNameRecord(nameID: 1, string: "Black Pack Niu Variable Expanded"),
                WindowsNameRecord(nameID: 16, string: "Black Pack Niu Variable"),
            ],
            inferred: .init(isItalicFont: false, gridAxisTags: [], namingOrderSuggested: []),
            designAxisTags: []
        )
        XCTAssertEqual(
            InstancerSessionBuilder.inferredFamilyName(from: analysis),
            "Black Pack Niu"
        )
        XCTAssertEqual(
            InstancerSessionBuilder.build(from: analysis).inferredFamilyName,
            "Black Pack Niu"
        )
    }

    func testInferredFamilyNameFallsBackToNameID1() {
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(
                path: "/t.ttf",
                format: "ttf",
                familyName: "Playfair VF",
                fullName: "Playfair VF",
                isVariable: true
            ),
            readiness: .init(
                hasFvar: true,
                hasStat: true,
                hasDesignAxisRecord: true,
                writable: true,
                blockers: []
            ),
            axes: [],
            statValues: [],
            instancesExisting: [],
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            windowsNameTable: [],
            inferred: .init(isItalicFont: false, gridAxisTags: [], namingOrderSuggested: []),
            designAxisTags: []
        )
        XCTAssertEqual(InstancerSessionBuilder.inferredFamilyName(from: analysis), "Playfair")
    }
}
