import XCTest
@testable import VarFontCore

final class AxisStopGapFillTests: XCTestCase {
    private func axis(
        tag: String = "wght",
        min: Double = 100,
        max: Double = 900,
        values: [Double]
    ) -> AxisDefinition {
        AxisDefinition(
            tag: tag,
            min: min,
            default: min,
            max: max,
            role: .instance,
            values: values.enumerated().map { index, value in
                AxisValue(
                    id: "s\(index)",
                    value: value,
                    name: AxisStopSuggestions.formatValue(value),
                    elidable: false
                )
            }
        )
    }

    func testCommonWeightLadderFillsTwoHundredSixHundredEightHundred() throws {
        let proposal = try XCTUnwrap(
            AxisStopGapFill.proposal(
                for: axis(values: [100, 300, 400, 500, 700, 900])
            )
        )
        XCTAssertEqual(proposal.values, [200, 600, 800])
        XCTAssertEqual(proposal.step, 100)
        XCTAssertEqual(proposal.previewLabel, "200, 600, 800")
    }

    func testDoesNotInventAFineGridFromThreeSparseMasters() {
        XCTAssertNil(AxisStopGapFill.proposal(for: axis(values: [100, 400, 900])))
    }

    func testTwoStopsAreTooSparse() {
        XCTAssertNil(AxisStopGapFill.proposal(for: axis(values: [400, 700])))
    }

    func testCompleteHundredStepLadderHasNoGaps() {
        XCTAssertNil(
            AxisStopGapFill.proposal(
                for: axis(values: [100, 200, 300, 400, 500, 600, 700, 800, 900])
            )
        )
    }

    func testSingleInteriorHoleOnInferredGrid() throws {
        let proposal = try XCTUnwrap(
            AxisStopGapFill.proposal(for: axis(values: [100, 200, 400, 500]))
        )
        XCTAssertEqual(proposal.values, [300])
    }

    func testIrregularOpticalSizeDoesNotMeshFill() {
        XCTAssertNil(
            AxisStopGapFill.proposal(
                for: axis(tag: "opsz", min: 8, max: 36, values: [8, 14, 36])
            )
        )
    }

    func testRegularOpticalSizeFillsDoubleGap() throws {
        let proposal = try XCTUnwrap(
            AxisStopGapFill.proposal(
                for: axis(tag: "opsz", min: 8, max: 24, values: [8, 12, 16, 24])
            )
        )
        XCTAssertEqual(proposal.values, [20])
        XCTAssertEqual(proposal.step, 4)
    }

    func testKeepsExistingStopsOutOfTheProposal() throws {
        let proposal = try XCTUnwrap(
            AxisStopGapFill.proposal(
                for: axis(values: [100, 300, 400, 500, 700, 900])
            )
        )
        XCTAssertFalse(proposal.values.contains { AxisCoordinate.valuesEqual($0, 400) })
    }

    func testDesignRecordOnlyAxisIsSkipped() {
        let skipped = axis(values: [100, 300, 400, 500, 700, 900])
        let designRecord = AxisDefinition(
            tag: skipped.tag,
            min: skipped.min,
            default: skipped.default,
            max: skipped.max,
            role: .designRecordOnly,
            values: skipped.values
        )
        XCTAssertNil(AxisStopGapFill.proposal(for: designRecord))
    }
}
