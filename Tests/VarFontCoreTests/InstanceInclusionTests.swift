import XCTest
@testable import VarFontCore

final class InstanceInclusionTests: XCTestCase {
    private let keepA = "wght:400"
    private let keepB = "wght:700"
    private let invented = "wght:500"
    private let allKeys: Set<String> = ["wght:400", "wght:500", "wght:700"]

    func testExcludeAllFromWhitelistConvertsToExcludeList() {
        var font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            includedInstanceKeys: [keepA, keepB],
            excludedInstanceKeys: []
        )

        InstanceInclusion.applyInclusion(
            keys: [keepA, keepB],
            included: false,
            to: &font,
            allInstanceKeys: allKeys
        )

        XCTAssertTrue(font.includedInstanceKeys.isEmpty)
        XCTAssertEqual(Set(font.excludedInstanceKeys), allKeys)
        XCTAssertFalse(InstanceInclusion.isTrimmedToOriginals(font))
    }

    func testExcludeLastWhitelistKeyKeepsNonWhitelistedExcluded() {
        var font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            includedInstanceKeys: [keepA],
            excludedInstanceKeys: []
        )

        InstanceInclusion.applyInclusion(
            keys: [keepA],
            included: false,
            to: &font,
            allInstanceKeys: allKeys
        )

        XCTAssertTrue(font.includedInstanceKeys.isEmpty)
        XCTAssertEqual(Set(font.excludedInstanceKeys), allKeys)
        XCTAssertTrue(font.excludedInstanceKeys.contains(invented))
    }

    func testExcludePartialWhitelistStaysInWhitelistMode() {
        var font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            includedInstanceKeys: [keepA, keepB],
            excludedInstanceKeys: []
        )

        InstanceInclusion.applyInclusion(
            keys: [keepA],
            included: false,
            to: &font,
            allInstanceKeys: allKeys
        )

        XCTAssertEqual(font.includedInstanceKeys, [keepB])
        XCTAssertTrue(font.excludedInstanceKeys.isEmpty)
        XCTAssertTrue(InstanceInclusion.isTrimmedToOriginals(font))
    }

    func testExcludeInExcludeListModeAppendsKeys() {
        var font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            includedInstanceKeys: [],
            excludedInstanceKeys: [keepA]
        )

        InstanceInclusion.applyInclusion(
            keys: [keepB],
            included: false,
            to: &font,
            allInstanceKeys: allKeys
        )

        XCTAssertTrue(font.includedInstanceKeys.isEmpty)
        XCTAssertEqual(Set(font.excludedInstanceKeys), [keepA, keepB])
    }
}
