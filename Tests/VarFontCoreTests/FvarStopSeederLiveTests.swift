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
}
