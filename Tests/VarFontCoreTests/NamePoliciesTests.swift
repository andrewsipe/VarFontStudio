import XCTest
@testable import VarFontCore

final class NamePoliciesTests: XCTestCase {
    func testID6UsesFilenameStemNotConstructedPrefix() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/PlayfairDisplay-Variable.ttf",
            isVariable: true,
            familyName: "Playfair Display",
            familyPSPrefix: "PlayfairDisplay",
            versionString: "Version 2.100",
            vendorID: "UKWN"
        )
        XCTAssertEqual(NamePolicies.buildID6(context), "PlayfairDisplay-Variable")
        XCTAssertEqual(
            NamePolicies.suggestion(nameID: 3, context: context)?.value,
            "2.100;UKWN;PlayfairDisplay-Variable"
        )
    }

    func testID6ItalicStemFromFilename() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/PlayfairDisplay-VariableItalic.ttf",
            isVariable: true,
            familyName: "Playfair Display",
            familyPSPrefix: "PlayfairDisplay",
            versionString: "Version 2.100"
        )
        XCTAssertEqual(NamePolicies.buildID6(context), "PlayfairDisplay-VariableItalic")
    }

    func testPlayfairSlotBuildersMatchFontCore() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/PlayfairDisplay-Variable.ttf",
            isVariable: true,
            familyName: "Playfair Display",
            typographicFamily: "Playfair Display",
            familyPSPrefix: "PlayfairDisplay",
            versionString: "Version 2.100",
            vendorID: "UKWN"
        )
        XCTAssertEqual(NamePolicies.buildID1(context), "Playfair Display")
        XCTAssertEqual(NamePolicies.buildID4(context), "Playfair Display Variable")
        XCTAssertEqual(NamePolicies.buildID16(context), "Playfair Display Variable")
        XCTAssertEqual(NamePolicies.buildID17(context), "Regular")
        XCTAssertEqual(NamePolicies.buildID2(context), "Regular")
    }

    func testItalicSlopeFromFilenameForID4AndID17() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Example-VariableItalic.ttf",
            isVariable: true,
            familyName: "Example",
            typographicFamily: "Example",
            familyPSPrefix: "Example",
            versionString: "Version 1.000"
        )
        XCTAssertEqual(NamePolicies.buildID4(context), "Example Variable Italic")
        XCTAssertEqual(NamePolicies.buildID17(context), "Italic")
        XCTAssertEqual(NamePolicies.buildID6(context), "Example-VariableItalic")
    }

    func testElidableUprightSlopeOmitsFromID4AndID17() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/FL_RareText-VariableUpright.ttf",
            isVariable: true,
            familyName: "FL Rare Text",
            typographicFamily: "FL Rare Variable"
        )
        XCTAssertEqual(NamePolicies.buildID1(context), "FL Rare Text")
        XCTAssertEqual(NamePolicies.buildID4(context), "FL Rare Text Variable")
        XCTAssertEqual(NamePolicies.buildID16(context), "FL Rare Text Variable")
        XCTAssertEqual(NamePolicies.buildID17(context), "Regular")
    }

    func testID1OmitsVariableToken() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/PlayfairDisplay-Variable.ttf",
            isVariable: true,
            familyName: "Playfair Display Variable",
            typographicFamily: "Playfair Display Variable",
            versionString: "Version 1.000"
        )
        XCTAssertEqual(NamePolicies.suggestion(nameID: 1, context: context)?.value, "Playfair Display")
        XCTAssertEqual(NamePolicies.suggestion(nameID: 16, context: context)?.value, "Playfair Display Variable")
    }

    func testID2ItalicFromItalRegistrationOne() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-Variable.ttf",
            isVariable: true,
            familyName: "Family",
            italRegistrationValue: 1
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Italic")
    }

    func testID2RegularFromItalRegistrationZeroIgnoresAngle() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-Variable.ttf",
            isVariable: true,
            familyName: "Family",
            italRegistrationValue: 0,
            postItalicAngle: -12,
            hasSlopeClarifier: true
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Regular")
    }

    func testID2ItalicFromPostItalicAngleWhenNoItalRegistration() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-Variable.ttf",
            isVariable: true,
            familyName: "Family",
            postItalicAngle: -11.5
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Italic")
    }

    func testID2ItalicFromSlopeClarifierWhenNoItalRegistration() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-Variable.ttf",
            isVariable: true,
            familyName: "Family",
            hasSlopeClarifier: true
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Italic")
    }

    func testID2RegularDefault() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-Variable.ttf",
            isVariable: true,
            familyName: "Family"
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Regular")
    }
}

final class WindowsNameTableEditingTests: XCTestCase {
    func testPopulatedRowsPreferOverrides() {
        let analysis = [
            WindowsNameRecord(nameID: 1, string: "Old Family"),
            WindowsNameRecord(nameID: 6, string: "OldPS"),
        ]
        let rows = WindowsNameTableEditing.populatedRows(
            windowsNameTable: analysis,
            overrides: ["1": "New Family"],
            familyPSPrefix: "NewPrefix"
        )
        XCTAssertEqual(rows.first(where: { $0.nameID == 1 })?.value, "New Family")
        XCTAssertEqual(rows.first(where: { $0.nameID == 25 })?.value, "NewPrefix")
        XCTAssertTrue(rows.first(where: { $0.nameID == 25 })?.isLinkedToPSPrefix == true)
    }

    func testCommitPatchesSkipUnchangedAndEmitDeletes() {
        let analysis = [
            WindowsNameRecord(nameID: 1, string: "Family"),
            WindowsNameRecord(nameID: 6, string: "Family-Variable"),
        ]
        let patches = WindowsNameTableEditing.commitPatches(
            windowsNameTable: analysis,
            overrides: [
                "1": "Family",
                "6": "Family-VariableVF",
                "16": "",
                "4": "Family Variable",
            ]
        )
        XCTAssertEqual(patches.map(\.nameID), [4, 6])
        XCTAssertEqual(patches.first(where: { $0.nameID == 6 })?.string, "Family-VariableVF")
        XCTAssertEqual(patches.first(where: { $0.nameID == 4 })?.string, "Family Variable")
    }

    func testCommitPatchesDeleteExisting() {
        let analysis = [WindowsNameRecord(nameID: 16, string: "Family Variable")]
        let patches = WindowsNameTableEditing.commitPatches(
            windowsNameTable: analysis,
            overrides: ["16": ""]
        )
        XCTAssertEqual(patches, [WindowsNameRecord(nameID: 16, string: "")])
    }

    func testMissingIDsExcludePresent() {
        let missing = WindowsNameTableEditing.missingNameIDs(
            windowsNameTable: [WindowsNameRecord(nameID: 1, string: "A")],
            overrides: ["6": "A-Variable"],
            familyPSPrefix: "A"
        )
        XCTAssertFalse(missing.contains(1))
        XCTAssertFalse(missing.contains(6))
        XCTAssertFalse(missing.contains(25))
        XCTAssertTrue(missing.contains(4))
    }
}
