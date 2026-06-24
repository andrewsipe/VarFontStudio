import XCTest
@testable import VarFontCore

final class NamingComposerTests: XCTestCase {
    func testComposeMatchesStopWithinTolerance() {
        let axis = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "wght-a", value: 400, name: "Regular", elidable: false),
            ]
        )
        let naming = NamingPolicy(order: ["wght"], elidedFallback: "Fallback")

        let result = NamingComposer.compose(
            coords: ["wght": 399.9999999],
            axes: [axis],
            naming: naming
        )

        XCTAssertEqual(result.name, "Regular")
        XCTAssertEqual(result.chain.count, 1)
        XCTAssertEqual(result.chain[0].name, "Regular")
    }

    func testComposeFallsBackWhenNoStopMatches() {
        let axis = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "wght-a", value: 400, name: "Regular", elidable: false),
            ]
        )
        let naming = NamingPolicy(order: ["wght"], elidedFallback: "Fallback")

        let result = NamingComposer.compose(
            coords: ["wght": 350],
            axes: [axis],
            naming: naming
        )

        XCTAssertEqual(result.name, "Fallback")
        XCTAssertTrue(result.chain.isEmpty)
    }

    func testComposeSkipsStatOnlyAxes() {
        let opsz = AxisDefinition(
            tag: "opsz",
            role: .instance,
            values: [
                AxisValue(id: "opsz-a", value: 5, name: "Micro", elidable: false),
            ]
        )
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .statOnly,
            values: [
                AxisValue(id: "wdth-a", value: 88, name: "SemiCondensed", elidable: false),
                AxisValue(id: "wdth-b", value: 100, name: "Normal", elidable: true),
            ]
        )
        let naming = NamingPolicy(order: ["opsz", "wdth"], elidedFallback: "Regular")

        let result = NamingComposer.compose(
            coords: ["opsz": 5, "wdth": 88],
            axes: [opsz, wdth],
            naming: naming
        )

        XCTAssertEqual(result.name, "Micro")
        XCTAssertEqual(result.chain.map(\.tag), ["opsz"])
    }
}

final class NamingOrderInferenceTests: XCTestCase {
    func testSuggestUsesSTATOrderingFirst() {
        let axes = [
            StatDesignAxis(tag: "wght", nameID: 1, ordering: 2),
            StatDesignAxis(tag: "opsz", nameID: 2, ordering: 0),
            StatDesignAxis(tag: "wdth", nameID: 3, ordering: 1),
        ]

        let order = NamingOrderInference.suggest(designAxes: axes)

        XCTAssertEqual(order.prefix(3), ["opsz", "wdth", "wght"])
    }

    func testSuggestAppendsFallbackTagsNotInSTAT() {
        let axes = [
            StatDesignAxis(tag: "opsz", nameID: 1, ordering: 0),
        ]

        let order = NamingOrderInference.suggest(designAxes: axes, additionalTags: ["ital"])

        XCTAssertTrue(order.contains("opsz"))
        XCTAssertTrue(order.contains("ital"))
        XCTAssertLessThan(order.firstIndex(of: "opsz")!, order.firstIndex(of: "ital")!)
    }
}
