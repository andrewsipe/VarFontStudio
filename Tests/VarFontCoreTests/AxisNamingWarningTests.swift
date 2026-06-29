import XCTest
@testable import VarFontCore

final class AxisNamingWarningTests: XCTestCase {
    func testDuplicateStopNameProducesWarningWithStopIDs() {
        let axis = AxisDefinition(
            tag: "wdth",
            displayName: "Width",
            role: .instance,
            values: [
                AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
                AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
            ]
        )

        let warnings = AxisStopValidator.validate(axes: [axis])
        let match = warnings.first { $0.code == "duplicate_stop_name" }

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.axis, "wdth")
        XCTAssertEqual(Set(match?.stopIDs ?? []), ["a", "b"])
        XCTAssertNotNil(match?.hint)
    }

    func testDuplicateStopValueProducesWarningWithStopIDs() {
        let axis = AxisDefinition(
            tag: "wdth",
            displayName: "Width",
            role: .instance,
            values: [
                AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
                AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
            ]
        )

        let warnings = AxisStopValidator.validate(axes: [axis])
        let match = warnings.first { $0.code == "duplicate_stop_value" }

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.axis, "wdth")
        XCTAssertEqual(Set(match?.stopIDs ?? []), ["a", "b"])
        XCTAssertNotNil(match?.hint)
    }

    func testComposedNameDuplicateWarningIdentifiesSharedStopName() {
        let axes = [
            AxisDefinition(
                tag: "wdth",
                displayName: "Width",
                role: .instance,
                values: [
                    AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
                    AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
                ]
            ),
        ]
        let naming = NamingPolicy(order: ["wdth"], elidedFallback: "Regular")

        let warning = NamingConflictAnalyzer.composedNameDuplicateWarning(
            composedName: "Normal",
            priorKey: "wdth:100",
            priorCoords: ["wdth": 100],
            currentKey: "wdth:101",
            currentCoords: ["wdth": 101],
            axes: axes,
            naming: naming
        )

        XCTAssertEqual(warning.code, "duplicate_composed_name")
        XCTAssertEqual(Set(warning.stopIDs ?? []), ["a", "b"])
        XCTAssertTrue(warning.message.contains("Normal"))
        XCTAssertNotNil(warning.hint)
    }

    func testPlanIncludesAxisStopWarnings() {
        let font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [
                        AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
                        AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [
                        AxisValue(id: "c", value: 400, name: "Regular", elidable: false),
                        AxisValue(id: "d", value: 700, name: "Bold", elidable: false),
                    ]
                ),
            ],
            options: CommitOptions(),
            includedInstanceKeys: [],
            excludedInstanceKeys: [],
            overrides: InstanceOverrides()
        )

        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["wdth", "wght"], elidedFallback: "Regular")
        )

        XCTAssertTrue(plan.warnings.contains { $0.code == "duplicate_stop_name" })
        XCTAssertTrue(plan.instances.contains { $0.duplicate })
        XCTAssertTrue(plan.warnings.contains { $0.code == "duplicate_composed_name" })
    }

    func testAllInstancesInDuplicateNameGroupAreMarked() {
        let font = FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [
                        AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
                        AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
                    ]
                ),
            ],
            options: CommitOptions(),
            includedInstanceKeys: [],
            excludedInstanceKeys: [],
            overrides: InstanceOverrides()
        )

        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular")
        )

        XCTAssertEqual(plan.instances.count, 2)
        XCTAssertTrue(plan.instances.allSatisfy(\.duplicate))
    }
}
