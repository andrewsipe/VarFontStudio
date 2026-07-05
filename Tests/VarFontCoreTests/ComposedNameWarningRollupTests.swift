import XCTest
@testable import VarFontCore

final class ComposedNameWarningRollupTests: XCTestCase {
    func testRollupEmitsOneWarningPerDistinctComposedName() {
        let axis = AxisDefinition(
            tag: "wght",
            min: 100,
            default: 400,
            max: 900,
            role: .instance,
            values: [
                AxisValue(id: "a", value: 400, name: "Regular", elidable: true),
                AxisValue(id: "b", value: 500, name: "Regular", elidable: false),
                AxisValue(id: "c", value: 600, name: "Regular", elidable: false),
            ]
        )
        let font = FontDocument(id: "f1", sourcePath: "/tmp/font.ttf", axes: [axis])
        let naming = NamingPolicy(order: ["wght"], elidedFallback: "Regular")
        let plan = InstancePlanner.plan(font: font, naming: naming)

        let duplicateWarnings = plan.warnings.filter { $0.code == "duplicate_composed_name" }
        XCTAssertEqual(duplicateWarnings.count, 1)
        XCTAssertEqual(duplicateWarnings[0].name, "Regular")
        XCTAssertTrue(duplicateWarnings[0].message.contains("3 instances"))
    }
}
