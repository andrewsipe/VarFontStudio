import CoreGraphics
import XCTest
@testable import VarFontCore

final class ImportedNameRepairTests: XCTestCase {
    func testOneHyphenFilenameBecomesTheFamily() {
        XCTAssertEqual(
            FilenameFamily.singleHyphenStub(filenameOrPath: "/fonts/TelderMono-Variable.ttf"),
            "TelderMono"
        )
        XCTAssertEqual(
            FilenameFamily.singleHyphenStub(filenameOrPath: "/fonts/TelderMono-VariableItalic.woff2"),
            "TelderMono"
        )
        XCTAssertNil(FilenameFamily.singleHyphenStub(filenameOrPath: "/fonts/TelderMono.ttf"))
        XCTAssertNil(FilenameFamily.singleHyphenStub(filenameOrPath: "/fonts/Telder-Mono-Variable.ttf"))
        XCTAssertEqual(
            FilenameFamily.preferred(filenameOrPath: "/fonts/TelderMono-Variable.ttf", recordedFamily: "HT"),
            "TelderMono"
        )
        XCTAssertEqual(
            FilenameFamily.preferred(filenameOrPath: "/fonts/TelderMono.ttf", recordedFamily: "HT"),
            "HT"
        )

        let naming = FilenameFamily.importNaming(
            analysis: analysis(
                statNameID: 256,
                resolved: [:],
                windows: [
                    WindowsNameRecord(nameID: 1, string: "HT"),
                    WindowsNameRecord(nameID: 16, string: "HT"),
                    WindowsNameRecord(nameID: 25, string: "HT"),
                ]
            ),
            sourceURL: URL(fileURLWithPath: "/fonts/TelderMono-Variable.ttf")
        )
        XCTAssertEqual(naming.overrides["1"], "TelderMono")
        XCTAssertEqual(naming.overrides["16"], "TelderMono")
        XCTAssertEqual(naming.familyPSPrefix, "TelderMono")
    }

    func testItalicAngleInsideTwoDegreesStaysUpright() {
        XCTAssertTrue(ItalicAngle.isUpright(0))
        XCTAssertTrue(ItalicAngle.isUpright(1.9))
        XCTAssertTrue(ItalicAngle.isUpright(-1.9))
        XCTAssertFalse(ItalicAngle.indicatesItalic(0))
        XCTAssertTrue(ItalicAngle.indicatesItalic(2))
        XCTAssertTrue(ItalicAngle.indicatesItalic(-8))
    }

    func testEmptyItalStopLinksToItsCounterpart() {
        let roman = ItalicStopNaming.assumedStyleLink(recorded: "", value: 0, format: 3, linkedValue: 1)
        XCTAssertEqual(roman.format, 3)
        XCTAssertEqual(roman.linkedValue, 1)

        let italic = ItalicStopNaming.assumedStyleLink(recorded: ".", value: 1, format: 1, linkedValue: nil)
        XCTAssertEqual(italic.format, 3)
        XCTAssertEqual(italic.linkedValue, 0)

        let kept = ItalicStopNaming.assumedStyleLink(recorded: "Italic", value: 1, format: 1, linkedValue: nil)
        XCTAssertEqual(kept.format, 1)
        XCTAssertNil(kept.linkedValue)
    }

    func testEmptyItalStopTakesRomanOrItalic() {
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: "", value: 0, fileIsItalic: false, stopCount: 1),
            "Roman"
        )
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: ".", value: 0, fileIsItalic: true, stopCount: 1),
            "Italic"
        )
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: "", value: 1, fileIsItalic: false, stopCount: 1),
            "Italic"
        )
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: "Roman", value: 0, fileIsItalic: true, stopCount: 1),
            "Roman"
        )
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: "", value: 0, fileIsItalic: true, stopCount: 2),
            "Roman"
        )
        XCTAssertEqual(
            ItalicStopNaming.importedName(recorded: "", value: 1, fileIsItalic: false, stopCount: 2),
            "Italic"
        )
    }

    func testRightLeaningStemCountsAsItalic() {
        let upright = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 0, y: 100), CGPoint(x: 10, y: 100),
        ]
        let leaning = [
            CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
            CGPoint(x: 30, y: 100), CGPoint(x: 40, y: 100),
        ]
        XCTAssertLessThan(abs(GlyphSlantProbe.slantDegrees(points: upright) ?? 99), GlyphSlantProbe.minimumDegrees)
        XCTAssertGreaterThanOrEqual(
            GlyphSlantProbe.slantDegrees(points: leaning) ?? 0,
            GlyphSlantProbe.minimumDegrees
        )
    }

    func testPeriodIsEmptyAndHTStays() {
        XCTAssertTrue(NameFiller.isFiller("."))
        XCTAssertTrue(NameFiller.isFiller("  .  "))
        XCTAssertTrue(NameFiller.isFiller(""))
        XCTAssertNil(NameFiller.meaningful("."))
        XCTAssertEqual(NameFiller.meaningful("HT"), "HT")
        XCTAssertEqual(NameFiller.meaningful("XLight"), "XLight")
    }

    func testRegisteredAxisNameFillsABlankAndKeepsARealName() {
        XCTAssertEqual(RegisteredAxisNames.displayName(tag: "wght", recorded: nil), "Weight")
        XCTAssertEqual(RegisteredAxisNames.displayName(tag: "wght", recorded: "."), "Weight")
        XCTAssertEqual(RegisteredAxisNames.displayName(tag: "ital", recorded: ""), "Italic")
        XCTAssertEqual(RegisteredAxisNames.displayName(tag: "wght", recorded: "Weight"), "Weight")
        XCTAssertEqual(RegisteredAxisNames.displayName(tag: "wght", recorded: "Poids"), "Poids")
    }

    func testImportKeepsFoundryNamesAndNamesOnlyRegisteredEmptyStops() {
        XCTAssertEqual(WeightStopNaming.importedName(recorded: "XLight", value: 200, tag: "wght"), "XLight")
        XCTAssertEqual(WeightStopNaming.importedName(recorded: "SemiBold", value: 600, tag: "wght"), "SemiBold")
        XCTAssertEqual(WeightStopNaming.importedName(recorded: ".", value: 400, tag: "wght"), "Regular")
        XCTAssertEqual(WeightStopNaming.importedName(recorded: "", value: 900, tag: "wght"), "Black")
        XCTAssertEqual(WeightStopNaming.importedName(recorded: ".", value: 250, tag: "wght"), "")
        XCTAssertEqual(WeightStopNaming.importedName(recorded: ".", value: 275, tag: "wght"), "")
        XCTAssertEqual(WeightStopNaming.canonicalSpelling(for: "XLight"), "Extralight")
        XCTAssertEqual(WeightStopNaming.canonicalSpelling(for: "SemiBold"), "Semibold")
        XCTAssertEqual(WeightStopNaming.canonicalSpelling(for: "XBold"), "Extrabold")
        XCTAssertNil(WeightStopNaming.canonicalSpelling(for: "Semibold"))
        XCTAssertNil(WeightStopNaming.canonicalSpelling(for: "Extralight"))
    }

    func testMissingWeightIsOfferedOnlyBetweenExistingStops() {
        let mono = AxisDefinition(
            tag: "wght",
            displayName: "Weight",
            min: 400,
            default: 400,
            max: 700,
            role: .instance,
            values: [
                AxisValue(id: "r", value: 400, name: "Regular", elidable: true),
                AxisValue(id: "s", value: 600, name: "Semibold", elidable: false),
                AxisValue(id: "b", value: 700, name: "Bold", elidable: false),
            ]
        )
        XCTAssertEqual(WeightStopNaming.missingScaleStops(on: mono).map(\.name), ["Medium"])

        let cira = AxisDefinition(
            tag: "wght",
            displayName: "Weight",
            min: 250,
            default: 400,
            max: 900,
            role: .instance,
            values: [250, 275, 300, 400, 500, 600, 700, 800, 900].map { value in
                AxisValue(id: "w\(Int(value))", value: value, name: "", elidable: value == 400)
            }
        )
        XCTAssertTrue(WeightStopNaming.missingScaleStops(on: cira).isEmpty)
    }

    func testEmptyWeightStopTakesTheSiblingName() {
        var fonts = [
            font(id: "roman", stops: [(250, "Thin", false), (400, "Regular", true)]),
            font(id: "italic", stops: [(250, ".", false), (400, "", true)]),
        ]
        SiblingStopNames.shareEmptyWeightNames(in: &fonts)
        let italic = fonts[1].axes[0].values
        XCTAssertEqual(italic[0].name, "Thin")
        XCTAssertEqual(italic[1].name, "Regular")
        XCTAssertTrue(italic[1].elidable)
        XCTAssertEqual(fonts[0].axes[0].values[0].name, "Thin")
    }

    func testFillerFamilyTakesARecordedSiblingAndHTStays() {
        var project = project(family: "Telder VF", fonts: [
            font(id: "roman", path: "/fonts/Telder-Variable.ttf", stops: [(400, "Regular", true)]),
            font(id: "italic", path: "/fonts/Telder-VariableItalic.ttf", stops: [(400, "", true)]),
        ])
        SiblingStopNames.shareFamilyName(in: &project, incomingFamily: ".", incomingFontID: "italic")
        XCTAssertEqual(project.familyLabel, "Telder VF")
        XCTAssertEqual(project.fonts[1].windowsNameOverrides["1"], "Telder VF")
        XCTAssertEqual(project.fonts[1].windowsNameOverrides["16"], "Telder VF")
        XCTAssertNil(project.fonts[0].windowsNameOverrides["1"])

        var ht = project
        ht.familyLabel = "HT"
        ht.fonts[1].windowsNameOverrides = [:]
        SiblingStopNames.shareFamilyName(in: &ht, incomingFamily: "HT", incomingFontID: "italic")
        XCTAssertEqual(ht.familyLabel, "HT")
        XCTAssertNil(ht.fonts[1].windowsNameOverrides["1"])
        XCTAssertNil(ht.fonts[0].windowsNameOverrides["1"])
    }

    func testRecordedFamilyReplacesAFilenameLabelOnEmptySiblings() {
        var project = project(family: "CiraSans-Variable", fonts: [
            font(id: "empty", path: "/fonts/CiraSans-Variable.ttf", stops: [(400, "Regular", true)]),
            font(id: "named", path: "/fonts/CiraSans-Italic.ttf", stops: [(400, "Regular", true)]),
        ])
        SiblingStopNames.shareFamilyName(in: &project, incomingFamily: "Cira Sans", incomingFontID: "named")
        XCTAssertEqual(project.familyLabel, "Cira Sans")
        XCTAssertEqual(project.fonts[0].windowsNameOverrides["1"], "Cira Sans")
        XCTAssertNil(project.fonts[1].windowsNameOverrides["1"])
    }

    func testAddingADanglingFontDoesNotReflowTheOthers() {
        var project = project(family: "Telder VF", fonts: [
            font(id: "done", path: "/fonts/Telder.ttf", stops: [(400, "Regular", true)]),
            font(id: "open", path: "/fonts/Cira.ttf", stops: [(400, "Regular", true)]),
        ])
        project.nameidStrategy = .preserve
        project.fonts[0].options.nameidStrategy = .preserve
        project.fonts[1].options.nameidStrategy = .preserve
        NameIDStrategyInference.applyDanglingReflow(
            to: &project,
            analysis: analysis(statNameID: 256, resolved: [:]),
            fontID: "open"
        )
        XCTAssertEqual(project.nameidStrategy, .preserve)
        XCTAssertEqual(project.fonts[0].options.nameidStrategy, .preserve)
        XCTAssertEqual(project.fonts[1].options.nameidStrategy, .reflow)
    }

    func testDanglingNameIDsPreferReflowAndResolvedNamesDoNot() {
        XCTAssertTrue(NameIDStrategyInference.prefersReflow(analysis: analysis(
            statNameID: 256,
            resolved: [:]
        )))
        XCTAssertFalse(NameIDStrategyInference.prefersReflow(analysis: analysis(
            statNameID: 256,
            resolved: [256: "Thin"]
        )))
    }

    func testFillerStyleBecomesItalicAndFamilyHTIsNotReplaced() {
        let italic = analysis(
            statNameID: 256,
            resolved: [:],
            windows: [
                WindowsNameRecord(nameID: 1, string: "HT"),
                WindowsNameRecord(nameID: 2, string: "."),
            ],
            fsSelection: 1
        )
        let overrides = NamePolicies.fillerStyleOverrides(for: italic)
        XCTAssertEqual(overrides["2"], "Italic")
        XCTAssertEqual(overrides["17"], "Italic")
        XCTAssertNil(overrides["1"])

        let roman = analysis(
            statNameID: 256,
            resolved: [:],
            windows: [
                WindowsNameRecord(nameID: 1, string: "HT"),
                WindowsNameRecord(nameID: 2, string: "."),
            ],
            fsSelection: 64
        )
        let romanOverrides = NamePolicies.fillerStyleOverrides(for: roman)
        XCTAssertEqual(romanOverrides["2"], "Regular")
        XCTAssertEqual(romanOverrides["17"], "Regular")
        XCTAssertNil(romanOverrides["1"])
    }

    private func project(family: String, fonts: [FontDocument]) -> ProjectDocument {
        ProjectDocument(
            schemaVersion: 1,
            familyLabel: family,
            naming: NamingPolicy(order: ["wght"]),
            template: ProjectTemplate(),
            fonts: fonts
        )
    }

    private func font(id: String, path: String? = nil, stops: [(Double, String, Bool)]) -> FontDocument {
        FontDocument(
            id: id,
            sourcePath: path ?? "/\(id).ttf",
            axes: [
                AxisDefinition(
                    tag: "wght",
                    displayName: "Weight",
                    min: 100,
                    default: 400,
                    max: 900,
                    role: .instance,
                    values: stops.map { value, name, elidable in
                        AxisValue(id: "\(id)-\(Int(value))", value: value, name: name, elidable: elidable)
                    }
                ),
            ]
        )
    }

    private func analysis(
        statNameID: Int,
        resolved: [Int: String],
        windows: [WindowsNameRecord] = [],
        fsSelection: UInt16 = 0
    ) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/t.ttf", format: "ttf", familyName: "HT", fullName: "", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [
                .init(
                    format: 3,
                    tag: "wght",
                    name: resolved[statNameID] ?? "",
                    elidable: true,
                    olderSibling: false,
                    nameID: statNameID,
                    value: 400
                ),
            ],
            instancesExisting: [],
            instancesExistingMeta: .init(total: 0, sampleCount: 0),
            nameAudit: .init(
                freeStart: 256,
                used: resolved.map { id, string in
                    FontAnalysis.NameAudit.NameIDUse(id: id, description: "STAT", string: string)
                },
                elidedFallbackID: nil,
                elidedFallbackName: nil
            ),
            windowsNameTable: windows,
            inferred: .init(
                isItalicFont: fsSelection & 1 != 0,
                gridAxisTags: ["wght"],
                namingOrderSuggested: ["wght"],
                fsSelection: fsSelection
            ),
            designAxisTags: ["wght"]
        )
    }
}
