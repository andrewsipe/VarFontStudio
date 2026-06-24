import XCTest
@testable import VarFontCore

final class LiveFontImportPlanTests: XCTestCase {
    func testPlayfairRomanLiveImportProducesInstances() throws {
        let path = NSHomeDirectory() + "/Downloads/PlayfairRomanVF.woff2"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Playfair not in Downloads")
        }
        let project = try ProjectImporter.openFont(at: URL(fileURLWithPath: path))
        let font = try XCTUnwrap(project.fonts.first)
        dumpAxisGrid(font)
        let plan = try XCTUnwrap(InstancePlanner.plan(project: project, fontID: font.id))
        XCTAssertGreaterThan(plan.formula.totalGenerated, 0, "Expected instance grid; empty instance axes: \(emptyInstanceAxes(font))")
        XCTAssertEqual(plan.formula.totalGenerated, 252)
        XCTAssertEqual(plan.formula.parts, [12, 3, 7])
    }

    func testRobotoFlexLiveImportProducesInstances() throws {
        let path = NSHomeDirectory()
            + "/Downloads/RobotoFlex-VariableFont_GRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght.ttf"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Roboto not in Downloads")
        }
        let project = try ProjectImporter.openFont(at: URL(fileURLWithPath: path))
        let font = try XCTUnwrap(project.fonts.first)
        dumpAxisGrid(font)
        let plan = try XCTUnwrap(InstancePlanner.plan(project: project, fontID: font.id))
        XCTAssertGreaterThan(plan.formula.totalGenerated, 0, "Expected instance grid; empty instance axes: \(emptyInstanceAxes(font))")
        XCTAssertEqual(plan.formula.parts, [9, 1])
        XCTAssertEqual(plan.formula.totalGenerated, 9)
    }

    private func dumpAxisGrid(_ font: FontDocument) {
        let grid = font.axes.filter { $0.role == .instance }
        print("grid axes:", grid.map { "\($0.tag)(\($0.values.count))" }.joined(separator: ", "))
    }

    private func emptyInstanceAxes(_ font: FontDocument) -> [String] {
        font.axes.filter { $0.role == .instance && $0.values.isEmpty }.map(\.tag)
    }
}
