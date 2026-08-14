import XCTest
@testable import VarFontCore

final class InstanceCodedNamingTests: XCTestCase {
    func testDetectsVaryingDigitPrefixes() {
        let detection = InstanceCodedNaming.detect(names: [
            "24 Condensed Regular",
            "27 Condensed Bold",
            "44 Normal Regular",
            "47 Normal Bold",
        ])
        XCTAssertEqual(detection?.matchedCount, 4)
        XCTAssertEqual(detection?.prefixes, ["24", "27", "44", "47"])
    }

    func testIgnoresStyleWordsWithoutDigits() {
        XCTAssertNil(
            InstanceCodedNaming.detect(names: [
                "Condensed Regular",
                "Condensed Bold",
                "Normal Regular",
                "Normal Bold",
            ])
        )
    }

    func testRequiresMoreThanOneDistinctPrefix() {
        XCTAssertNil(
            InstanceCodedNaming.detect(names: [
                "211 Regular",
                "211 Bold",
                "211 Medium",
            ])
        )
    }

    func testStripTokenAndGluedPrefixes() {
        XCTAssertEqual(InstanceCodedNaming.stripPrefix("211 Condensed Regular"), "Condensed Regular")
        XCTAssertEqual(InstanceCodedNaming.stripPrefix("211Condensed"), "Condensed")
        XCTAssertEqual(InstanceCodedNaming.stripPrefix("Bold"), "Bold")
        XCTAssertEqual(InstanceCodedNaming.stripPrefix("W1 Regular"), "Regular")
    }
}
