import XCTest
@testable import VarFontCore

final class AxisStopFillPlannerTests: XCTestCase {
    private func weightAxis(min: Double, max: Double, default defaultValue: Double? = nil) -> AxisDefinition {
        AxisDefinition(
            tag: "wght",
            min: min,
            default: defaultValue ?? min,
            max: max,
            role: .instance,
            values: []
        )
    }

    func testTypicalStepSetsDefaultCountForWeight() throws {
        let axis = weightAxis(min: 100, max: 900, default: 400)
        let options = try XCTUnwrap(AxisStopFillPlanner.options(for: axis))
        XCTAssertEqual(options.typicalStep, 100)
        XCTAssertEqual(options.defaultCount, 9)
        XCTAssertEqual(options.countRange, 2...12)
        XCTAssertEqual(
            try XCTUnwrap(AxisStopFillPlanner.values(for: axis, count: 9)),
            [100, 200, 300, 400, 500, 600, 700, 800, 900]
        )
    }

    func testDefaultCountUsesTypicalStepNotAFixedSix() throws {
        let axis = weightAxis(min: 0, max: 200)
        let options = try XCTUnwrap(AxisStopFillPlanner.options(for: axis))
        XCTAssertEqual(options.defaultCount, 3)
    }

    func testCountIsTheContractWithoutSnap() throws {
        let axis = weightAxis(min: 100, max: 900, default: 400)
        XCTAssertEqual(
            try XCTUnwrap(AxisStopFillPlanner.values(for: axis, count: 4)),
            [100, 366.67, 633.33, 900]
        )
        XCTAssertEqual(
            try XCTUnwrap(AxisStopFillPlanner.values(for: axis, count: 5)),
            [100, 300, 500, 700, 900]
        )
    }

    func testOptionalSnapMapsOntoTypicalTicksWithoutDroppingCount() throws {
        let axis = weightAxis(min: 100, max: 900, default: 400)
        XCTAssertEqual(
            try XCTUnwrap(AxisStopFillPlanner.values(for: axis, count: 4, snap: true)),
            [100, 400, 600, 900]
        )
        let plan = try XCTUnwrap(
            AxisStopFillPlanner.plan(for: axis, count: 4, snap: true, statFormat: 2)
        )
        XCTAssertTrue(plan.snapping)
        XCTAssertEqual(plan.stops.map(\.value), [100, 400, 600, 900])
        XCTAssertEqual(plan.stops.map(\.name), ["Extrathin", "Regular", "Semibold", "Black"])
        XCTAssertEqual(plan.stops.map(\.rangeMin), [100, 250, 500, 750])
        XCTAssertEqual(plan.stops.map(\.rangeMax), [250, 500, 750, 900])
        XCTAssertEqual(plan.stops.map(\.elidable), [false, true, false, false])
    }

    func testSnapDoesNotApplyWhenCountExceedsTicks() throws {
        let axis = weightAxis(min: 100, max: 900)
        let plan = try XCTUnwrap(
            AxisStopFillPlanner.plan(for: axis, count: 12, snap: true, statFormat: 1)
        )
        XCTAssertFalse(plan.snapFits)
        XCTAssertFalse(plan.snapping)
        XCTAssertEqual(plan.stops.count, 12)
    }

    func testFormat1WritesNomsOnly() throws {
        let axis = weightAxis(min: 100, max: 900, default: 400)
        let plan = try XCTUnwrap(
            AxisStopFillPlanner.plan(for: axis, count: 4, snap: false, statFormat: 1)
        )
        XCTAssertEqual(plan.statFormat, 1)
        XCTAssertEqual(plan.stops.map(\.statFormat), [1, 1, 1, 1])
        XCTAssertEqual(plan.stops.map(\.name), ["Extrathin", "366.67", "633.33", "Black"])
    }

    func testWidthTypicalStep() throws {
        let axis = AxisDefinition(tag: "wdth", min: 75, default: 100, max: 125, role: .instance, values: [])
        let options = try XCTUnwrap(AxisStopFillPlanner.options(for: axis))
        XCTAssertEqual(options.typicalStep, 25)
        XCTAssertEqual(options.defaultCount, 3)
        XCTAssertEqual(
            try XCTUnwrap(AxisStopFillPlanner.values(for: axis, count: 3, snap: true)),
            [75, 100, 125]
        )
    }

    func testNarrowRangeStillOffersCountSlider() throws {
        let axis = weightAxis(min: 0, max: 10)
        let options = try XCTUnwrap(AxisStopFillPlanner.options(for: axis))
        XCTAssertTrue(options.countRange.contains(options.defaultCount))
    }

    func testBooleanStyleAxisDoesNotSupportFill() {
        let axis = AxisDefinition(tag: "ital", min: 0, default: 0, max: 1, role: .instance, values: [])
        XCTAssertFalse(AxisStopFillPlanner.supportsFill(axis))
        XCTAssertNil(AxisStopFillPlanner.options(for: axis))
    }

    func testFillSupportedRegardlessOfExistingStops() {
        var axis = weightAxis(min: 0, max: 200)
        axis.values = [AxisValue(id: "1", value: 100, name: "Regular", elidable: true)]
        XCTAssertTrue(AxisStopFillPlanner.supportsFill(axis))
        XCTAssertNotNil(AxisStopFillPlanner.options(for: axis))
    }

    func testDefaultFormatFollowsExistingStops() {
        var axis = weightAxis(min: 100, max: 900, default: 400)
        XCTAssertEqual(AxisStopFillPlanner.defaultFormat(for: axis), 1)
        axis.values = [
            AxisValue(id: "1", value: 100, name: "Thin", elidable: false, statFormat: 2, rangeMin: 100, rangeMax: 150),
        ]
        XCTAssertEqual(AxisStopFillPlanner.defaultFormat(for: axis), 2)
    }
}

final class AxisStopRangeGeometryTests: XCTestCase {
    func testTileUsesMidpointsAndClampsEnds() {
        let tiled = AxisStopRangeGeometry.tile(noms: [100, 400, 900], axisMin: 100, axisMax: 900)
        XCTAssertEqual(tiled.map(\.min), [100, 250, 650])
        XCTAssertEqual(tiled.map(\.nom), [100, 400, 900])
        XCTAssertEqual(tiled.map(\.max), [250, 650, 900])
    }

    func testInsertNipsOnlyNeighbors() throws {
        let existing: [AxisValue] = [
            AxisValue(id: "thin", value: 200, name: "Thin", elidable: false, statFormat: 2, rangeMin: 100, rangeMax: 250),
            AxisValue(id: "light", value: 300, name: "Light", elidable: false, statFormat: 2, rangeMin: 250, rangeMax: 350),
            AxisValue(id: "reg", value: 400, name: "Regular", elidable: true, statFormat: 2, rangeMin: 350, rangeMax: 450),
        ]
        let plan = try AxisStopRangeGeometry.insert(
            [AxisStopRangeGeometry.InsertRequest(value: 250, name: "ExtraLight")],
            into: existing,
            axisMin: 100,
            axisMax: 900,
            makeID: { _ in "new" }
        ).get()

        XCTAssertEqual(plan.insertedIDs, ["new"])
        XCTAssertEqual(plan.values.map(\.name), ["Thin", "ExtraLight", "Light", "Regular"])
        let extra = try XCTUnwrap(plan.values.first { $0.id == "new" })
        XCTAssertEqual(extra.statFormat, 2)
        XCTAssertEqual(extra.rangeMin, 225)
        XCTAssertEqual(extra.rangeMax, 275)
        XCTAssertEqual(plan.values.first { $0.id == "thin" }?.rangeMax, 225)
        XCTAssertEqual(plan.values.first { $0.id == "light" }?.rangeMin, 275)
        XCTAssertEqual(plan.values.first { $0.id == "reg" }?.rangeMin, 350)
        XCTAssertEqual(plan.values.first { $0.id == "reg" }?.rangeMax, 450)
        XCTAssertEqual(plan.rewrites.map(\.name), ["Thin", "Light"])
    }

    func testInsertRejectsDuplicateNom() {
        let existing = [
            AxisValue(id: "thin", value: 200, name: "Thin", elidable: false),
        ]
        let result = AxisStopRangeGeometry.insert(
            [AxisStopRangeGeometry.InsertRequest(value: 200, name: "Thin")],
            into: existing,
            axisMin: 100,
            axisMax: 900,
            makeID: { _ in "new" }
        )
        guard case .failure(.duplicate(let value)) = result else {
            return XCTFail("expected duplicate")
        }
        XCTAssertEqual(value, 200)
    }

    func testInsertPromotesFormat1Neighbor() throws {
        let existing = [
            AxisValue(id: "thin", value: 200, name: "Thin", elidable: false, statFormat: 1),
            AxisValue(id: "reg", value: 400, name: "Regular", elidable: true, statFormat: 1),
        ]
        let plan = try AxisStopRangeGeometry.insert(
            [AxisStopRangeGeometry.InsertRequest(value: 300, name: "Light")],
            into: existing,
            axisMin: 100,
            axisMax: 900,
            makeID: { _ in "light" }
        ).get()
        XCTAssertEqual(plan.values.first { $0.id == "thin" }?.statFormat, 2)
        XCTAssertEqual(plan.values.first { $0.id == "thin" }?.rangeMax, 250)
        XCTAssertEqual(plan.values.first { $0.id == "reg" }?.statFormat, 2)
        XCTAssertEqual(plan.values.first { $0.id == "reg" }?.rangeMin, 350)
    }
}
