import XCTest
@testable import VarFontCore

final class SaveReviewPresentationBuilderTests: XCTestCase {
    func testFvarAxesAreProtected() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let plan = makePlan()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: []
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let fvar = presentation.tabs.first { $0.id == .fvar }
        XCTAssertNotNil(fvar)
        let axisRows = fvar?.sections.first { $0.title.hasPrefix("Axes") }?.rows ?? []
        XCTAssertEqual(axisRows.count, 1)
        XCTAssertTrue(axisRows.allSatisfy { $0.category == .protected })
        XCTAssertEqual(axisRows.first?.afterValue, "400 / 400 / 700")
        XCTAssertEqual(fvar?.sections.first { $0.title.hasPrefix("Axes") }?.title, "Axes (source fvar order)")
    }

    func testFvarAxisRowNoteAppearsOnce() {
        let analysis = makeAnalysis()
        var font = makeFont()
        font.axes[0].default = 500
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: makePlan(),
            report: CommitDiffReport(statRows: [], instanceRows: [], nameIDRows: []),
            diff: nil,
            naming: makeNaming()
        )
        let axisRow = presentation.tabs.first { $0.id == .fvar }?
            .sections.first { $0.title.hasPrefix("Axes") }?.rows.first
        XCTAssertNotNil(axisRow?.noteLine)
        XCTAssertEqual(axisRow?.noteLine?.components(separatedBy: SaveReviewRowFormatter.fvarProtectedNote).count, 2)
        // Source scales remain in afterValue even when project default diverges.
        XCTAssertEqual(axisRow?.afterValue, "400 / 400 / 700")
    }

    func testNameReflowCategory() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let plan = makePlan()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: [
                CommitDiffNameIDRow(
                    id: 281,
                    beforeString: nil,
                    afterString: "Bold",
                    afterRole: "stat_axis_value",
                    change: .added,
                    reflowedFromNameID: 269
                ),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            report: report,
            diff: CommitDiff(
                nameRecordsSequenced: [
                    .init(id: 279, string: "Weight", role: "axis_display_name"),
                    .init(id: 281, string: "Bold", role: "stat_axis_value"),
                ],
                statValuesPlanned: [
                    .init(tag: "wght", value: 700, name: "Bold", elidable: false, statFormat: 1, nameID: 281),
                ]
            ),
            naming: makeNaming()
        )
        let nameTab = presentation.tabs.first { $0.id == .name }
        let reflowRow = nameTab?.sections.flatMap(\.rows).first { $0.id == "name:281" }
        XCTAssertEqual(reflowRow?.category, .reflow)
        XCTAssertEqual(reflowRow?.wasLine, "slot moved from nameID 269")
    }

    func testRemovedSlotsSection() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let plan = makePlan()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: [
                CommitDiffNameIDRow(id: 290, beforeString: "Stale", afterString: nil, change: .removed),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let nameTab = presentation.tabs.first { $0.id == .name }
        let removed = nameTab?.sections.first { $0.title == "Removed slots" }
        XCTAssertEqual(removed?.rows.count, 1)
        XCTAssertEqual(removed?.rows.first?.category, .removed)
    }

    func testCombinationsSectionShowsFormat4Rows() {
        var font = makeFont()
        font.compoundStatValues = [
            CompoundStatValue(
                id: "c1",
                coords: ["opsz": 36, "wght": 100],
                axisIndices: [0, 1],
                axisValues: [36, 100],
                name: "Poster Extrathin",
                elidable: false
            ),
        ]
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: [
                CommitDiffNameIDRow(
                    id: 270,
                    beforeString: "Poster Extrathin",
                    afterString: "Poster Extrathin",
                    afterRole: "stat_format4",
                    change: .unchanged
                ),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: font,
            plan: makePlan(),
            report: report,
            diff: CommitDiff(
                nameRecordsSequenced: [
                    .init(id: 270, string: "Poster Extrathin", role: "stat_format4"),
                ]
            ),
            naming: makeNaming()
        )
        let combinations = presentation.tabs.first { $0.id == .name }?
            .sections.first { $0.title == "Combinations" }
        XCTAssertEqual(combinations?.rows.count, 1)
        XCTAssertEqual(combinations?.rows.first?.fieldTitle, "Combination style")
        XCTAssertEqual(
            combinations?.rows.first?.fieldSubtitle,
            "Format 4 combination style · wght=100 opsz=36"
        )
        XCTAssertEqual(combinations?.rows.first?.afterValue, "\"Poster Extrathin\"")
        XCTAssertEqual(combinations?.rows.first?.category, .same)

        let statCombinations = presentation.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Combinations" }
        XCTAssertEqual(statCombinations?.rows.count, 1)
        XCTAssertEqual(statCombinations?.rows.first?.fieldTitle, "Poster Extrathin")
        XCTAssertEqual(statCombinations?.rows.first?.nameID, 270)
        XCTAssertEqual(
            statCombinations?.rows.first?.fieldSubtitle,
            "Format 4 combination style · wght=100 opsz=36"
        )
        XCTAssertEqual(statCombinations?.rows.first?.roleLabel, "stat_format4")
    }

    func testNameAxisDisplayRowsIncludeAxisTag() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: [
                CommitDiffNameIDRow(
                    id: 279,
                    beforeString: "Weight",
                    afterString: "Weight",
                    afterRole: "axis_display_name",
                    change: .unchanged
                ),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: makePlan(),
            report: report,
            diff: CommitDiff(
                nameRecordsSequenced: [
                    .init(id: 279, string: "Weight", role: "axis_display_name"),
                ]
            ),
            naming: makeNaming()
        )
        let axisRow = presentation.tabs.first { $0.id == .name }?
            .sections.first { $0.title == "Axis records" }?.rows.first
        XCTAssertEqual(axisRow?.fieldTitle, "Weight (wght) axis")
    }

    func testOtReflowLabelsAppearBeforeAxisRecords() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [],
            nameIDRows: [
                CommitDiffNameIDRow(
                    id: 256,
                    beforeString: "Alternate g",
                    afterString: "Alternate g",
                    afterRole: "ot_feature_label",
                    change: .added,
                    reflowedFromNameID: 763
                ),
                CommitDiffNameIDRow(
                    id: 279,
                    beforeString: "Weight",
                    afterString: "Weight",
                    afterRole: "axis_display_name",
                    change: .unchanged
                ),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: makePlan(),
            report: report,
            diff: CommitDiff(
                nameRecordsSequenced: [
                    .init(id: 256, string: "Alternate g", role: "ot_feature_label"),
                    .init(id: 279, string: "Weight", role: "axis_display_name"),
                ],
                otReflowMapping: [
                    .init(fromID: 763, toID: 256, string: "Alternate g", feature: "ss05"),
                ]
            ),
            naming: makeNaming()
        )
        let nameTab = presentation.tabs.first { $0.id == .name }
        let sectionTitles = nameTab?.sections.map(\.title) ?? []
        XCTAssertEqual(sectionTitles.first, "OpenType feature labels")
        XCTAssertTrue(sectionTitles.contains("Axis records"))
        let otRow = nameTab?.sections.first?.rows.first
        XCTAssertEqual(otRow?.fieldTitle, "ss05 · Alternate g")
        XCTAssertEqual(otRow?.category, .reflow)
    }

    func testDuplicateSourceStatValuesAtSameTagValueDoNotTrap() {
        // BlackPack-Variable ships two STAT records at wght:400 (format 2 + format 3).
        // Review must not trap on Dictionary(uniqueKeysWithValues:).
        var analysis = makeAnalysis()
        analysis.statValues = [
            .init(
                format: 2,
                tag: "wght",
                name: "Not for desktop use",
                elidable: true,
                nameID: 256,
                value: 400,
                rangeMin: 250,
                rangeMax: 550,
                nominal: 400
            ),
            .init(
                format: 3,
                tag: "wght",
                name: "Not for desktop use",
                elidable: true,
                nameID: 257,
                value: 400,
                linkedValue: 700
            ),
        ]
        let report = CommitDiffReport(
            statRows: [
                CommitDiffStatRow(
                    tag: "wght",
                    value: 400,
                    beforeName: "Not for desktop use",
                    afterName: "Regular",
                    beforeNameID: 256,
                    afterNameID: 256,
                    afterStatFormat: 2,
                    afterLinkedValue: nil,
                    change: .changed
                ),
            ],
            instanceRows: [],
            nameIDRows: []
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: makeFont(),
            plan: makePlan(),
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let weightSection = presentation.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Weight" || $0.title == "wght" }
        XCTAssertEqual(weightSection?.rows.count, 1)
        XCTAssertEqual(weightSection?.rows.first?.fieldTitle, "wght = 400")
        XCTAssertEqual(weightSection?.rows.first?.wasLine, "was \"Not for desktop use\"")
    }

    func testFractionalStatGhostPairsCollapseToOneRow() {
        var analysis = makeAnalysis()
        analysis.statValues = [
            .init(format: 1, tag: "wght", name: "Regular", elidable: false, nameID: 263, value: 35.79998779296875),
        ]
        let report = CommitDiffReport(
            statRows: [
                CommitDiffStatRow(
                    tag: "wght",
                    value: 35.79998779296875,
                    beforeName: "Regular",
                    afterName: nil,
                    beforeNameID: 263,
                    afterNameID: nil,
                    change: .removed
                ),
                CommitDiffStatRow(
                    tag: "wght",
                    value: 35.8,
                    beforeName: nil,
                    afterName: "Regular",
                    beforeNameID: nil,
                    afterNameID: 263,
                    change: .added
                ),
            ],
            instanceRows: [],
            nameIDRows: []
        )
        var font = makeFont()
        font.axes[0].values = [
            AxisValue(id: "w1", value: 35.8, name: "Regular", elidable: false),
        ]
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: makePlan(),
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let weightSection = presentation.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Weight" || $0.title == "wght" }
        XCTAssertEqual(weightSection?.rows.count, 1)
        XCTAssertEqual(weightSection?.rows.first?.category, .added)
        XCTAssertEqual(weightSection?.rows.first?.fieldTitle, "wght = 35.8")
    }

    func testFvarInstanceRowsIncludePostscriptName() {
        let analysis = makeAnalysis()
        let font = makeFont()
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [
                CommitDiffInstanceRow(
                    key: "i1",
                    beforeName: "Regular",
                    afterName: "Regular",
                    beforePostscriptName: "Playfair-Regular",
                    afterPostscriptName: "Playfair-Regular",
                    coords: ["wght": 400],
                    change: .unchanged,
                    postscriptChange: .unchanged
                ),
            ],
            nameIDRows: []
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: makePlan(),
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let fvar = presentation.tabs.first { $0.id == .fvar }
        let instanceSection = fvar?.sections.first { $0.title == "Instances" }
        XCTAssertEqual(instanceSection?.rows.count, 2)
        XCTAssertEqual(instanceSection?.rows[0].roleLabel, "subfamilyNameID")
        XCTAssertEqual(instanceSection?.rows[1].roleLabel, "postscriptNameID")
        XCTAssertEqual(instanceSection?.rows[1].afterValue, "\"Playfair-Regular\"")
    }

    func testDuplicateComposedNamesFlagImpactedRows() {
        let analysis = makeAnalysis()
        let font = makeFont()
        // Two included instances share "Regular" (duplicate); "Bold" is unique.
        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: .init(parts: [], totalGenerated: 3, totalIncluded: 3, totalExcluded: 0),
            instances: [
                PlannedInstance(key: "i1", composedName: "Regular", coords: ["wght": 400], included: true, duplicate: true, namingChain: []),
                PlannedInstance(key: "i2", composedName: "Regular", coords: ["wght": 401], included: true, duplicate: true, namingChain: []),
                PlannedInstance(key: "i3", composedName: "Bold", coords: ["wght": 700], included: true, duplicate: false, namingChain: []),
            ],
            warnings: [],
            namePlanSummary: nil
        )
        let report = CommitDiffReport(
            statRows: [],
            instanceRows: [
                CommitDiffInstanceRow(key: "i1", beforeName: "Regular", afterName: "Regular", coords: ["wght": 400], change: .unchanged),
                CommitDiffInstanceRow(key: "i3", beforeName: "Bold", afterName: "Bold", coords: ["wght": 700], change: .unchanged),
            ],
            nameIDRows: [
                CommitDiffNameIDRow(id: 300, beforeString: "Regular", afterString: "Regular", afterRole: "instance_subfamily", change: .unchanged),
                CommitDiffNameIDRow(id: 301, beforeString: "Bold", afterString: "Bold", afterRole: "instance_subfamily", change: .unchanged),
            ]
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            report: report,
            diff: nil,
            naming: makeNaming()
        )

        let fvarInstances = presentation.tabs.first { $0.id == .fvar }?
            .sections.first { $0.title == "Instances" }?.rows ?? []
        let fvarRegular = fvarInstances.first { $0.afterValue == "\"Regular\"" }
        let fvarBold = fvarInstances.first { $0.afterValue == "\"Bold\"" }
        XCTAssertNotNil(fvarRegular?.conflictHint, "Shared composed name should flag the fvar row")
        XCTAssertNil(fvarBold?.conflictHint, "Unique composed name must not be flagged")

        let nameInstances = presentation.tabs.first { $0.id == .name }?
            .sections.first { $0.title == "Instances" }?.rows ?? []
        XCTAssertTrue(
            nameInstances.contains { $0.afterValue == "\"Regular\"" && $0.conflictHint != nil },
            "Shared composed name should flag the name-tab subfamily row"
        )
        XCTAssertTrue(
            nameInstances.contains { $0.afterValue == "\"Bold\"" && $0.conflictHint == nil },
            "Unique composed name row stays unflagged"
        )
    }

    func testConflictingAxisStopsFlagStatRows() {
        let analysis = makeAnalysis()
        var font = makeFont()
        // Two "Regular" weight stops (the Axis Tree conflict) plus a clean "Medium".
        font.axes = [
            AxisDefinition(
                tag: "wght",
                displayName: "Weight",
                min: 100,
                default: 100,
                max: 900,
                role: .instance,
                values: [
                    AxisValue(id: "s100", value: 100, name: "Regular", elidable: true, statFormat: 1),
                    AxisValue(id: "s200", value: 200, name: "Regular", elidable: false, statFormat: 1),
                    AxisValue(id: "s350", value: 350, name: "Medium", elidable: false, statFormat: 1),
                ]
            ),
        ]
        let plan = InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: .init(parts: [], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
            instances: [],
            warnings: [
                PlanWarning(
                    code: "duplicate_stop_name",
                    axis: "wght",
                    name: "Regular",
                    stopIDs: ["s100", "s200"],
                    message: "Two Weight stops share the name \"Regular\"."
                ),
            ],
            namePlanSummary: nil
        )
        let report = CommitDiffReport(
            statRows: [
                CommitDiffStatRow(tag: "wght", value: 100, beforeName: "Regular", afterName: "Regular", beforeNameID: 273, afterNameID: 273, afterStatFormat: 1, afterLinkedValue: nil, change: .unchanged),
                CommitDiffStatRow(tag: "wght", value: 200, beforeName: nil, afterName: "Regular", beforeNameID: nil, afterNameID: 274, afterStatFormat: 1, afterLinkedValue: nil, change: .added),
                CommitDiffStatRow(tag: "wght", value: 350, beforeName: "Medium", afterName: "Medium", beforeNameID: 275, afterNameID: 275, afterStatFormat: 1, afterLinkedValue: nil, change: .unchanged),
            ],
            instanceRows: [],
            nameIDRows: []
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: analysis,
            font: font,
            plan: plan,
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let statRows = presentation.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Weight" || $0.title == "wght" }?.rows ?? []
        XCTAssertNotNil(statRows.first { $0.fieldTitle == "wght = 100" }?.conflictHint, "Conflicting stop should be flagged")
        XCTAssertNotNil(statRows.first { $0.fieldTitle == "wght = 200" }?.conflictHint, "Conflicting stop should be flagged")
        XCTAssertNil(statRows.first { $0.fieldTitle == "wght = 350" }?.conflictHint, "Non-conflicting stop stays clean")
    }

    func testStatStopShowsFormat2RangeAndElided() {
        var font = makeFont()
        font.axes[0].values = [
            AxisValue(
                id: "v1",
                value: 400,
                name: "Regular",
                elidable: true,
                statFormat: 2,
                rangeMin: 250,
                rangeMax: 550,
                code: "4"
            ),
        ]
        let report = CommitDiffReport(
            statRows: [
                CommitDiffStatRow(
                    tag: "wght",
                    value: 400,
                    beforeName: "Regular",
                    afterName: "Regular",
                    beforeNameID: 256,
                    afterNameID: 256,
                    afterStatFormat: 2,
                    afterLinkedValue: nil,
                    change: .unchanged
                ),
            ],
            instanceRows: [],
            nameIDRows: []
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: font,
            plan: makePlan(),
            report: report,
            diff: CommitDiff(
                statValuesPlanned: [
                    .init(
                        tag: "wght",
                        value: 400,
                        name: "Regular",
                        elidable: true,
                        statFormat: 2,
                        nameID: 256,
                        rangeMin: 250,
                        rangeMax: 550
                    ),
                ]
            ),
            naming: makeNaming()
        )
        let row = presentation.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Weight" || $0.title == "wght" }?.rows.first
        XCTAssertEqual(row?.afterValue, "\"Regular\" · 250–400–550")
        XCTAssertEqual(row?.fieldSubtitle, "Stop value · Format 2 range · Elided")
        XCTAssertFalse(row?.fieldSubtitle.contains("code") == true)
    }

    func testFvarTabLabelsNamingOrderAndPostScriptHyphen() {
        var font = makeFont()
        font.axes.insert(
            AxisDefinition(
                tag: "opsz",
                displayName: "Optical Size",
                min: 6,
                default: 12,
                max: 144,
                role: .instance,
                values: []
            ),
            at: 0
        )
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: font,
            plan: makePlan(),
            report: CommitDiffReport(statRows: [], instanceRows: [], nameIDRows: []),
            diff: nil,
            naming: NamingPolicy(order: ["opsz", "@pshyphen", "wght", "@code"])
        )
        let section = presentation.tabs.first { $0.id == .fvar }?
            .sections.first { $0.title == "Naming order" }
        XCTAssertEqual(section?.rows.count, 1)
        XCTAssertEqual(section?.rows.first?.afterValue, "opsz · [-] · wght · code")
        XCTAssertEqual(
            section?.rows.first?.fieldSubtitle,
            "Instance names · [-] is the PostScript hyphen split · code joins Axis Tree stop codes"
        )
        XCTAssertEqual(section?.rows.first?.category, .same)
    }

    func testFvarInstanceSubtitleShowsComposedCodeNotStat() {
        var font = makeFont()
        font.axes[0].values[0].code = "4"
        font.axes[0].values[1].code = "7"
        let report = CommitDiffReport(
            statRows: [
                CommitDiffStatRow(
                    tag: "wght",
                    value: 400,
                    beforeName: "Regular",
                    afterName: "Regular",
                    beforeNameID: 256,
                    afterNameID: 256,
                    afterStatFormat: 1,
                    change: .unchanged
                ),
            ],
            instanceRows: [
                CommitDiffInstanceRow(
                    key: "i1",
                    beforeName: "Regular",
                    afterName: "Regular",
                    coords: ["wght": 400],
                    change: .unchanged
                ),
            ],
            nameIDRows: []
        )
        let withCode = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: font,
            plan: makePlan(),
            report: report,
            diff: nil,
            naming: NamingPolicy(order: ["@pshyphen", "wght", "@code"])
        )
        let instanceRow = withCode.tabs.first { $0.id == .fvar }?
            .sections.first { $0.title == "Instances" }?.rows.first
        XCTAssertEqual(instanceRow?.fieldSubtitle, "wght=400 · code 4")

        let statRow = withCode.tabs.first { $0.id == .stat }?
            .sections.first { $0.title == "Weight" || $0.title == "wght" }?.rows.first
        XCTAssertEqual(statRow?.fieldSubtitle, "Stop value · Format 1 · Elided")
        XCTAssertFalse(statRow?.fieldSubtitle.contains("code") == true)

        let withoutToken = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: font,
            plan: makePlan(),
            report: report,
            diff: nil,
            naming: makeNaming()
        )
        let plainInstance = withoutToken.tabs.first { $0.id == .fvar }?
            .sections.first { $0.title == "Instances" }?.rows.first
        XCTAssertEqual(plainInstance?.fieldSubtitle, "wght=400")
    }

    func testTabAddedRemovedCountsMatchFilterCategories() {
        let presentation = SaveReviewPresentationBuilder.build(
            analysis: makeAnalysis(),
            font: makeFont(),
            plan: makePlan(),
            report: CommitDiffReport(
                statRows: [
                    CommitDiffStatRow(
                        tag: "wght",
                        value: 700,
                        beforeName: nil,
                        afterName: "Bold",
                        beforeNameID: nil,
                        afterNameID: 281,
                        afterStatFormat: 1,
                        change: .added
                    ),
                    CommitDiffStatRow(
                        tag: "wght",
                        value: 300,
                        beforeName: "Light",
                        afterName: nil,
                        beforeNameID: 280,
                        afterNameID: nil,
                        afterStatFormat: 1,
                        change: .removed
                    ),
                ],
                instanceRows: [],
                nameIDRows: [
                    CommitDiffNameIDRow(id: 290, beforeString: "Stale", afterString: nil, change: .removed),
                ]
            ),
            diff: nil,
            naming: makeNaming()
        )
        let stat = presentation.tabs.first { $0.id == .stat }
        XCTAssertEqual(stat?.addedRowCount, 1)
        XCTAssertEqual(stat?.removedRowCount, 1)
        let names = presentation.tabs.first { $0.id == .name }
        XCTAssertEqual(names?.removedRowCount, 1)
        XCTAssertEqual(names?.addedRowCount, 0)
    }

    // MARK: - Fixtures

    private func makeAnalysis() -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "Test", fullName: "Test", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [
                .init(
                    tag: "wght",
                    displayName: "Weight",
                    min: 400,
                    default: 400,
                    max: 700,
                    roleInferred: .instance,
                    variesInExistingInstances: true,
                    valuesExisting: []
                ),
            ],
            statValues: [],
            instancesExisting: [],
            instancesExistingMeta: .init(total: 0, sampleCount: 0),
            nameAudit: .init(freeStart: 256, used: [], elidedFallbackID: nil, elidedFallbackName: nil),
            inferred: .init(isItalicFont: false, gridAxisTags: ["wght"], namingOrderSuggested: ["wght"]),
            designAxisTags: ["wght"]
        )
    }

    private func makeFont() -> FontDocument {
        FontDocument(
            id: "f1",
            sourcePath: "/t.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: true,
            axes: [
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 400,
                    default: 400,
                    max: 700,
                    role: .instance,
                    values: [
                        AxisValue(id: "v1", value: 400, name: "Regular", elidable: true, statFormat: 1),
                        AxisValue(id: "v2", value: 700, name: "Bold", elidable: false, statFormat: 1),
                    ]
                ),
            ],
            options: CommitOptions(),
            includedInstanceKeys: [],
            excludedInstanceKeys: [],
            overrides: InstanceOverrides(),
            statDesignAxisTags: ["wght"]
        )
    }

    private func makeNaming() -> NamingPolicy {
        NamingPolicy(order: ["@pshyphen", "wght"])
    }

    private func makePlan() -> InstancePlan {
        InstancePlan(
            schemaVersion: 1,
            fontID: "f1",
            formula: .init(parts: [], totalGenerated: 0, totalIncluded: 0, totalExcluded: 0),
            instances: [],
            warnings: [],
            namePlanSummary: nil
        )
    }
}
