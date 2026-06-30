import XCTest
@testable import VarFontCore

final class AxisCoordinateFormatTests: XCTestCase {
    func testCanonicalRoundsToTwoDecimalPlaces() {
        XCTAssertEqual(AxisCoordinateFormat.canonical(162.3115692138672), 162.31)
        XCTAssertEqual(AxisCoordinateFormat.canonical(162.31155395507812), 162.31)
    }

    func testInstanceKeysMatchAfterCanonicalization() {
        let a = InstanceKeyBuilder.makeKey(coords: ["wdth": 162.3115692138672, "wght": 750])
        let b = InstanceKeyBuilder.makeKey(coords: ["wdth": 162.31155395507812, "wght": 750])
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "wdth:162.31|wght:750")
    }

    func testFormatTrimsTrailingZeros() {
        XCTAssertEqual(AxisCoordinateFormat.format(100), "100")
        XCTAssertEqual(AxisCoordinateFormat.format(86.90), "86.9")
        XCTAssertEqual(AxisCoordinateFormat.format(162.31), "162.31")
    }
}
