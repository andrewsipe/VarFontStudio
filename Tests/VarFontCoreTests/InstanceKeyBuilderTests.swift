import XCTest
@testable import VarFontCore

final class InstanceKeyBuilderTests: XCTestCase {
    func testMakeKeySortsTagsAlphabetically() {
        let key = InstanceKeyBuilder.makeKey(coords: [
            "wght": 400,
            "opsz": 12,
            "wdth": 100,
            "ital": 0,
        ])
        XCTAssertEqual(key, "ital:0|opsz:12|wdth:100|wght:400")
    }

    func testParseKeyRoundTrip() {
        let coords: [String: Double] = ["ital": 0, "opsz": 5, "wdth": 88, "wght": 360]
        let key = InstanceKeyBuilder.makeKey(coords: coords)
        XCTAssertEqual(key, "ital:0|opsz:5|wdth:88|wght:360")
        XCTAssertEqual(InstanceKeyBuilder.parseKey(key), coords)
    }
}
