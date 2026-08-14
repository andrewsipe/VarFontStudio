import XCTest
@testable import VarFontCore

final class FvarStopSeederLiveTests: XCTestCase {
    private var easeURL: URL? {
        let path = "/Users/skymacbook/Downloads/_Fonts/TTF/Variable/Studiofeixen/converted/Ease-Variable.ttf"
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: path) ? url : nil
    }

    func testEaseImportSeedsCustomAxisStops() throws {
        guard let url = easeURL else {
            throw XCTSkip("Ease-Variable.ttf not present on this machine")
        }

        let (project, report) = try ProjectImporter.openFont(at: url)
        let font = try XCTUnwrap(project.fonts.first)

        let ousd = try XCTUnwrap(font.axes.first { $0.tag == "ousd" })
        let insd = try XCTUnwrap(font.axes.first { $0.tag == "insd" })
        let wght = try XCTUnwrap(font.axes.first { $0.tag == "wght" })

        XCTAssertEqual(Set(ousd.values.map(\.value)), Set([0, 20, 100]))
        XCTAssertEqual(Set(insd.values.map(\.value)), Set([0, 50, 70, 100]))
        XCTAssertEqual(wght.values.count, 5)
        XCTAssertGreaterThan(report.seededStopCount, 0)
        // Weight names already match fvar residues — no sheet-worthy conflicts.
        XCTAssertTrue(report.conflicts.isEmpty)

        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 20) }?.name, "SemiRounded")
        XCTAssertEqual(ousd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Rounded")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 50) }?.name, "SemiDisplay")
        XCTAssertEqual(insd.values.first { AxisCoordinate.valuesEqual($0.value, 100) }?.name, "Display")

        let byName = Dictionary(uniqueKeysWithValues: report.compoundSuggestions.map { ($0.name.lowercased(), $0) })
        XCTAssertNotNil(byName["doublerounded"])
        XCTAssertNotNil(byName["fullrounded"])
        XCTAssertEqual(byName["doublerounded"]?.coords["ousd"], 100)
        XCTAssertEqual(byName["doublerounded"]?.coords["insd"], 70)
        XCTAssertEqual(byName["fullrounded"]?.coords["ousd"], 100)
        XCTAssertEqual(byName["fullrounded"]?.coords["insd"], 100)
        XCTAssertNil(byName["doublerounded"]?.coords["wght"])
        XCTAssertNil(byName["fullrounded"]?.coords["wght"])
    }

    /// Import Review's headline number is `projectedStyleCount` over the post-seed font.
    /// It has to agree with the report's own projection, or the sheet lies about the outcome.
    func testProjectedStyleCountMatchesReportedOrthogonality() throws {
        guard let url = easeURL else {
            throw XCTSkip("Ease-Variable.ttf not present on this machine")
        }

        let (project, report) = try ProjectImporter.openFont(at: url)
        let font = try XCTUnwrap(project.fonts.first)
        let metrics = try XCTUnwrap(report.orthogonality)

        let onRecommendations = FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: report.heldStopCandidates,
            decisions: [:] as [String: FvarStopSeeder.StopDisposition]
        )
        XCTAssertEqual(onRecommendations, metrics.projectedAnalyticCount)

        let allPromoted = FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: report.heldStopCandidates,
            decisions: report.heldStopCandidates.reduce(into: [:]) { $0[$1.id] = .stop }
        )
        XCTAssertEqual(allPromoted, metrics.projectedIfAllPromoted)
    }

    func testInterchangeImportPrunesWrongSpaceSTATAndProjectsCleanGrid() throws {
        let path = "/Users/skymacbook/Downloads/_Fonts/WOFF2/New Folder With Items/Motaitalic/converted/Interchange-Variable.ttf"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Interchange-Variable.ttf not present on this machine")
        }
        let url = URL(fileURLWithPath: path)
        let (project, report) = try ProjectImporter.openFont(at: url)
        var font = try XCTUnwrap(project.fonts.first)

        XCTAssertTrue(report.needsReview)
        // Broken STAT (Poster@4, Black@220, opsz@6/20/46/80, …) must not survive seed.
        let wght = try XCTUnwrap(font.axes.first { $0.tag == "wght" })
        let opsz = try XCTUnwrap(font.axes.first { $0.tag == "opsz" })
        XCTAssertNil(wght.values.first { AxisCoordinate.valuesEqual($0.value, 220) })
        XCTAssertNil(wght.values.first { AxisCoordinate.valuesEqual($0.value, 4) })
        XCTAssertNil(opsz.values.first { AxisCoordinate.valuesEqual($0.value, 6) })
        XCTAssertNil(opsz.values.first { AxisCoordinate.valuesEqual($0.value, 80) })

        let onRecommendations = FvarStopSeeder.projectedStyleCount(
            font: font,
            heldCandidates: report.heldStopCandidates,
            decisions: Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
                ($0.id, $0.recommendedDisposition)
            }),
            acceptedCompoundCoords: report.compoundSuggestions.map(\.coords)
        )
        // 6 promoted weights × 4 optical sizes + 16 off-grid Format 4 light styles.
        XCTAssertEqual(onRecommendations, 40)

        _ = FvarStopSeeder.apply(
            reviewDecisions: .init(
                stopDispositions: Dictionary(uniqueKeysWithValues: report.heldStopCandidates.map {
                    ($0.id, $0.recommendedDisposition)
                }),
                acceptedCompoundIDs: Set(report.compoundSuggestions.map(\.id))
            ),
            report: report,
            to: &font
        )
        XCTAssertEqual(font.axes.first { $0.tag == "wght" }?.values.count, 6)
        XCTAssertEqual(font.axes.first { $0.tag == "opsz" }?.values.count, 4)
        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["opsz", "wght"], elidedFallback: "Regular")
        )
        XCTAssertEqual(plan.formula.totalGenerated, 40)
        XCTAssertEqual(font.compoundStatValues.count, 16)
    }

    func testPatchedInterchangeReimportKeepsFormat4WithoutComboReview() throws {
        let path = "/Users/skymacbook/Downloads/_Fonts/WOFF2/New Folder With Items/Motaitalic/converted/Interchange-Variable-patched.ttf"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Interchange-Variable-patched.ttf not present on this machine")
        }
        let (project, report) = try ProjectImporter.openFont(at: URL(fileURLWithPath: path))
        let font = try XCTUnwrap(project.fonts.first)

        XCTAssertEqual(font.compoundStatValues.count, 16)
        XCTAssertFalse(font.compoundStatValues.contains { $0.coords.keys.contains("?") })
        XCTAssertFalse(
            report.heldStopCandidates.contains { $0.classification == .comboOnly },
            "STAT Format 4 already encodes combo-only lights — Import Review should not re-ask"
        )
        XCTAssertTrue(
            report.compoundSuggestions.isEmpty,
            "Existing Format 4 compounds should not be re-suggested"
        )
        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["opsz", "wght", "ital"], elidedFallback: "Regular")
        )
        XCTAssertFalse(plan.warnings.contains { $0.code == "compound_axis_missing" })
        XCTAssertEqual(plan.formula.totalGenerated, 40)
    }
}
