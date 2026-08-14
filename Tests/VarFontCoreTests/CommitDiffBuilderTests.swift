import XCTest
@testable import VarFontCore

final class CommitDiffBuilderTests: XCTestCase {
    func testStatSameNameDifferentNameIDIsUnchanged() {
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [
                .init(
                    format: 1,
                    tag: "wght",
                    name: "Regular",
                    elidable: false,
                    olderSibling: false,
                    nameID: 269,
                    value: 750
                ),
            ],
            instancesExisting: [],
            instancesExistingMeta: .init(total: 0, sampleCount: 0),
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: 261, elidedFallbackName: "Regular"),
            inferred: .init(isItalicFont: false, gridAxisTags: ["wght"], namingOrderSuggested: ["wght"]),
            designAxisTags: ["wght"]
        )

        let font = FontDocument(
            id: "f1",
            sourcePath: "/t.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 0,
                    default: 400,
                    max: 1000,
                    role: .instance,
                    roleInferred: .instance,
                    values: [
                        AxisValue(
                            id: "w750",
                            value: 750,
                            name: "Regular",
                            elidable: false,
                            olderSibling: false,
                            statFormat: 1
                        ),
                    ]
                ),
            ]
        )

        let diff = CommitDiff(
            statValuesPlanned: [
                .init(
                    tag: "wght",
                    value: 750,
                    name: "Regular",
                    elidable: false,
                    statFormat: 1,
                    nameID: 261
                ),
            ]
        )

        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: PlanFormula(parts: [1], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
            instances: [],
            warnings: [],
            namePlanSummary: nil
        )

        let result = CommitResult(
            schemaVersion: 1,
            requestID: "r1",
            ok: true,
            outputPath: nil,
            dryRun: true,
            summary: nil,
            diff: diff,
            validation: nil,
            warnings: [],
            errors: []
        )

        let report = CommitDiffBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            result: result
        )

        let row = report.statRows.first { $0.tag == "wght" && $0.value == 750 }
        XCTAssertNotNil(row)
        XCTAssertEqual(row?.change, CommitDiffChangeKind.unchanged)
        if let row {
            XCTAssertEqual(SaveReviewDisplayCategoryMapper.category(for: row), .same)
        }
    }

    func testFixed16_16StatCoordinatesDoNotDuplicateRows() {
        // After export, analysis re-reads STAT as 16.16 Fixed (19.72999…) while the
        // Axis Tree still holds the project Double (19.73). Those must be one SAME row.
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [
                .init(
                    format: 2,
                    tag: "opsz",
                    name: "Standard",
                    elidable: false,
                    nameID: 260,
                    value: 19.729995727539062,
                    rangeMin: 10.0,
                    rangeMax: 40.0,
                    nominal: 19.729995727539062
                ),
                .init(
                    format: 1,
                    tag: "wght",
                    name: "Regular",
                    elidable: false,
                    nameID: 263,
                    value: 35.79998779296875
                ),
            ],
            instancesExisting: [],
            instancesExistingMeta: .init(total: 0, sampleCount: 0),
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: 261, elidedFallbackName: "Regular"),
            inferred: .init(isItalicFont: false, gridAxisTags: ["opsz", "wght"], namingOrderSuggested: ["opsz", "wght"]),
            designAxisTags: ["opsz", "wght"]
        )

        let font = FontDocument(
            id: "f1",
            sourcePath: "/t.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "opsz",
                    displayName: "Optical size",
                    min: 1,
                    default: 19.73,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "o1", value: 19.73, name: "Standard", elidable: false, statFormat: 2, rangeMin: 10, rangeMax: 40),
                    ]
                ),
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 1,
                    default: 35.8,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 35.8, name: "Regular", elidable: false, statFormat: 1),
                    ]
                ),
            ]
        )

        let diff = CommitDiff(
            statValuesPlanned: [
                .init(tag: "opsz", value: 19.73, name: "Standard", elidable: false, statFormat: 2, nameID: 260, rangeMin: 10, rangeMax: 40),
                .init(tag: "wght", value: 35.8, name: "Regular", elidable: false, statFormat: 1, nameID: 263),
            ]
        )

        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: PlanFormula(parts: [1], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
            instances: [],
            warnings: [],
            namePlanSummary: nil
        )

        let report = CommitDiffBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            result: CommitResult(
                schemaVersion: 1,
                requestID: "r1",
                ok: true,
                outputPath: nil,
                dryRun: true,
                summary: nil,
                diff: diff,
                validation: nil,
                warnings: [],
                errors: []
            )
        )

        let opsz = report.statRows.filter { $0.tag == "opsz" }
        XCTAssertEqual(opsz.count, 1)
        XCTAssertEqual(opsz.first?.change, .unchanged)
        XCTAssertEqual(SaveReviewDisplayCategoryMapper.category(for: opsz[0]), .same)

        let wght = report.statRows.filter { $0.tag == "wght" }
        XCTAssertEqual(wght.count, 1)
        XCTAssertEqual(wght.first?.change, .unchanged)
        XCTAssertEqual(SaveReviewDisplayCategoryMapper.category(for: wght[0]), .same)
    }

    func testOtReflowShowsMovedNameIDRow() {
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [],
            instancesExisting: [],
            instancesExistingMeta: .init(total: 0, sampleCount: 0),
            nameAudit: .init(
                freeStart: 256,
                used: [
                    .init(id: 763, description: "GSUB ss05 UINameID", string: "Alternate g"),
                ],
                elidedFallbackID: 261,
                elidedFallbackName: "Regular"
            ),
            inferred: .init(isItalicFont: false, gridAxisTags: [], namingOrderSuggested: []),
            designAxisTags: []
        )

        let font = FontDocument(
            id: "f1",
            sourcePath: "/t.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: []
        )

        let diff = CommitDiff(
            nameRecordsPlanned: [
                .init(id: 256, string: "Alternate g", role: "ot_feature_label"),
            ],
            otReflowMapping: [
                .init(fromID: 763, toID: 256, string: "Alternate g", feature: "ss05"),
            ]
        )

        let result = CommitResult(
            schemaVersion: 1,
            requestID: "r1",
            ok: true,
            outputPath: nil,
            dryRun: true,
            summary: .init(protectedNameIDs: []),
            diff: diff,
            validation: nil,
            warnings: [],
            errors: []
        )

        let report = CommitDiffBuilder.build(
            analysis: analysis,
            font: font,
            plan: InstancePlan(
                schemaVersion: 1,
                fontID: "f1",
                formula: PlanFormula(parts: [1], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
                instances: [],
                warnings: [],
                namePlanSummary: nil
            ),
            result: result
        )

        let added = report.nameIDRows.first { $0.id == 256 }
        XCTAssertEqual(added?.reflowedFromNameID, 763)
        XCTAssertEqual(added?.change, .added)
    }

    /// fvar can list multiple named instances at the same coords; preview must not trap.
    func testDuplicateExistingInstanceKeysDoNotCrash() {
        let coords = ["wght": 400.0]
        let key = InstanceKeyBuilder.makeKey(coords: coords)
        let analysis = FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [],
            instancesExisting: [
                .init(key: key, composedName: "Regular", coords: coords, subfamilyNameID: 2, postscriptNameID: 6),
                .init(key: key, composedName: "Normal", coords: coords, subfamilyNameID: 258, postscriptNameID: 259),
            ],
            instancesExistingMeta: .init(total: 2, sampleCount: 2),
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: 2, elidedFallbackName: "Regular"),
            inferred: .init(isItalicFont: false, gridAxisTags: ["wght"], namingOrderSuggested: ["wght"]),
            designAxisTags: ["wght"]
        )

        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: PlanFormula(parts: [1], totalGenerated: 1, totalIncluded: 1, totalExcluded: 0),
            instances: [
                PlannedInstance(
                    key: key,
                    composedName: "Regular",
                    coords: coords,
                    included: true,
                    duplicate: false,
                    namingChain: []
                ),
            ],
            warnings: [],
            namePlanSummary: nil
        )

        let result = CommitResult(
            schemaVersion: 1,
            requestID: "r1",
            ok: true,
            outputPath: nil,
            dryRun: true,
            summary: nil,
            diff: CommitDiff(),
            validation: nil,
            warnings: [],
            errors: []
        )

        let report = CommitDiffBuilder.build(
            analysis: analysis,
            font: FontDocument(
                id: "f1",
                sourcePath: "/t.ttf",
                outputPath: nil,
                analysisSnapshotID: nil,
                dirty: false,
                axes: []
            ),
            plan: plan,
            result: result
        )

        XCTAssertEqual(report.instanceRows.count, 1)
        XCTAssertEqual(report.instanceRows.first?.key, key)
    }
}
