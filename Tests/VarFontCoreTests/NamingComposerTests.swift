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

        let order = NamingOrderInference.suggest(
            designAxes: axes,
            fvarAxisTags: ["opsz", "wdth", "wght"]
        )

        XCTAssertEqual(order, ["opsz", "wdth", "wght"])
    }

    func testPlayfairLikeIncludesItalFromSTATButNotPhantomSlnt() {
        let designAxes = [
            StatDesignAxis(tag: "opsz", nameID: 1, ordering: 0),
            StatDesignAxis(tag: "wdth", nameID: 2, ordering: 1),
            StatDesignAxis(tag: "wght", nameID: 3, ordering: 2),
            StatDesignAxis(tag: "ital", nameID: 4, ordering: 3),
        ]

        let order = NamingOrderInference.suggest(
            designAxes: designAxes,
            fvarAxisTags: ["opsz", "wdth", "wght"]
        )

        XCTAssertEqual(order, ["opsz", "wdth", "wght", "ital"])
        XCTAssertFalse(order.contains("slnt"))
    }

    func testMelangeLikeExcludesPhantomAxes() {
        let designAxes = [
            StatDesignAxis(tag: "wdth", nameID: 1, ordering: 0),
            StatDesignAxis(tag: "wght", nameID: 2, ordering: 1),
        ]

        let order = NamingOrderInference.suggest(
            designAxes: designAxes,
            fvarAxisTags: ["wdth", "wght"]
        )

        XCTAssertEqual(order, ["wdth", "wght"])
        XCTAssertFalse(order.contains("opsz"))
        XCTAssertFalse(order.contains("slnt"))
        XCTAssertFalse(order.contains("ital"))
    }

    func testRobotoLikeRetainsSlntBeforeItal() {
        let designAxes = [
            StatDesignAxis(tag: "opsz", nameID: 1, ordering: 0),
            StatDesignAxis(tag: "wght", nameID: 2, ordering: 1),
            StatDesignAxis(tag: "wdth", nameID: 3, ordering: 2),
            StatDesignAxis(tag: "ital", nameID: 4, ordering: 4),
            StatDesignAxis(tag: "slnt", nameID: 5, ordering: 3),
        ]

        let order = NamingOrderInference.suggest(
            designAxes: designAxes,
            fvarAxisTags: ["opsz", "wght", "wdth", "slnt"]
        )

        XCTAssertEqual(order, ["opsz", "wght", "wdth", "slnt", "ital"])
        XCTAssertLessThan(order.firstIndex(of: "slnt")!, order.firstIndex(of: "ital")!)
    }
}
