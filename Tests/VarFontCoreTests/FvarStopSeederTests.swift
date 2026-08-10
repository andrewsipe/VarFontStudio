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
        // 70 is combo-only — held for Import Review, not auto-promoted.
        XCTAssertEqual(insd.values.map(\.value), [0, 50, 100])
        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 20) }?.name, "SemiRounded")
        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Rounded")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 50) }?.name, "SemiDisplay")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Display")
        XCTAssertNil(insd.values.first { AxisCoordinate.valuesEqual($0.value, 70) })
        XCTAssertTrue(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 0) }?.elidable == true)
        XCTAssertTrue(report.needsReview)
        XCTAssertTrue(report.heldStopCandidates.contains {
            $0.axisTag == "insd" && AxisCoordinate.valuesEqual($0.value, 70) && $0.classification == .comboOnly
        })
        XCTAssertGreaterThan(report.seededStopCount, 0)
        XCTAssertTrue(report.conflicts.isEmpty)
        XCTAssertNotNil(report.expansionPreview)
        XCTAssertFalse(report.expansionCallouts.isEmpty)

        let byName = Dictionary(uniqueKeysWithValues: report.compoundSuggestions.map { ($0.name.lowercased(), $0) })
        let doubleRounded = try! XCTUnwrap(byName["doublerounded"])
        XCTAssertEqual(Set(doubleRounded.coords.keys), Set(["ousd", "insd"]))
        XCTAssertEqual(doubleRounded.coords["ousd"], 100)
        XCTAssertEqual(doubleRounded.coords["insd"], 70)
        XCTAssertEqual(doubleRounded.coveredInstanceCount, 1)

        let fullRounded = try! XCTUnwrap(byName["fullrounded"])
        XCTAssertEqual(Set(fullRounded.coords.keys), Set(["ousd", "insd"]))
        XCTAssertEqual(fullRounded.coords["ousd"], 100)
        XCTAssertEqual(fullRounded.coords["insd"], 100)
        // Weight must not appear — it varies across FullRounded in real fonts; here only one sample.
        XCTAssertNil(fullRounded.coords["wght"])

        let held70 = try! XCTUnwrap(report.heldStopCandidates.first {
            $0.axisTag == "insd" && AxisCoordinate.valuesEqual($0.value, 70)
        })
        let context = try! XCTUnwrap(report.expansionPreview)
        let recommended = FvarStopSeeder.previewExpansion(
            context: context,
            decisions: [held70.id: .comboOnly],
            recommended: [held70.id: .comboOnly]
        )
        let promoted = FvarStopSeeder.previewExpansion(
            context: context,
            decisions: [held70.id: .promote],
            recommended: [held70.id: .comboOnly]
        )
        let recommendedCount = recommended?.inventedCombinationCount ?? 0
        let promotedCount = promoted?.inventedCombinationCount ?? 0
        XCTAssertGreaterThan(promotedCount, recommendedCount)
        let sampleLabels = recommended?.sampleMissingLabels ?? []
        XCTAssertTrue(
            sampleLabels.contains { $0.contains("SemiRounded") && $0.contains("SemiDisplay") },
            "Expected composed STAT name in samples, got: \(sampleLabels)"
        )
        XCTAssertTrue(
            recommended?.samples.contains { !$0.composedName.isEmpty } ?? false
        )
    }

    func testCompoundSuggestionsGroupConstantAxesAcrossWeights() {
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
                analyzed(tag: "ousd", displayName: "Outside Corners", values: [], observed: [0, 100]),
                analyzed(tag: "insd", displayName: "Inside Corners", values: [], observed: [0, 70, 100]),
            ],
            instances: [
                instance("Regular", ["wght": 100, "ousd": 0, "insd": 0]),
                instance("Medium", ["wght": 350, "ousd": 0, "insd": 0]),
                instance("Rounded Regular", ["wght": 100, "ousd": 100, "insd": 0]),
                instance("Rounded Medium", ["wght": 350, "ousd": 100, "insd": 0]),
                instance("Display Regular", ["wght": 100, "ousd": 0, "insd": 100]),
                instance("Display Medium", ["wght": 350, "ousd": 0, "insd": 100]),
                instance("DoubleRounded Regular", ["wght": 100, "ousd": 100, "insd": 70]),
                instance("DoubleRounded Medium", ["wght": 350, "ousd": 100, "insd": 70]),
                instance("FullRounded Regular", ["wght": 100, "ousd": 100, "insd": 100]),
                instance("FullRounded Medium", ["wght": 350, "ousd": 100, "insd": 100]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        let byName = Dictionary(uniqueKeysWithValues: report.compoundSuggestions.map { ($0.name.lowercased(), $0) })

        let doubleRounded = try! XCTUnwrap(byName["doublerounded"])
        XCTAssertEqual(doubleRounded.coords["ousd"], 100)
        XCTAssertEqual(doubleRounded.coords["insd"], 70)
        XCTAssertNil(doubleRounded.coords["wght"])
        XCTAssertEqual(doubleRounded.coveredInstanceCount, 2)
        XCTAssertEqual(doubleRounded.legLabels["ousd"], "Rounded")
        XCTAssertEqual(doubleRounded.legLabels["insd"], "70")

        let fullRounded = try! XCTUnwrap(byName["fullrounded"])
        XCTAssertEqual(fullRounded.coords["ousd"], 100)
        XCTAssertEqual(fullRounded.coords["insd"], 100)
        XCTAssertNil(fullRounded.coords["wght"])
        XCTAssertEqual(fullRounded.coveredInstanceCount, 2)
        XCTAssertEqual(fullRounded.legLabels["ousd"], "Rounded")
        XCTAssertEqual(fullRounded.legLabels["insd"], "Display")

        // Univariate styles must not become Format 4 suggestions.
        XCTAssertNil(byName["rounded"])
        XCTAssertNil(byName["display"])
    }

    func testCompoundSuggestionsDropWeightEvenWhenConstantAcrossGroup() {
        // Residual name only appears at one weight — without a policy filter, wght
        // would look like a constant compound leg.
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
                analyzed(tag: "ousd", displayName: "Outside Corners", values: [], observed: [0, 100]),
                analyzed(tag: "insd", displayName: "Inside Corners", values: [], observed: [0, 70]),
            ],
            instances: [
                instance("Regular", ["wght": 100, "ousd": 0, "insd": 0]),
                instance("Medium", ["wght": 350, "ousd": 0, "insd": 0]),
                instance("DoubleRounded Medium", ["wght": 350, "ousd": 100, "insd": 70]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        let suggestion = try! XCTUnwrap(
            report.compoundSuggestions.first { $0.name.caseInsensitiveCompare("DoubleRounded") == .orderedSame }
        )
        XCTAssertEqual(suggestion.coords["ousd"], 100)
        XCTAssertEqual(suggestion.coords["insd"], 70)
        XCTAssertNil(suggestion.coords["wght"])
        XCTAssertEqual(suggestion.coveredInstanceCount, 1)
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

    func testQuietOrthogonalCatalogDoesNotNeedReview() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w100", value: 100, name: "Regular", elidable: true),
                ]),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [100], observed: [100, 400]),
            ],
            instances: [
                instance("Regular", ["wght": 100]),
                instance("Bold", ["wght": 400]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertFalse(report.needsReview)
        XCTAssertTrue(report.heldStopCandidates.isEmpty)
        XCTAssertEqual(font.axes[0].values.map(\.value).sorted(), [100, 400])
        XCTAssertEqual(font.axes[0].values.first { AxisCoordinate.valuesEqual($0.value, 400) }?.name, "Bold")
        XCTAssertTrue(report.compoundSuggestions.isEmpty)
    }

    func testEmptySubfamilyNamesTriggerSparsityCalloutButStillSeedStops() {
        var font = makeFont(
            axes: [
                weightAxis(values: []),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [], observed: [100, 400]),
            ],
            instances: [
                FontAnalysis.ExistingInstance(
                    key: InstanceKeyBuilder.makeKey(coords: ["wght": 100]),
                    composedName: "",
                    coords: ["wght": 100],
                    subfamilyNameID: 0,
                    postscriptNameID: 0
                ),
                FontAnalysis.ExistingInstance(
                    key: InstanceKeyBuilder.makeKey(coords: ["wght": 400]),
                    composedName: "",
                    coords: ["wght": 400],
                    subfamilyNameID: 0,
                    postscriptNameID: 0
                ),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.needsReview)
        XCTAssertEqual(report.namingSparsity?.missingSubfamilyCount, 2)
        XCTAssertEqual(font.axes[0].values.count, 2)
        XCTAssertTrue(report.compoundSuggestions.isEmpty)
        XCTAssertTrue(report.heldStopCandidates.isEmpty)
    }

    func testSharedSubfamilyNameAcrossLocationsTriggersSparsity() {
        var font = makeFont(
            axes: [
                weightAxis(values: []),
                AxisDefinition(
                    tag: "ousd",
                    displayName: "Outside",
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
                analyzed(tag: "wght", displayName: "Weight", values: [], observed: [100]),
                analyzed(tag: "ousd", displayName: "Outside", values: [], observed: [0, 50, 100]),
            ],
            instances: [
                FontAnalysis.ExistingInstance(
                    key: "a",
                    composedName: "Style",
                    coords: ["wght": 100, "ousd": 0],
                    subfamilyNameID: 300,
                    postscriptNameID: 0
                ),
                FontAnalysis.ExistingInstance(
                    key: "b",
                    composedName: "Style",
                    coords: ["wght": 100, "ousd": 50],
                    subfamilyNameID: 300,
                    postscriptNameID: 0
                ),
                FontAnalysis.ExistingInstance(
                    key: "c",
                    composedName: "Style",
                    coords: ["wght": 100, "ousd": 100],
                    subfamilyNameID: 300,
                    postscriptNameID: 0
                ),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.needsReview)
        XCTAssertGreaterThanOrEqual(report.namingSparsity?.sharedNameCollapseSize ?? 0, 2)
    }

    func testApplyReviewDecisionsPromotesHeldComboOnlyStop() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w100", value: 100, name: "Regular", elidable: true),
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
                analyzed(tag: "wght", displayName: "Weight", values: [100], observed: [100]),
                analyzed(tag: "ousd", displayName: "Outside Corners", values: [], observed: [0, 100]),
                analyzed(tag: "insd", displayName: "Inside Corners", values: [], observed: [0, 70]),
            ],
            instances: [
                instance("Regular", ["wght": 100, "ousd": 0, "insd": 0]),
                instance("DoubleRounded", ["wght": 100, "ousd": 100, "insd": 70]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        let held70 = try! XCTUnwrap(report.heldStopCandidates.first {
            $0.axisTag == "insd" && AxisCoordinate.valuesEqual($0.value, 70)
        })
        let suggestion = try! XCTUnwrap(report.compoundSuggestions.first)

        let remaining = FvarStopSeeder.apply(
            reviewDecisions: .init(
                stopDecisions: [held70.id: .comboOnly],
                acceptedCompoundIDs: [suggestion.id]
            ),
            report: report,
            to: &font
        )

        XCTAssertNil(font.axes.first { $0.tag == "insd" }?.values.first {
            AxisCoordinate.valuesEqual($0.value, 70)
        })
        XCTAssertEqual(font.compoundStatValues.count, 1)
        XCTAssertEqual(font.compoundStatValues.first?.name, suggestion.name)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testApplyReviewDecisionsUsesPromotedStopNameOverride() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w100", value: 100, name: "Regular", elidable: true),
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
                analyzed(tag: "wght", displayName: "Weight", values: [100], observed: [100]),
                analyzed(tag: "ousd", displayName: "Outside Corners", values: [], observed: [0, 100]),
                analyzed(tag: "insd", displayName: "Inside Corners", values: [], observed: [0, 70]),
            ],
            instances: [
                instance("Regular", ["wght": 100, "ousd": 0, "insd": 0]),
                instance("DoubleRounded", ["wght": 100, "ousd": 100, "insd": 70]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        let held70 = try! XCTUnwrap(report.heldStopCandidates.first {
            $0.axisTag == "insd" && AxisCoordinate.valuesEqual($0.value, 70)
        })

        _ = FvarStopSeeder.apply(
            reviewDecisions: .init(
                stopDecisions: [held70.id: .promote],
                promotedStopNames: [held70.id: "DeepCorners"]
            ),
            report: report,
            to: &font
        )

        let stop = font.axes.first { $0.tag == "insd" }?.values.first {
            AxisCoordinate.valuesEqual($0.value, 70)
        }
        XCTAssertEqual(stop?.name, "DeepCorners")
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
