import XCTest
@testable import VarFontCore

final class InstancePlannerCompoundTests: XCTestCase {
    func testOffGridFormat4CompoundsAppearAsInstances() throws {
        var font = FontDocument(
            id: "font-1",
            sourcePath: "/tmp/Interchange.ttf",
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "opsz",
                    displayName: "Optical Size",
                    min: 1,
                    default: 1,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "o1", value: 1, name: "Micro", elidable: false),
                        AxisValue(id: "o2", value: 19.73, name: "Standard", elidable: true),
                        AxisValue(id: "o3", value: 54.51, name: "Title", elidable: false),
                        AxisValue(id: "o4", value: 100, name: "Poster", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 1,
                    default: 34,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 44.02, name: "Regular", elidable: false),
                        AxisValue(id: "w2", value: 52.55, name: "Medium", elidable: false),
                        AxisValue(id: "w3", value: 65.38, name: "Bold", elidable: false),
                        AxisValue(id: "w4", value: 77.94, name: "Extra Bold", elidable: false),
                        AxisValue(id: "w5", value: 89.43, name: "Black", elidable: false),
                        AxisValue(id: "w6", value: 100, name: "Extra Black", elidable: false),
                    ]
                ),
            ]
        )
        font.compoundStatValues = [
            CompoundStatValue(
                id: "c1",
                coords: ["opsz": 100, "wght": 1],
                axisIndices: [],
                axisValues: [],
                name: "Poster Extra Thin",
                elidable: false
            ),
            CompoundStatValue(
                id: "c2",
                coords: ["opsz": 1, "wght": 15.01],
                axisIndices: [],
                axisValues: [],
                name: "Micro Extra Thin",
                elidable: false
            ),
            CompoundStatValue(
                id: "c3",
                coords: ["opsz": 1, "wght": 28.08],
                axisIndices: [],
                axisValues: [],
                name: "Micro Extra Light",
                elidable: false
            ),
            CompoundStatValue(
                id: "c4",
                coords: ["opsz": 1, "wght": 37.55],
                axisIndices: [],
                axisValues: [],
                name: "Micro Light",
                elidable: false
            ),
        ]

        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["opsz", "wght"], elidedFallback: "Regular")
        )

        XCTAssertEqual(plan.formula.parts, [4, 6])
        XCTAssertEqual(plan.formula.totalGenerated, 28, "24 orthogonal + 4 off-grid Format 4")

        let names = plan.instances.map(\.composedName)
        let microExtraThin = try XCTUnwrap(names.firstIndex(of: "Micro Extra Thin"))
        let microExtraLight = try XCTUnwrap(names.firstIndex(of: "Micro Extra Light"))
        let microLight = try XCTUnwrap(names.firstIndex(of: "Micro Light"))
        let microRegular = try XCTUnwrap(names.firstIndex(of: "Micro Regular"))
        let microMedium = try XCTUnwrap(names.firstIndex(of: "Micro Medium"))
        let standardRegular = try XCTUnwrap(names.firstIndex(of: "Regular"))
        let posterExtraThin = try XCTUnwrap(names.firstIndex(of: "Poster Extra Thin"))

        // Same rule as Axis Tree value order: off-grid Format 4 wghts participate by
        // coordinate, not "after every Format 1 stop".
        XCTAssertLessThan(microExtraThin, microExtraLight)
        XCTAssertLessThan(microExtraLight, microLight)
        XCTAssertLessThan(microLight, microRegular)
        XCTAssertLessThan(microRegular, microMedium)
        XCTAssertLessThan(microMedium, standardRegular, "finish Micro group before Standard")
        XCTAssertGreaterThan(posterExtraThin, standardRegular, "Poster Format 4 stays with Poster")
    }

    func testNamingOverlayCompoundsDoNotDuplicateGridCells() {
        var font = FontDocument(
            id: "font-1",
            sourcePath: "/tmp/Ease.ttf",
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 100,
                    default: 100,
                    max: 900,
                    role: .instance,
                    values: [
                        AxisValue(id: "w100", value: 100, name: "Regular", elidable: true),
                        AxisValue(id: "w700", value: 700, name: "Bold", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "ousd",
                    displayName: "Outside",
                    min: 0,
                    default: 0,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "o0", value: 0, name: "Default", elidable: true),
                        AxisValue(id: "o100", value: 100, name: "Rounded", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "insd",
                    displayName: "Inside",
                    min: 0,
                    default: 0,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "i0", value: 0, name: "Default", elidable: true),
                        AxisValue(id: "i70", value: 70, name: "Deep", elidable: false),
                    ]
                ),
            ]
        )
        // Naming overlay across weights — must not invent a third wght-less instance.
        font.compoundStatValues = [
            CompoundStatValue(
                id: "c1",
                coords: ["ousd": 100, "insd": 70],
                axisIndices: [],
                axisValues: [],
                name: "DoubleRounded",
                elidable: false
            ),
        ]

        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["ousd", "insd", "wght"], elidedFallback: "Regular")
        )

        XCTAssertEqual(plan.formula.totalGenerated, 8, "2×2×2 product only; compound is naming overlay")
        XCTAssertTrue(plan.instances.contains { $0.composedName == "DoubleRounded" })
    }

    func testCompoundsSortByAxisOrderNotAlphabetically() {
        let axes = [
            AxisDefinition(
                tag: "opsz",
                displayName: "Optical Size",
                min: 1, default: 1, max: 100, role: .instance,
                values: [
                    AxisValue(id: "o1", value: 1, name: "Micro", elidable: false),
                    AxisValue(id: "o2", value: 100, name: "Poster", elidable: false),
                ]
            ),
            AxisDefinition(
                tag: "wght",
                displayName: "Weight",
                min: 1, default: 34, max: 100, role: .instance,
                values: [
                    AxisValue(id: "w1", value: 44, name: "Regular", elidable: false),
                ]
            ),
        ]
        let compounds = [
            CompoundStatValue(id: "a", coords: ["opsz": 100, "wght": 1], axisIndices: [], axisValues: [], name: "Poster Extra Thin", elidable: false),
            CompoundStatValue(id: "b", coords: ["opsz": 1, "wght": 15], axisIndices: [], axisValues: [], name: "Micro Extra Thin", elidable: false),
            CompoundStatValue(id: "c", coords: ["opsz": 1, "wght": 20], axisIndices: [], axisValues: [], name: "Micro Thin", elidable: false),
            CompoundStatValue(id: "d", coords: ["opsz": 100, "wght": 5], axisIndices: [], axisValues: [], name: "Poster Thin", elidable: false),
        ]

        let sorted = CompoundStatNaming.sortedByAxisOrder(
            compounds,
            axes: axes,
            namingOrder: ["opsz", "wght"]
        )
        XCTAssertEqual(sorted.map(\.name), [
            "Micro Extra Thin",
            "Micro Thin",
            "Poster Extra Thin",
            "Poster Thin",
        ])
    }
}
