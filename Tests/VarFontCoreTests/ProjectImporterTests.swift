import XCTest
@testable import VarFontCore

final class ProjectImporterTests: XCTestCase {
    func testImportPlayfairFamilyFixtureShape() throws {
        let analysis = try FixtureLoader.decode(FontAnalysis.self, from: "playfair-roman-analysis.json")
        let project = ProjectImporter.newProject(
            from: analysis,
            sourceURL: URL(fileURLWithPath: analysis.source.path)
        )

        XCTAssertEqual(project.schemaVersion, 1)
        XCTAssertEqual(project.fonts.count, 1)
        XCTAssertFalse(project.fonts[0].axes.isEmpty)
        XCTAssertTrue(project.naming.order.contains("wght"))

        let plan = InstancePlanner.plan(project: project, fontID: project.fonts[0].id)
        XCTAssertNotNil(plan)
        XCTAssertGreaterThan(plan?.formula.totalGenerated ?? 0, 0)
    }
}
