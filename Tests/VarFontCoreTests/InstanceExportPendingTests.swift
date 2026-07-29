import XCTest
@testable import VarFontCore

final class InstanceExportPendingTests: XCTestCase {
    func testIncludedInstanceMissingFromFvarIsPending() {
        let plan = planWithInstances([
            ("ital:0|opsz:12|wdth:100|wght:400", ["ital": 0, "opsz": 12, "wdth": 100, "wght": 400], included: true),
            ("ital:0|opsz:12|wdth:100|wght:700", ["ital": 0, "opsz": 12, "wdth": 100, "wght": 700], included: true),
        ])
        let analysis = analysisWithFvarInstances([
            ["wdth": 100, "wght": 400],
        ])

        let pending = InstanceExportPending.pendingIncludedKeys(plan: plan, analysis: analysis)
        XCTAssertEqual(pending, ["ital:0|opsz:12|wdth:100|wght:700"])
    }

    func testAlignedKeyMatchesWhenPlanIncludesPinnedAxes() {
        let plan = planWithInstances([
            ("ital:0|opsz:12|wdth:100|wght:400", ["ital": 0, "opsz": 12, "wdth": 100, "wght": 400], included: true),
        ])
        let analysis = analysisWithFvarInstances([
            ["wdth": 100, "wght": 400],
        ])

        let pending = InstanceExportPending.pendingIncludedKeys(plan: plan, analysis: analysis)
        XCTAssertTrue(pending.isEmpty)
    }

    func testExcludedInstancesAreNotPending() {
        let plan = planWithInstances([
            ("wdth:100|wght:700", ["wdth": 100, "wght": 700], included: false),
        ])
        let analysis = analysisWithFvarInstances([])

        let pending = InstanceExportPending.pendingIncludedKeys(plan: plan, analysis: analysis)
        XCTAssertTrue(pending.isEmpty)
    }

    func testEmptyFvarMarksAllIncludedAsPending() {
        let plan = planWithInstances([
            ("wdth:100|wght:400", ["wdth": 100, "wght": 400], included: true),
        ])
        let analysis = analysisWithFvarInstances([])

        let pending = InstanceExportPending.pendingIncludedKeys(plan: plan, analysis: analysis)
        XCTAssertEqual(pending, ["wdth:100|wght:400"])
    }

    private func planWithInstances(
        _ rows: [(key: String, coords: [String: Double], included: Bool)]
    ) -> InstancePlan {
        InstancePlan(
            schemaVersion: 1,
            fontID: "test-font",
            formula: PlanFormula(
                parts: [rows.count],
                totalGenerated: rows.count,
                totalIncluded: rows.filter(\.included).count,
                totalExcluded: rows.filter { !$0.included }.count
            ),
            instances: rows.map { row in
                PlannedInstance(
                    key: row.key,
                    composedName: row.key,
                    coords: row.coords,
                    included: row.included,
                    duplicate: false,
                    namingChain: []
                )
            },
            warnings: [],
            namePlanSummary: nil
        )
    }

    private func analysisWithFvarInstances(_ coordsList: [[String: Double]]) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/tmp/test.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [],
            instancesExisting: coordsList.map { coords in
                FontAnalysis.ExistingInstance(
                    key: InstanceKeyBuilder.makeKey(coords: coords),
                    composedName: "Instance",
                    coords: coords,
                    subfamilyNameID: 0,
                    postscriptNameID: 0
                )
            },
            instancesExistingMeta: .init(total: coordsList.count, sampleCount: coordsList.count),
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            inferred: .init(isItalicFont: false, gridAxisTags: ["wdth", "wght"], namingOrderSuggested: ["wdth", "wght"])
        )
    }
}
