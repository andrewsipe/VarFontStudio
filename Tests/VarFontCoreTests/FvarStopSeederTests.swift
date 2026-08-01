import XCTest
@testable import VarFontCore

final class FvarStopSeederTests: XCTestCase {
    func testSeedsMissingCustomAxisStopsFromFvarValues() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w100", value: 100, name: "Regular", elidable: true),
                    AxisValue(id: "w350", value: 350, name: "Medium", elidable: false),
                ]),
                AxisDefinition(
                    tag: "ousd",
                    displayName: "Outside Corners",
                    min: 0,
                    default: 0,
                    max: 100,
                    role: .instance,
                    values: []
                ),
                AxisDefinition(
                    tag: "insd",
                    displayName: "Inside Corners",
                    min: 0,
                    default: 0,
                    max: 100,
                    role: .instance,
                    values: []
                ),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [100, 350], observed: [100, 350]),
                analyzed(tag: "ousd", displayName: "Outside Corners", values: [], observed: [0, 20, 100]),
                analyzed(tag: "insd", displayName: "Inside Corners", values: [], observed: [0, 50, 70, 100]),
            ],
            instances: [
                instance("Regular", ["wght": 100, "ousd": 0, "insd": 0]),
                instance("Medium", ["wght": 350, "ousd": 0, "insd": 0]),
                instance("SemiRounded Regular", ["wght": 100, "ousd": 20, "insd": 0]),
                instance("SemiRounded Medium", ["wght": 350, "ousd": 20, "insd": 0]),
                instance("Rounded Regular", ["wght": 100, "ousd": 100, "insd": 0]),
                instance("Display Regular", ["wght": 100, "ousd": 0, "insd": 100]),
                instance("SemiDisplay Regular", ["wght": 100, "ousd": 0, "insd": 50]),
                instance("DoubleRounded Regular", ["wght": 100, "ousd": 100, "insd": 70]),
                instance("FullRounded Regular", ["wght": 100, "ousd": 100, "insd": 100]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)

        let ousd = try! XCTUnwrap(font.axes.first { $0.tag == "ousd" })
        let insd = try! XCTUnwrap(font.axes.first { $0.tag == "insd" })
        XCTAssertEqual(ousd.values.map(\.value), [0, 20, 100])
        XCTAssertEqual(insd.values.map(\.value), [0, 50, 70, 100])
        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 20) }?.name, "SemiRounded")
        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Rounded")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 50) }?.name, "SemiDisplay")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Display")
        // DoubleRounded only appears with ousd off default — no univariate name for 70.
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 70) }?.name, "70")
        XCTAssertTrue(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 0) }?.elidable == true)
        XCTAssertGreaterThan(report.seededStopCount, 0)
        XCTAssertTrue(report.conflicts.isEmpty)
    }

    func testReportsNameConflictWhenFvarResidueDisagreesWithSTAT() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w400", value: 400, name: "Regular", elidable: true),
                ]),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [400], observed: [400]),
            ],
            instances: [
                instance("Book", ["wght": 400]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)

        XCTAssertEqual(report.seededStopCount, 0)
        XCTAssertEqual(report.conflicts.count, 1)
        let conflict = try! XCTUnwrap(report.conflicts.first)
        XCTAssertEqual(conflict.existingName, "Regular")
        XCTAssertEqual(conflict.fvarName, "Book")
        XCTAssertEqual(conflict.existingStopID, "w400")

        FvarStopSeeder.apply(resolution: .takeFvar, conflict: conflict, to: &font)
        XCTAssertEqual(font.axes[0].values[0].name, "Book")
    }

    func testDoesNotConflictWhenNamesMatchIgnoringCase() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w400", value: 400, name: "Medium", elidable: false),
                ]),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [400], observed: [400]),
            ],
            instances: [
                instance("medium", ["wght": 400]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.conflicts.isEmpty)
        XCTAssertEqual(report.seededStopCount, 0)
    }

    // MARK: - Fixtures

    private func makeFont(axes: [AxisDefinition]) -> FontDocument {
        FontDocument(id: "font-1", sourcePath: "/tmp/Ease.ttf", dirty: false, axes: axes)
    }

    private func weightAxis(values: [AxisValue]) -> AxisDefinition {
        AxisDefinition(
            tag: "wght",
            displayName: "Weight",
            min: 100,
            default: 100,
            max: 900,
            role: .instance,
            values: values
        )
    }

    private func analyzed(
        tag: String,
        displayName: String,
        values: [Double],
        observed: [Double]
    ) -> FontAnalysis.AnalyzedAxis {
        FontAnalysis.AnalyzedAxis(
            tag: tag,
            displayName: displayName,
            min: observed.min() ?? 0,
            default: observed.first ?? 0,
            max: observed.max() ?? 0,
            roleInferred: .instance,
            variesInExistingInstances: observed.count > 1,
            valuesExisting: values.map {
                FontAnalysis.StatValueSnapshot(format: 1, value: $0, name: "\(Int($0))")
            },
            fvarValuesObserved: observed
        )
    }

    private func instance(_ name: String, _ coords: [String: Double]) -> FontAnalysis.ExistingInstance {
        FontAnalysis.ExistingInstance(
            key: InstanceKeyBuilder.makeKey(coords: coords),
            composedName: name,
            coords: coords,
            subfamilyNameID: 0,
            postscriptNameID: 0
        )
    }

    private func makeAnalysis(
        axes: [FontAnalysis.AnalyzedAxis],
        instances: [FontAnalysis.ExistingInstance]
    ) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(
                path: "/tmp/Ease.ttf",
                format: "ttf",
                familyName: "Ease",
                fullName: "Ease",
                isVariable: true
            ),
            readiness: .init(
                hasFvar: true,
                hasStat: true,
                hasDesignAxisRecord: true,
                writable: true,
                blockers: []
            ),
            axes: axes,
            statValues: [],
            instancesExisting: instances,
            nameAudit: .init(freeStart: 256, used: []),
            inferred: .init(
                isItalicFont: false,
                gridAxisTags: axes.map(\.tag),
                namingOrderSuggested: axes.map(\.tag)
            ),
            designAxisTags: axes.map(\.tag)
        )
    }
}
