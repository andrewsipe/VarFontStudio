import XCTest
@testable import VarFontCore

final class AxisLadderAlignmentTests: XCTestCase {
    func testSupportsAlignmentOnlyWeightAndWidth() {
        XCTAssertTrue(AxisLadderAlignment.supportsAlignment("wght"))
        XCTAssertTrue(AxisLadderAlignment.supportsAlignment("wdth"))
        XCTAssertFalse(AxisLadderAlignment.supportsAlignment("opsz"))
        XCTAssertFalse(AxisLadderAlignment.supportsAlignment("ital"))
    }

    func testPlannerDoesNotEmitLadderWarnings() {
        let axis = AxisDefinition(
            tag: "wght",
            min: 360,
            default: 360,
            max: 900,
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 360, name: "SemiLight", elidable: false, statFormat: 1),
                AxisValue(id: "w2", value: 400, name: "Normal", elidable: true, statFormat: 1),
            ],
            referenceMapping: .stopAnchored,
            referenceMappingInferred: .stopAnchored
        )
        let font = FontDocument(
            id: "f1",
            sourcePath: "/tmp/font.ttf",
            axes: [axis]
        )
        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["wght"], elidedFallback: "Regular")
        )
        XCTAssertFalse(plan.warnings.contains { $0.code.hasPrefix("ladder_") })
    }
}
