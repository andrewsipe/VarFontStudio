import XCTest
@testable import VarFontCore

final class OTFeatureLabelEditingTests: XCTestCase {
    func testPopulatedRowsMergeOverridesAndUnlabeled() {
        let labels = [
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Set 1"
            )
        ]
        let unlabeled = [
            OTFeatureUnlabeled(table: "GSUB", featureTag: "ss02", suggestedString: "Alternate a")
        ]
        let rows = OTFeatureLabelEditing.populatedRows(
            labels: labels,
            unlabeled: unlabeled,
            overrides: ["GSUB|ss01|UINameID": "Renamed"],
            additions: []
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].value, "Renamed")
        XCTAssertTrue(rows[0].isOverride)
        XCTAssertEqual(rows[1].featureTag, "ss02")
        XCTAssertEqual(rows[1].suggestedString, "Alternate a")
        XCTAssertEqual(
            OTFeatureLabelEditing.Row.displayLabel(for: "ss01"),
            "Stylistic Set 01"
        )
    }

    func testProvisionalNameIDsAfterAdditions() {
        let labels = [
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Set 1"
            )
        ]
        let additions = [
            OTFeatureLabelAddition(table: "GSUB", featureTag: "ss02", string: "New"),
            OTFeatureLabelAddition(table: "GSUB", featureTag: "ss03", string: "Also"),
        ]
        let preserve = OTFeatureLabelEditing.provisionalNameIDs(
            existingLabels: labels,
            additions: additions,
            nameidStrategy: .preserve
        )
        // Continue after preserved OT nameID 300 — not back at 256.
        XCTAssertEqual(preserve["GSUB|ss02|UINameID"], 301)
        XCTAssertEqual(preserve["GSUB|ss03|UINameID"], 302)

        let reflow = OTFeatureLabelEditing.provisionalNameIDs(
            existingLabels: labels,
            additions: additions,
            nameidStrategy: .reflow
        )
        // Existing site reserves 256; additions start at 257.
        XCTAssertEqual(reflow["GSUB|ss02|UINameID"], 257)
        XCTAssertEqual(reflow["GSUB|ss03|UINameID"], 258)

        let rows = OTFeatureLabelEditing.populatedRows(
            labels: labels,
            unlabeled: [],
            overrides: [:],
            additions: additions,
            nameidStrategy: .reflow
        )
        let ss02 = rows.first { $0.featureTag == "ss02" }
        XCTAssertEqual(ss02?.nameID, 257)
        XCTAssertEqual(ss02?.isProvisionalNameID, true)
    }

    func testCommitPatchesAndAdditions() {
        let labels = [
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Set 1"
            )
        ]
        let patches = OTFeatureLabelEditing.commitPatches(
            labels: labels,
            overrides: [
                "GSUB|ss01|UINameID": "New Name",
                "GSUB|ss01|UINameID-same": "ignored",
            ]
        )
        XCTAssertEqual(patches.count, 1)
        XCTAssertEqual(patches[0].string, "New Name")

        let additions = OTFeatureLabelEditing.commitAdditions(
            additions: [
                OTFeatureLabelAddition(table: "GSUB", featureTag: "ss02", string: "Draft"),
            ],
            overrides: ["GSUB|ss02|UINameID": "Final"]
        )
        XCTAssertEqual(additions.count, 1)
        XCTAssertEqual(additions[0].string, "Final")
    }

    func testFontDocumentRoundTripOTFields() throws {
        var font = FontDocument(id: "f1", sourcePath: "/tmp/a.ttf")
        font.otFeatureLabelOverrides = ["GSUB|ss01|UINameID": "X"]
        font.otFeatureLabelAdditions = [
            OTFeatureLabelAddition(table: "GSUB", featureTag: "ss03", string: "Y")
        ]
        let data = try VarFontJSON.encode(font)
        let decoded = try VarFontJSON.decode(FontDocument.self, from: data)
        XCTAssertEqual(decoded.otFeatureLabelOverrides["GSUB|ss01|UINameID"], "X")
        XCTAssertEqual(decoded.otFeatureLabelAdditions.first?.featureTag, "ss03")
    }

    func testCommitRequestIncludesOTPatches() {
        var font = FontDocument(id: "f1", sourcePath: "/tmp/a.ttf")
        font.otFeatureLabelOverrides = ["GSUB|ss01|UINameID": "Patched"]
        font.otFeatureLabelAdditions = [
            OTFeatureLabelAddition(table: "GSUB", featureTag: "ss02", string: "Added")
        ]
        let labels = [
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Original"
            )
        ]
        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: font.id,
            formula: PlanFormula(parts: [], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
            instances: [],
            warnings: []
        )
        let request = CommitRequestBuilder.make(
            font: font,
            naming: NamingPolicy(order: [], elidedFallback: "Regular"),
            plan: plan,
            outputPath: "/tmp/out.ttf",
            dryRun: true,
            otFeatureLabels: labels
        )
        XCTAssertEqual(request.otLabelPatches.count, 1)
        XCTAssertEqual(request.otLabelPatches[0].string, "Patched")
        XCTAssertEqual(request.otLabelAdditions.count, 1)
        XCTAssertEqual(request.otLabelAdditions[0].featureTag, "ss02")
    }

    func testCommitPatchesToleratesDuplicateLabelSites() {
        let labels = [
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Set 1"
            ),
            OTFeatureLabelRecord(
                table: "GSUB",
                featureTag: "ss01",
                field: "UINameID",
                nameID: 300,
                string: "Set 1"
            ),
        ]
        let patches = OTFeatureLabelEditing.commitPatches(
            labels: labels,
            overrides: ["GSUB|ss01|UINameID": "Renamed"]
        )
        XCTAssertEqual(patches.count, 1)
        XCTAssertEqual(patches[0].string, "Renamed")

        let rows = OTFeatureLabelEditing.populatedRows(
            labels: labels,
            unlabeled: [],
            overrides: [:],
            additions: []
        )
        XCTAssertEqual(rows.count, 1)
    }
}
