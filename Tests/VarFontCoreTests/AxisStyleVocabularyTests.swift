import XCTest
@testable import VarFontCore

final class AxisStyleVocabularyTests: XCTestCase {
    func testFamilies() {
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Wide"), .width)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "UltraCondensed"), .width)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Bold"), .weight)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Extrabold"), .weight)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Italic"), .slope)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Micro"), .optical)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "Regular"), .unknown)
        XCTAssertEqual(AxisStyleVocabulary.family(for: "SemiRounded"), .unknown)
    }

    func testCrossAxisMismatch() {
        XCTAssertTrue(AxisStyleVocabulary.mismatchesAxis("Wide", tag: "wght"))
        XCTAssertTrue(AxisStyleVocabulary.mismatchesAxis("Extended", tag: "wght"))
        XCTAssertTrue(AxisStyleVocabulary.mismatchesAxis("Condensed", tag: "slnt"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("Wide", tag: "wdth"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("Bold", tag: "wght"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("Italic", tag: "slnt"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("Regular", tag: "wght"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("Display", tag: "insd"))
        XCTAssertFalse(AxisStyleVocabulary.mismatchesAxis("SemiDisplay", tag: "ousd"))
        XCTAssertTrue(AxisStyleVocabulary.mismatchesAxis("Display", tag: "wght"))
    }

    func testStrippingFileSlopeTokensLeavesSlopeAxesAlone() {
        XCTAssertEqual(AxisStyleVocabulary.strippingFileSlopeTokens("Light Italic", forAxisTag: "wght"), "Light")
        XCTAssertEqual(AxisStyleVocabulary.strippingFileSlopeTokens("Text Italic", forAxisTag: "opsz"), "Text")
        XCTAssertEqual(AxisStyleVocabulary.strippingFileSlopeTokens("Italic", forAxisTag: "wght"), "")
        XCTAssertEqual(AxisStyleVocabulary.strippingFileSlopeTokens("Italic", forAxisTag: "slnt"), "Italic")
        XCTAssertEqual(AxisStyleVocabulary.strippingFileSlopeTokens("Light Italic", forAxisTag: "ital"), "Light Italic")
    }

    func testPositionalFuzzVsOpszShear() {
        // Rooftop Bold@783/810 on a 1…1000 axis.
        XCTAssertTrue(
            AxisStyleVocabulary.isPositionalFuzz(
                span: 27,
                nearestForeignDistance: 187,
                axisRange: 999
            )
        )
        // Rooftop Regular@398/399.
        XCTAssertTrue(
            AxisStyleVocabulary.isPositionalFuzz(
                span: 1,
                nearestForeignDistance: 52,
                axisRange: 999
            )
        )
        // Interchange Extra Thin span across opsz (≈14 on ≈100 range) with overlap.
        XCTAssertFalse(
            AxisStyleVocabulary.isPositionalFuzz(
                span: 14.01,
                nearestForeignDistance: 4.0,
                axisRange: 99
            )
        )
    }

    func testConflictPrefersFvarWhenSTATHasWrongAxisVocabulary() {
        let resolution = FvarStopSeeder.NameConflict.recommendedResolution(
            axisTag: "wght",
            existingName: "Wide",
            fvarName: "Regular",
            existingNameWasEmpty: false,
            fvarNameWasEmpty: false
        )
        XCTAssertEqual(resolution, .takeFvar)
    }

    func testConflictPrefersFvarWhenSTATNameDuplicatedOnAxis() {
        let resolution = FvarStopSeeder.NameConflict.recommendedResolution(
            axisTag: "wdth",
            existingName: "Condensed",
            fvarName: "Ultra Condensed",
            existingNameWasEmpty: false,
            fvarNameWasEmpty: false,
            existingNameDuplicatedOnAxis: true
        )
        XCTAssertEqual(resolution, .takeFvar)
    }
}
