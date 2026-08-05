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

    func testID2BoldItalicFromFontMetrics() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Family-BoldItalic.ttf",
            isVariable: true,
            familyName: "Family",
            fsSelection: 0x0001,
            usWeightClass: 700
        )
        XCTAssertEqual(NamePolicies.buildID2(context), "Bold Italic")
    }

    func testID3AndID5PreferHeadRevisionAndOS2Vendor() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Rocket-Variable.ttf",
            isVariable: true,
            familyName: "Rocket",
            versionString: "Version 9.999",
            uniqueID: "9.999;OLDV;OldName",
            vendorID: "HLDN",
            fontRevision: 1.25
        )
        XCTAssertEqual(
            NamePolicies.suggestion(nameID: 3, context: context)?.value,
            "1.250;HLDN;Rocket-Variable"
        )
        XCTAssertEqual(
            NamePolicies.suggestion(nameID: 5, context: context)?.value,
            "Version 1.250"
        )
    }

    func testID0UsesHeadYearAndDistinctRightsHolders() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Rocket-Variable.ttf",
            isVariable: true,
            familyName: "Rocket",
            manufacturer: "Holdon Typefoundry",
            designer: "Fadhl Haqq",
            headCreatedYear: 2026
        )
        XCTAssertEqual(
            NamePolicies.buildID0(context),
            "Copyright © 2026 by Holdon Typefoundry & Fadhl Haqq. All rights reserved."
        )
    }

    func testID0FallsBackToExistingCopyrightYearAndDeduplicatesHolder() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Rocket-Variable.ttf",
            isVariable: true,
            familyName: "Rocket",
            copyright: "Copyright 2024 Holdon Typefoundry.",
            manufacturer: "Holdon Typefoundry",
            designer: "holdon typefoundry"
        )
        XCTAssertEqual(
            NamePolicies.buildID0(context),
            "Copyright © 2024 by Holdon Typefoundry. All rights reserved."
        )
    }

    func testID7UsesTypographicFamilyAndRightsHolders() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Rocket-Variable.ttf",
            isVariable: true,
            familyName: "Rocket Variable",
            typographicFamily: "Rocket Variable",
            manufacturer: "Holdon Typefoundry"
        )
        XCTAssertEqual(
            NamePolicies.buildID7(context),
            "Rocket is a trademark of Holdon Typefoundry."
        )
    }

    func testManualLowIDsHaveNoPolicySuggestions() {
        let context = NamePolicies.FillContext(
            sourcePath: "/fonts/Rocket-Variable.ttf",
            isVariable: true,
            familyName: "Rocket"
        )
        for nameID in [8, 9, 10, 11, 12, 13, 14, 18, 19, 20, 21, 22, 23, 24] {
            XCTAssertNil(NamePolicies.suggestion(nameID: nameID, context: context))
        }
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

    func testCanRevertOnlyWhenOverrideDivergesFromFile() {
        let analysis = [WindowsNameRecord(nameID: 1, string: "Family")]
        let overrides = ["1": "Edited Family", "2": "Family", "13": ""]

        XCTAssertTrue(WindowsNameTableEditing.canRevert(
            nameID: 1,
            windowsNameTable: analysis,
            overrides: overrides
        ))
        // Added draft row that the file never had.
        XCTAssertTrue(WindowsNameTableEditing.canRevert(
            nameID: 13,
            windowsNameTable: analysis,
            overrides: overrides
        ))
        // No override recorded at all.
        XCTAssertFalse(WindowsNameTableEditing.canRevert(
            nameID: 6,
            windowsNameTable: analysis,
            overrides: overrides
        ))
    }

    func testCanRevertIsFalseWhenOverrideMatchesFileOrIsPSPrefix() {
        let analysis = [
            WindowsNameRecord(nameID: 1, string: "Family"),
            WindowsNameRecord(nameID: 25, string: "Family"),
        ]
        XCTAssertFalse(WindowsNameTableEditing.canRevert(
            nameID: 1,
            windowsNameTable: analysis,
            overrides: ["1": "Family"]
        ))
        XCTAssertFalse(WindowsNameTableEditing.canRevert(
            nameID: 25,
            windowsNameTable: analysis,
            overrides: ["25": "Other"]
        ))
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
