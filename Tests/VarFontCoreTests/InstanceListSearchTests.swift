import XCTest
@testable import VarFontCore

final class InstanceListSearchTests: XCTestCase {
    private func instance(
        name: String = "Bold Condensed",
        key: String = "wdth=75,wght=700",
        coords: [String: Double] = ["wdth": 75, "wght": 700],
        chain: [NamingChainLink] = [
            NamingChainLink(tag: "wdth", name: "Condensed", elided: false),
            NamingChainLink(tag: "wght", name: "Bold", elided: false),
        ]
    ) -> PlannedInstance {
        PlannedInstance(
            key: key,
            composedName: name,
            coords: coords,
            included: true,
            duplicate: false,
            namingChain: chain
        )
    }

    // MARK: - Aliases

    func testSemanticAliasesResolveToOpenTypeTags() {
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("weight"), "wght")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("WIDTH"), "wdth")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("optical"), "opsz")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("optical size"), "opsz")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("slant"), "slnt")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("italic"), "ital")
        XCTAssertEqual(InstanceListSearch.resolveAxisToken("wght"), "wght")
    }

    func testDisplayNameAliasOverridesBuiltInsWhenProvided() {
        let map = ["opsz": "Point Size"]
        XCTAssertEqual(
            InstanceListSearch.resolveAxisToken("Point Size", displayNameByTag: map),
            "opsz"
        )
    }

    // MARK: - Parse

    func testParsesPlusAxisSetWithAliases() {
        let query = InstanceListSearch.parse("wdth+weight+italic")
        guard case .axisSet(let tags) = query else {
            return XCTFail("expected axisSet, got \(String(describing: query))")
        }
        XCTAssertEqual(tags, ["wdth", "wght", "ital"])
    }

    func testParsesTagEqualsWithAliases() {
        let query = InstanceListSearch.parse("weight=400 wdth=100")
        guard case .tagEquals(let preds) = query else {
            return XCTFail("expected tagEquals, got \(String(describing: query))")
        }
        XCTAssertEqual(preds.map(\.tag), ["wght", "wdth"])
        XCTAssertTrue(AxisCoordinate.valuesEqual(preds[0].value, 400))
        XCTAssertTrue(AxisCoordinate.valuesEqual(preds[1].value, 100))
    }

    func testFallsBackToFreeText() {
        let query = InstanceListSearch.parse("Regular")
        guard case .text(let text) = query else {
            return XCTFail("expected text, got \(String(describing: query))")
        }
        XCTAssertEqual(text, "Regular")
    }

    // MARK: - Match

    func testAxisSetKeepsInstancesThatHaveAllTags() {
        let query = InstanceListSearch.parse("wdth+wght")!
        XCTAssertTrue(InstanceListSearch.matches(instance(), query: query))
        XCTAssertFalse(InstanceListSearch.matches(
            instance(coords: ["wght": 400]),
            query: query
        ))
    }

    func testTagEqualsMatchesCoordinateValues() {
        let query = InstanceListSearch.parse("weight=700")!
        XCTAssertTrue(InstanceListSearch.matches(instance(), query: query))
        XCTAssertFalse(InstanceListSearch.matches(
            instance(coords: ["wdth": 75, "wght": 400]),
            query: query
        ))
    }

    func testTextMatchesElidedNamingChainTokens() {
        let regular = instance(
            name: "Bold",
            key: "wght=700",
            coords: ["wght": 700, "wdth": 100],
            chain: [
                NamingChainLink(tag: "wdth", name: "Regular", elided: true),
                NamingChainLink(tag: "wght", name: "Bold", elided: false),
            ]
        )
        let query = InstanceListSearch.parse("Regular")!
        XCTAssertTrue(InstanceListSearch.matches(regular, query: query))
        XCTAssertFalse(InstanceListSearch.matches(
            instance(chain: [
                NamingChainLink(tag: "wght", name: "Bold", elided: false),
            ]),
            query: query
        ))
    }

    // MARK: - Shared axes / budget / row tags

    func testGroupSharedAxesDetectsConstantValues() {
        let a = instance(coords: ["wdth": 75, "wght": 400, "opsz": 12])
        let b = instance(coords: ["wdth": 75, "wght": 700, "opsz": 12])
        let shared = InstanceCoordPresentation.groupSharedAxes(
            instances: [a, b],
            enabledTags: ["wdth", "wght", "opsz"]
        )
        XCTAssertEqual(shared, ["wdth", "opsz"])
    }

    func testGroupSharedAxesDoesNotLiftSingletonGroup() {
        // One instance matching an Excluded/Conflicts filter would otherwise lift
        // every axis to the header and leave coords-only rows empty.
        let solo = instance(coords: ["wdth": 75, "wght": 400, "opsz": 12])
        let shared = InstanceCoordPresentation.groupSharedAxes(
            instances: [solo],
            enabledTags: ["wdth", "wght", "opsz"]
        )
        XCTAssertEqual(shared, [])
    }

    func testPillBudgetFitsFixedWidthTags() {
        // 80 wide, 24 pill + 4 gap → floor((80+4)/(24+4)) = 3
        XCTAssertEqual(InstanceCoordPresentation.pillBudget(availableWidth: 80, pillWidth: 24, gap: 4), 3)
        XCTAssertEqual(InstanceCoordPresentation.pillBudget(availableWidth: 20, pillWidth: 24), 0)
        XCTAssertEqual(InstanceCoordPresentation.pillBudget(availableWidth: 24, pillWidth: 24), 1)
    }

    func testRowAxisTagsDropsSharedAndAppliesSearchFocus() {
        let tags = InstanceCoordPresentation.rowAxisTags(
            enabledTags: ["wdth", "wght", "opsz", "ital"],
            sharedTags: ["opsz"],
            searchFocus: ["wdth", "wght"]
        )
        XCTAssertEqual(tags, ["wdth", "wght"])
    }
}
