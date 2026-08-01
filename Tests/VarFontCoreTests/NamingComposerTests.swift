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

    func testComposeUsesFormat4CompoundOverCoveredAxisStops() {
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "w350", value: 350, name: "Medium", elidable: false),
            ]
        )
        let ousd = AxisDefinition(
            tag: "ousd",
            min: 0,
            default: 0,
            max: 100,
            role: .instance,
            values: [
                AxisValue(id: "o100", value: 100, name: "Rounded", elidable: false),
            ]
        )
        let insd = AxisDefinition(
            tag: "insd",
            min: 0,
            default: 0,
            max: 100,
            role: .instance,
            values: [
                AxisValue(id: "i100", value: 100, name: "Display", elidable: false),
                AxisValue(id: "i70", value: 70, name: "70", elidable: false),
            ]
        )
        let compounds = [
            CompoundStatValue(
                id: "c1",
                coords: ["ousd": 100, "insd": 100],
                axisIndices: [1, 2],
                axisValues: [100, 100],
                name: "FullRounded",
                elidable: false
            ),
            CompoundStatValue(
                id: "c2",
                coords: ["ousd": 100, "insd": 70],
                axisIndices: [1, 2],
                axisValues: [100, 70],
                name: "DoubleRounded",
                elidable: false
            ),
        ]
        let naming = NamingPolicy(order: ["wght", "ousd", "insd"], elidedFallback: "Regular")

        let full = NamingComposer.compose(
            coords: ["wght": 350, "ousd": 100, "insd": 100],
            axes: [wght, ousd, insd],
            naming: naming,
            compounds: compounds
        )
        XCTAssertEqual(full.name, "Medium FullRounded")
        XCTAssertEqual(full.chain.map(\.kind), [.axis, .compound])
        XCTAssertEqual(full.chain.map(\.name), ["Medium", "FullRounded"])

        let double = NamingComposer.compose(
            coords: ["wght": 350, "ousd": 100, "insd": 70],
            axes: [wght, ousd, insd],
            naming: naming,
            compounds: compounds
        )
        XCTAssertEqual(double.name, "Medium DoubleRounded")
    }

    func testComposeEmitsCompoundBeforeInBetweenAxis() {
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [AxisValue(id: "w", value: 100, name: "Regular", elidable: true)]
        )
        let ousd = AxisDefinition(
            tag: "ousd",
            role: .instance,
            values: [AxisValue(id: "o", value: 100, name: "Rounded", elidable: false)]
        )
        let opsz = AxisDefinition(
            tag: "opsz",
            role: .instance,
            values: [AxisValue(id: "p", value: 14, name: "Text", elidable: false)]
        )
        let insd = AxisDefinition(
            tag: "insd",
            role: .instance,
            values: [AxisValue(id: "i", value: 100, name: "Display", elidable: false)]
        )
        let compounds = [
            CompoundStatValue(
                id: "c1",
                coords: ["ousd": 100, "insd": 100],
                axisIndices: [1, 3],
                axisValues: [100, 100],
                name: "FullRounded",
                elidable: false
            ),
        ]
        let naming = NamingPolicy(order: ["wght", "ousd", "opsz", "insd"], elidedFallback: "Regular")

        let result = NamingComposer.compose(
            coords: ["wght": 100, "ousd": 100, "opsz": 14, "insd": 100],
            axes: [wght, ousd, opsz, insd],
            naming: naming,
            compounds: compounds
        )
        XCTAssertEqual(result.name, "FullRounded Text")
        XCTAssertEqual(result.chain.map(\.name), ["Regular", "FullRounded", "Text"])
        XCTAssertTrue(result.chain[0].elided)
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
