import XCTest
@testable import VarFontCore

final class WindowsNameValidationTests: XCTestCase {
    private let fullTable = [
        WindowsNameRecord(nameID: 1, string: "Playfair Display"),
        WindowsNameRecord(nameID: 2, string: "Regular"),
        WindowsNameRecord(nameID: 4, string: "Playfair Display Regular"),
        WindowsNameRecord(nameID: 6, string: "PlayfairDisplay-Regular"),
    ]

    func testUsableValuesProduceNoProblem() {
        XCTAssertNil(WindowsNameValidation.classify("Playfair Display"))
        XCTAssertNil(WindowsNameValidation.classify("Version 1.001"))
        XCTAssertNil(WindowsNameValidation.classify("© 2026 Foundry"))
        XCTAssertTrue(WindowsNameValidation.isUsable("Regular"))
    }

    func testBlankAndWhitespaceOnlyValuesReadAsEmpty() {
        XCTAssertEqual(WindowsNameValidation.classify(""), .empty)
        XCTAssertEqual(WindowsNameValidation.classify("   "), .empty)
        XCTAssertEqual(WindowsNameValidation.classify("\u{7F}"), .empty)
        XCTAssertEqual(WindowsNameValidation.classify("\u{200B}\u{FEFF}"), .empty)
    }

    func testPunctuationAndPlaceholderWordsReadAsPlaceholder() {
        XCTAssertEqual(WindowsNameValidation.classify("."), .placeholder)
        XCTAssertEqual(WindowsNameValidation.classify("-"), .placeholder)
        XCTAssertEqual(WindowsNameValidation.classify(" — "), .placeholder)
        XCTAssertEqual(WindowsNameValidation.classify("Untitled"), .placeholder)
        XCTAssertEqual(WindowsNameValidation.classify("n/a"), .placeholder)
        XCTAssertFalse(WindowsNameValidation.isUsable("TODO"))
    }

    func testRealContentWithInvisibleMarksIsFlaggedButNotBlank() {
        XCTAssertEqual(WindowsNameValidation.classify("Playfair\u{200B} Display"), .controlCharacters)
        XCTAssertEqual(WindowsNameValidation.normalized("Playfair\u{200B} Display"), "Playfair Display")
        XCTAssertTrue(WindowsNameValidation.isUsable("Playfair\u{7F}"))
    }

    func testHealthyTableHasNoIssues() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable,
            overrides: [:],
            removals: [],
            familyPSPrefix: nil
        )
        XCTAssertTrue(issues.isEmpty)
    }

    func testAbsentRequiredIDReportsMissing() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable.filter { $0.nameID != 6 },
            overrides: [:],
            removals: [],
            familyPSPrefix: nil
        )
        XCTAssertEqual(issues.map(\.nameID), [6])
        XCTAssertEqual(issues.first?.problem, .missing)
        XCTAssertTrue(issues.first?.isRequired == true)
    }

    /// A required ID that was removed (only reachable from a legacy project file, since the
    /// panel protects these) still has a record in the font, so it reads as cleared rather
    /// than missing — and there is no row left to badge, hence its own issue.
    func testRemovedRequiredIDReportsClearedRatherThanMissing() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable,
            overrides: [:],
            removals: [1],
            familyPSPrefix: nil
        )
        XCTAssertEqual(issues.map(\.nameID), [1])
        XCTAssertEqual(issues.first?.problem, .cleared)
        XCTAssertTrue(issues.first?.message.contains("deletes nameID 1") == true)
    }

    /// Emptying a required field keeps its row, so the warning rides on the row itself.
    func testClearedRequiredFieldKeepsRowAndReportsEmpty() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable,
            overrides: ["1": ""],
            removals: [],
            familyPSPrefix: nil
        )
        XCTAssertEqual(issues.map(\.nameID), [1])
        XCTAssertEqual(issues.first?.problem, .empty)
        XCTAssertTrue(issues.first?.message.contains("Required record is empty") == true)
    }

    func testPlaceholderValuesOnVisibleRowsAreReported() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable,
            overrides: ["4": ".", "8": "   "],
            removals: [],
            familyPSPrefix: nil
        )
        XCTAssertEqual(issues.first(where: { $0.nameID == 4 })?.problem, .placeholder)
        XCTAssertEqual(issues.first(where: { $0.nameID == 8 })?.problem, .empty)
        XCTAssertFalse(issues.first(where: { $0.nameID == 8 })?.isRequired == true)
    }

    func testRequiredIssuesSortAheadOfOptionalOnes() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable,
            overrides: ["0": ".", "2": "?"],
            removals: [],
            familyPSPrefix: nil
        )
        XCTAssertEqual(issues.map(\.nameID), [2, 0])
    }

    /// Omitting ID 25 is a supported choice, not a validation failure.
    func testOmittedID25IsNotAnIssue() {
        let issues = WindowsNameValidation.issues(
            windowsNameTable: fullTable + [WindowsNameRecord(nameID: 25, string: "Playfair")],
            overrides: [:],
            removals: [25],
            familyPSPrefix: "Playfair"
        )
        XCTAssertTrue(issues.isEmpty)
    }
}
