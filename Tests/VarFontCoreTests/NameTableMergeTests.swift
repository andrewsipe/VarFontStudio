import XCTest
@testable import VarFontCore

final class NameTableMergeTests: XCTestCase {
    private func record(_ nameID: Int, _ string: String) -> WindowsNameRecord {
        WindowsNameRecord(nameID: nameID, string: string)
    }

    func testMasterIntentsUsesOverrideThenAnalysis() {
        let table = [record(0, "Copyright on disk"), record(9, "Designer on disk")]
        let intents = NameTableMerge.masterIntents(
            windowsNameTable: table,
            overrides: ["0": "Copyright override"],
            removals: []
        )
        XCTAssertEqual(intents[0], .set("Copyright override"))
        XCTAssertEqual(intents[9], .set("Designer on disk"))
        XCTAssertEqual(intents[7], .leaveTarget)
    }

    func testMasterIntentsMarksRemoval() {
        let intents = NameTableMerge.masterIntents(
            windowsNameTable: [record(8, "Manufacturer")],
            overrides: [:],
            removals: [8]
        )
        XCTAssertEqual(intents[8], .remove)
    }

    func testMergeSetsOverrideWhenTargetDiffers() {
        let merged = NameTableMerge.mergeIntoTarget(
            masterIntents: [0: .set("© 2026 Acme")],
            targetOverrides: [:],
            targetRemovals: [],
            targetWindowsNameTable: [record(0, "Old copyright")]
        )
        XCTAssertEqual(merged.overrides["0"], "© 2026 Acme")
        XCTAssertTrue(merged.removals.isEmpty)
    }

    func testMergeClearsOverrideWhenTargetAlreadyMatches() {
        let merged = NameTableMerge.mergeIntoTarget(
            masterIntents: [7: .set("Acme Foundry")],
            targetOverrides: ["7": "Draft"],
            targetRemovals: [],
            targetWindowsNameTable: [record(7, "Acme Foundry")]
        )
        XCTAssertNil(merged.overrides["7"])
    }

    func testMergePropagatesRemoval() {
        let merged = NameTableMerge.mergeIntoTarget(
            masterIntents: [10: .remove],
            targetOverrides: ["10": "Description"],
            targetRemovals: [],
            targetWindowsNameTable: [record(10, "Description")]
        )
        XCTAssertNil(merged.overrides["10"])
        XCTAssertEqual(merged.removals, [10])
    }

    func testMergeLeavesTargetUntouchedForAbsentMasterID() {
        let merged = NameTableMerge.mergeIntoTarget(
            masterIntents: [12: .leaveTarget],
            targetOverrides: ["12": "Local URL"],
            targetRemovals: [],
            targetWindowsNameTable: []
        )
        XCTAssertEqual(merged.overrides["12"], "Local URL")
        XCTAssertTrue(merged.removals.isEmpty)
    }

    // MARK: - OpenType feature labels

    private func otLabel(
        _ tag: String,
        _ string: String,
        table: String = "GSUB",
        field: String = "UINameID",
        nameID: Int = 256
    ) -> OTFeatureLabelRecord {
        OTFeatureLabelRecord(
            table: table,
            featureTag: tag,
            field: field,
            nameID: nameID,
            string: string
        )
    }

    func testOTMasterIntentsUsesOverrideThenAnalysisAndAdditions() {
        let intents = NameTableMerge.otMasterIntents(
            labels: [otLabel("ss01", "Set 1")],
            overrides: ["GSUB|ss01|UINameID": "Renamed"],
            additions: [OTFeatureLabelAddition(table: "GSUB", featureTag: "ss02", string: "New")]
        )
        XCTAssertEqual(intents["GSUB|ss01|UINameID"], .set("Renamed"))
        XCTAssertEqual(intents["GSUB|ss02|UINameID"], .set("New"))
        XCTAssertNil(intents["GSUB|ss03|UINameID"])
    }

    func testOTMergeOverridesLabeledSiteWhenTargetDiffers() {
        let merged = NameTableMerge.mergeOTIntoTarget(
            masterIntents: ["GSUB|ss01|UINameID": .set("Swash")],
            targetLabels: [otLabel("ss01", "Old")],
            targetUnlabeled: [],
            targetOverrides: [:],
            targetAdditions: []
        )
        XCTAssertEqual(merged.overrides["GSUB|ss01|UINameID"], "Swash")
        XCTAssertTrue(merged.additions.isEmpty)
    }

    func testOTMergeClearsOverrideWhenTargetAlreadyMatches() {
        let merged = NameTableMerge.mergeOTIntoTarget(
            masterIntents: ["GSUB|ss01|UINameID": .set("Swash")],
            targetLabels: [otLabel("ss01", "Swash")],
            targetUnlabeled: [],
            targetOverrides: ["GSUB|ss01|UINameID": "Draft"],
            targetAdditions: []
        )
        XCTAssertNil(merged.overrides["GSUB|ss01|UINameID"])
    }

    func testOTMergeAddsLabelToUnlabeledTargetFeature() {
        let merged = NameTableMerge.mergeOTIntoTarget(
            masterIntents: ["GSUB|ss02|UINameID": .set("Alternate a")],
            targetLabels: [],
            targetUnlabeled: [OTFeatureUnlabeled(table: "GSUB", featureTag: "ss02")],
            targetOverrides: [:],
            targetAdditions: []
        )
        XCTAssertEqual(merged.overrides["GSUB|ss02|UINameID"], "Alternate a")
        XCTAssertEqual(merged.additions.count, 1)
        XCTAssertEqual(merged.additions.first?.featureTag, "ss02")
        XCTAssertEqual(merged.additions.first?.string, "Alternate a")
    }

    func testOTMergeSkipsFeatureTargetDoesNotHave() {
        let merged = NameTableMerge.mergeOTIntoTarget(
            masterIntents: ["GSUB|ss01|UINameID": .set("Swash")],
            targetLabels: [],
            targetUnlabeled: [OTFeatureUnlabeled(table: "GSUB", featureTag: "ss02")],
            targetOverrides: [:],
            targetAdditions: []
        )
        XCTAssertTrue(merged.overrides.isEmpty)
        XCTAssertTrue(merged.additions.isEmpty)
    }

    func testOTMergePushesEmptyLabelOntoExistingSite() {
        let merged = NameTableMerge.mergeOTIntoTarget(
            masterIntents: ["GSUB|ss01|UINameID": .set("")],
            targetLabels: [otLabel("ss01", "Swash")],
            targetUnlabeled: [],
            targetOverrides: [:],
            targetAdditions: []
        )
        XCTAssertEqual(merged.overrides["GSUB|ss01|UINameID"], "")
    }
}
