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
            decisions: [held70.id: .combo],
            recommended: [held70.id: .combo]
        )
        let promoted = FvarStopSeeder.previewExpansion(
            context: context,
            decisions: [held70.id: .stop],
            recommended: [held70.id: .combo]
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

    func testEmptySTATNameUsesCoordinateInConflictAndPrefersFvarName() {
        var font = makeFont(
            axes: [
                weightAxis(values: [
                    AxisValue(id: "w400", value: 400, name: "", elidable: false),
                ]),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [400], observed: [400]),
            ],
            instances: [
                instance("Regular", ["wght": 400]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)

        XCTAssertEqual(report.conflicts.count, 1)
        let conflict = try! XCTUnwrap(report.conflicts.first)
        XCTAssertEqual(conflict.existingName, "400")
        XCTAssertEqual(conflict.fvarName, "Regular")
        XCTAssertTrue(conflict.existingNameWasEmpty)
        XCTAssertEqual(conflict.recommendedResolution, .takeFvar)

        FvarStopSeeder.apply(resolution: .keepSTAT, conflict: conflict, to: &font)
        XCTAssertEqual(font.axes[0].values[0].name, "400")

        font.axes[0].values[0].name = ""
        FvarStopSeeder.apply(resolution: .takeFvar, conflict: conflict, to: &font)
        XCTAssertEqual(font.axes[0].values[0].name, "Regular")
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

    func testCodedInstanceNamesStripPrefixAndDoNotWriteStopCode() {
        var font = makeFont(
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    displayName: "Width",
                    min: 75,
                    default: 100,
                    max: 100,
                    role: .instance,
                    values: []
                ),
                weightAxis(values: []),
            ]
        )
        font.axes[1].min = 400
        font.axes[1].default = 400
        font.axes[1].max = 700
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wdth", displayName: "Width", values: [], observed: [75, 100]),
                analyzed(tag: "wght", displayName: "Weight", values: [], observed: [400, 700]),
            ],
            instances: [
                instance("24 Condensed Regular", ["wdth": 75, "wght": 400]),
                instance("27 Condensed Bold", ["wdth": 75, "wght": 700]),
                instance("44 Normal Regular", ["wdth": 100, "wght": 400]),
                instance("47 Normal Bold", ["wdth": 100, "wght": 700]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.needsReview)
        XCTAssertEqual(report.codedNaming?.prefixes, ["24", "27", "44", "47"])
        XCTAssertTrue(report.reviewReason.contains("coded instance names"))
        XCTAssertTrue(report.heldStopCandidates.isEmpty, "Coded naming is awareness-only — still seed stops")

        let wdth = try! XCTUnwrap(font.axes.first { $0.tag == "wdth" })
        let wght = try! XCTUnwrap(font.axes.first { $0.tag == "wght" })
        XCTAssertEqual(wdth.values.first { AxisCoordinate.valuesEqual($0.value, 75) }?.name, "Condensed")
        XCTAssertEqual(wdth.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Normal")
        XCTAssertEqual(wght.values.first { AxisCoordinate.valuesEqual($0.value, 400) }?.name, "Regular")
        XCTAssertEqual(wght.values.first { AxisCoordinate.valuesEqual($0.value, 700) }?.name, "Bold")
        XCTAssertTrue(font.axes.flatMap(\.values).allSatisfy { $0.code == nil })
    }

    func testCodedDetectionLeavesExistingSTATNamesAlone() {
        var font = makeFont(
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    displayName: "Width",
                    min: 75,
                    default: 100,
                    max: 100,
                    role: .instance,
                    values: [
                        AxisValue(id: "w75", value: 75, name: "24 Condensed", elidable: false),
                        AxisValue(id: "w100", value: 100, name: "Normal", elidable: true),
                    ]
                ),
                weightAxis(values: [
                    AxisValue(id: "w400", value: 400, name: "Regular", elidable: true),
                    AxisValue(id: "w700", value: 700, name: "Bold", elidable: false),
                ]),
            ]
        )
        font.axes[1].min = 400
        font.axes[1].default = 400
        font.axes[1].max = 700
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wdth", displayName: "Width", values: [75, 100], observed: [75, 100]),
                analyzed(tag: "wght", displayName: "Weight", values: [400, 700], observed: [400, 700]),
            ],
            instances: [
                instance("24 Condensed Regular", ["wdth": 75, "wght": 400]),
                instance("27 Condensed Bold", ["wdth": 75, "wght": 700]),
                instance("44 Normal Regular", ["wdth": 100, "wght": 400]),
                instance("47 Normal Bold", ["wdth": 100, "wght": 700]),
            ]
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertNotNil(report.codedNaming)
        let wdth = try! XCTUnwrap(font.axes.first { $0.tag == "wdth" })
        XCTAssertEqual(wdth.values.first { AxisCoordinate.valuesEqual($0.value, 75) }?.name, "24 Condensed")
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
                stopDispositions: [held70.id: .combo],
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
                stopDispositions: [held70.id: .stop],
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

    func testShearedWeightLadderPromotesExtremesAndHoldsEntangledLightEnd() {
        // Interchange-Variable.ttf's real coordinates: 10 named weights × 4 optical sizes, wght
        // opsz-compensated (same name, different coordinate per opsz), opsz itself clean.
        let roles = ["Micro", "", "Title", "Poster"]
        let opszByRole: [String: Double] = ["Micro": 1.0, "": 19.73, "Title": 54.51, "Poster": 100.0]
        let weightLadder: [String: [Double]] = [
            "Extra Thin": [15.01, 10.36, 5.66, 1.00],
            "Thin": [20.26, 15.24, 10.18, 5.16],
            "Extra Light": [28.08, 23.02, 17.91, 12.80],
            "Light": [37.55, 32.73, 27.99, 23.24],
            "Regular": [48.12, 44.02, 39.91, 35.80],
            "Medium": [59.25, 55.92, 52.55, 49.18],
            "Bold": [69.95, 67.65, 65.38, 63.08],
            "Extra Bold": [80.80, 79.37, 77.94, 76.51],
            "Black": [90.45, 89.94, 89.43, 88.92],
            "Extra Black": [100.00, 100.00, 100.00, 100.00],
        ]

        var instances: [FontAnalysis.ExistingInstance] = []
        var allWght: Set<Double> = []
        for (weightName, values) in weightLadder {
            for (index, role) in roles.enumerated() {
                let wght = values[index]
                allWght.insert(wght)
                let name = role.isEmpty ? weightName : "\(role) \(weightName)"
                instances.append(instance(name, ["wght": wght, "opsz": opszByRole[role]!]))
            }
        }

        var font = makeFont(
            axes: [
                AxisDefinition(tag: "wght", displayName: "Weight", min: 1, default: 34, max: 100, role: .instance, values: []),
                AxisDefinition(tag: "opsz", displayName: "Optical Size", min: 1, default: 1, max: 100, role: .instance, values: []),
            ]
        )
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [], observed: Array(allWght)),
                analyzed(tag: "opsz", displayName: "Optical Size", values: [], observed: [1.0, 19.73, 54.51, 100.0]),
            ],
            instances: instances
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.needsReview)

        func candidate(_ tag: String, _ value: Double) -> FvarStopSeeder.StopCandidate? {
            report.heldStopCandidates.first { $0.axisTag == tag && AxisCoordinate.valuesEqual($0.value, value) }
        }

        // opsz: clean, no entanglement — every coordinate is named from the font. The
        // axis-default slice (Micro, opsz=1.0) is safe enough to auto-apply immediately;
        // the rest are held for review but still recommended as stops.
        let opszAxis = try! XCTUnwrap(font.axes.first { $0.tag == "opsz" })
        XCTAssertEqual(opszAxis.values.first { AxisCoordinate.valuesEqual($0.value, 1.0) }?.name, "Micro")
        XCTAssertEqual(candidate("opsz", 54.51)?.proposedName, "Title")
        XCTAssertEqual(candidate("opsz", 100.0)?.proposedName, "Poster")
        for value in [19.73, 54.51, 100.0] {
            XCTAssertEqual(candidate("opsz", value)?.recommendedDisposition, .stop, "opsz=\(value)")
        }

        // Clean weights (heavies + gray band): exactly one Stop coordinate per name, rest Neither.
        for name in ["Extra Black", "Black", "Extra Bold", "Bold", "Medium", "Regular"] {
            let members = report.heldStopCandidates.filter { $0.axisTag == "wght" && $0.clusterName == name }
            XCTAssertFalse(members.isEmpty, name)
            XCTAssertEqual(
                members.filter { $0.recommendedDisposition.asStop }.count, 1,
                "\(name) should promote exactly one canonical coordinate"
            )
            XCTAssertTrue(
                members.filter { !$0.recommendedDisposition.asStop }.allSatisfy { $0.recommendedDisposition.isNeither },
                "\(name) non-canonical members should be Neither, not Combo"
            )
        }

        // Light end: overlapping ranges — Combo only (Format 4 with wght as a leg).
        for name in ["Extra Thin", "Thin", "Extra Light", "Light"] {
            let members = report.heldStopCandidates.filter { $0.axisTag == "wght" && $0.clusterName == name }
            XCTAssertEqual(members.count, 4, name)
            XCTAssertTrue(members.allSatisfy { $0.recommendedDisposition == .combo }, name)
        }

        // Combo styles for each light-end instance (4 opsz × 4 weights), named from fvar.
        let lightNames = ["Extra Thin", "Thin", "Extra Light", "Light"]
        for weight in lightNames {
            let combos = report.compoundSuggestions.filter {
                $0.legLabels["wght"]?.caseInsensitiveCompare(weight) == .orderedSame
            }
            XCTAssertEqual(combos.count, 4, "\(weight) combos: \(combos.map(\.name))")
        }
        XCTAssertTrue(report.compoundSuggestions.contains {
            $0.name == "Poster Extra Thin"
                && AxisCoordinate.valuesEqual($0.coords["wght"] ?? -1, 1.00)
                && AxisCoordinate.valuesEqual($0.coords["opsz"] ?? -1, 100.0)
        })
    }

    func testCharacterSetAddOnsDoNotDropLightCombos() {
        let roles = ["Micro", "", "Title", "Poster"]
        let opszByRole: [String: Double] = ["Micro": 1.0, "": 19.73, "Title": 54.51, "Poster": 100.0]
        let weightLadder: [String: [Double]] = [
            "Extra Thin": [15.01, 10.36, 5.66, 1.00],
            "Thin": [20.26, 15.24, 10.18, 5.16],
            "Extra Light": [28.08, 23.02, 17.91, 12.80],
            "Light": [37.55, 32.73, 27.99, 23.24],
            "Regular": [48.12, 44.02, 39.91, 35.80],
            "Medium": [59.25, 55.92, 52.55, 49.18],
            "Bold": [69.95, 67.65, 65.38, 63.08],
            "Extra Bold": [80.80, 79.37, 77.94, 76.51],
            "Black": [90.45, 89.94, 89.43, 88.92],
            "Extra Black": [100.00, 100.00, 100.00, 100.00],
        ]
        var instances: [FontAnalysis.ExistingInstance] = []
        var allWght: Set<Double> = []
        for (weightName, values) in weightLadder {
            for (index, role) in roles.enumerated() {
                let wght = values[index]
                allWght.insert(wght)
                let name = role.isEmpty ? weightName : "\(role) \(weightName)"
                instances.append(instance(name, ["wght": wght, "opsz": opszByRole[role]!]))
            }
        }
        instances.append(instance("Character Set Regular", ["wght": 44.02, "opsz": 19.73]))
        instances.append(instance("Poster Character Set Regular", ["wght": 35.8, "opsz": 100.0]))

        var font = makeFont(axes: [
            AxisDefinition(tag: "wght", displayName: "Weight", min: 1, default: 34, max: 100, role: .instance, values: []),
            AxisDefinition(tag: "opsz", displayName: "Optical Size", min: 1, default: 1, max: 100, role: .instance, values: []),
        ])
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: [], observed: Array(allWght)),
                analyzed(tag: "opsz", displayName: "Optical Size", values: [], observed: [1.0, 19.73, 54.51, 100.0]),
            ],
            instances: instances
        )
        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        for weight in ["Extra Thin", "Thin", "Extra Light", "Light"] {
            let combos = report.compoundSuggestions.filter {
                $0.legLabels["wght"]?.caseInsensitiveCompare(weight) == .orderedSame
            }
            XCTAssertEqual(combos.count, 4, "\(weight): \(combos.map(\.name))")
        }
    }

    /// Interchange ships a broken STAT: wght Format 1 stops in the wrong coordinate space
    /// (names like Poster/Title, values up to 220) and opsz stops that don't match fvar.
    /// Seed must drop those so Import Review choices actually control the instance grid.
    func testWrongSpaceSTATIsPrunedSoReviewChoicesControlTheGrid() {
        let roles = ["Micro", "", "Title", "Poster"]
        let opszByRole: [String: Double] = ["Micro": 1.0, "": 19.73, "Title": 54.51, "Poster": 100.0]
        let weightLadder: [String: [Double]] = [
            "Extra Thin": [15.01, 10.36, 5.66, 1.00],
            "Thin": [20.26, 15.24, 10.18, 5.16],
            "Extra Light": [28.08, 23.02, 17.91, 12.80],
            "Light": [37.55, 32.73, 27.99, 23.24],
            "Regular": [48.12, 44.02, 39.91, 35.80],
            "Medium": [59.25, 55.92, 52.55, 49.18],
            "Bold": [69.95, 67.65, 65.38, 63.08],
            "Extra Bold": [80.80, 79.37, 77.94, 76.51],
            "Black": [90.45, 89.94, 89.43, 88.92],
            "Extra Black": [100.00, 100.00, 100.00, 100.00],
        ]
        var instances: [FontAnalysis.ExistingInstance] = []
        var allWght: Set<Double> = []
        for (weightName, values) in weightLadder {
            for (index, role) in roles.enumerated() {
                let wght = values[index]
                allWght.insert(wght)
                let name = role.isEmpty ? weightName : "\(role) \(weightName)"
                instances.append(instance(name, ["wght": wght, "opsz": opszByRole[role]!]))
            }
        }

        // Real Interchange STAT fragments: foreign wght ladder + opsz at non-fvar coords.
        let bogusWghtSTAT: [(Double, String)] = [
            (4, "Poster"), (13.2, "Poster"), (35, "Micro"), (89.8, "Regular"),
            (149.9, "Bold"), (220, "Black"),
        ]
        let bogusOpszSTAT: [(Double, String)] = [
            (6, "Micro"), (20, "Extra"), (46, "Title"), (80, "Poster"),
        ]

        var font = makeFont(axes: [
            AxisDefinition(
                tag: "wght", displayName: "Weight", min: 1, default: 34, max: 100, role: .instance,
                values: bogusWghtSTAT.map { AxisValue(id: "w-\($0.0)", value: $0.0, name: $0.1, elidable: false) }
            ),
            AxisDefinition(
                tag: "opsz", displayName: "Optical Size", min: 1, default: 1, max: 100, role: .instance,
                values: bogusOpszSTAT.map { AxisValue(id: "o-\($0.0)", value: $0.0, name: $0.1, elidable: false) }
            ),
        ])
        let analysis = makeAnalysis(
            axes: [
                analyzed(tag: "wght", displayName: "Weight", values: bogusWghtSTAT.map(\.0), observed: Array(allWght)),
                analyzed(tag: "opsz", displayName: "Optical Size", values: bogusOpszSTAT.map(\.0), observed: [1.0, 19.73, 54.51, 100.0]),
            ],
            instances: instances
        )

        let report = FvarStopSeeder.seed(into: &font, analysis: analysis)
        XCTAssertTrue(report.needsReview)

        // Foreign STAT gone — none of those coordinates survive on the axes.
        let wght = try! XCTUnwrap(font.axes.first { $0.tag == "wght" })
        let opsz = try! XCTUnwrap(font.axes.first { $0.tag == "opsz" })
        for (value, _) in bogusWghtSTAT {
            XCTAssertNil(wght.values.first { AxisCoordinate.valuesEqual($0.value, value) }, "wght \(value)")
        }
        for (value, _) in bogusOpszSTAT {
            XCTAssertNil(opsz.values.first { AxisCoordinate.valuesEqual($0.value, value) }, "opsz \(value)")
        }

        // Accept recommendations → clean ladder, not 40×STAT pollution.
        let decisions = FvarStopSeeder.ReviewDecisions(
            stopDispositions: Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
                ($0.id, $0.recommendedDisposition)
            }),
            acceptedCompoundIDs: Set(report.compoundSuggestions.map { $0.id })
        )
        _ = FvarStopSeeder.apply(reviewDecisions: decisions, report: report, to: &font)

        let wghtAfter = try! XCTUnwrap(font.axes.first { $0.tag == "wght" })
        let opszAfter = try! XCTUnwrap(font.axes.first { $0.tag == "opsz" })
        // One stop per promoted weight name; light end stays off Format 1.
        XCTAssertEqual(wghtAfter.values.count, 6, wghtAfter.values.map { "\($0.name)=\($0.value)" }.joined(separator: ", "))
        XCTAssertEqual(Set(wghtAfter.values.map { $0.name }), Set(["Regular", "Medium", "Bold", "Extra Bold", "Black", "Extra Black"]))
        XCTAssertEqual(opszAfter.values.count, 4, opszAfter.values.map { "\($0.name)=\($0.value)" }.joined(separator: ", "))

        let projected = FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: [],
            decisions: [:],
            acceptedCompoundCoords: font.compoundStatValues.map(\.coords)
        )
        XCTAssertEqual(projected, 40, "6×4 orthogonal + 16 Format 4")
        XCTAssertEqual(font.compoundStatValues.count, 16)
        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["opsz", "wght"], elidedFallback: "Regular")
        )
        XCTAssertEqual(plan.formula.totalGenerated, 40)
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
