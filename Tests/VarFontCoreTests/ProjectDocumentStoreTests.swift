import XCTest
@testable import VarFontCore

final class ProjectDocumentStoreTests: XCTestCase {
    func testRoundTripPlayfairFixture() throws {
        let project = try FixtureLoader.decode(ProjectDocument.self, from: "playfair-family-project.json")
        let data = try ProjectDocumentStore.encode(project)
        let roundTrip = try VarFontJSON.decode(ProjectDocument.self, from: data)
        XCTAssertEqual(roundTrip.familyLabel, project.familyLabel)
        XCTAssertEqual(roundTrip.fonts.map(\.id), project.fonts.map(\.id))
        XCTAssertEqual(roundTrip.naming.order, project.naming.order)
    }

    func testRejectUnsupportedSchemaVersion() throws {
        var data = try FixtureLoader.data("playfair-family-project.json")
        let original = String(data: data, encoding: .utf8)!
        let mutated = original.replacingOccurrences(of: "\"schema_version\": 1", with: "\"schema_version\": 99")
        data = Data(mutated.utf8)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unsupported-\(UUID().uuidString).varf")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertThrowsError(try ProjectDocumentStore.load(from: tempURL)) { error in
            XCTAssertEqual(error as? ProjectDocumentStoreError, .unsupportedSchemaVersion(99))
        }
    }

    func testRelativePathRoundTrip() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("varfont-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let fontURL = base.appendingPathComponent("fonts/TestVF.woff2")
        try FileManager.default.createDirectory(at: fontURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: fontURL.path, contents: Data())

        var project = try FixtureLoader.decode(ProjectDocument.self, from: "playfair-family-project.json")
        project.fonts[0].sourcePath = fontURL.path

        let projectURL = base.appendingPathComponent("project.varf")
        try ProjectDocumentStore.save(project, to: projectURL)

        let savedRaw = try VarFontJSON.decode(ProjectDocument.self, from: Data(contentsOf: projectURL))
        XCTAssertEqual(savedRaw.fonts[0].sourcePath, "fonts/TestVF.woff2")

        let loaded = try ProjectDocumentStore.load(from: projectURL)
        XCTAssertEqual(loaded.fonts[0].sourcePath, fontURL.standardizedFileURL.path)
    }

    func testAtomicSaveDoesNotLeavePartialFileOnFailure() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("varfont-atomic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let blockerURL = base.appendingPathComponent("blocker")
        FileManager.default.createFile(atPath: blockerURL.path, contents: Data())
        let projectURL = blockerURL.appendingPathComponent("project.varf")

        let project = try FixtureLoader.decode(ProjectDocument.self, from: "playfair-family-project.json")
        XCTAssertThrowsError(try ProjectDocumentStore.save(project, to: projectURL))

        let contents = try FileManager.default.contentsOfDirectory(atPath: base.path)
        XCTAssertFalse(contents.contains { $0.hasSuffix(".tmp") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectURL.path))
    }

    func testLegacyVarfontExtensionStillRecognized() throws {
        let url = URL(fileURLWithPath: "/tmp/Playfair.varfont")
        XCTAssertTrue(ProjectFileFormat.isProjectFileURL(url))
        XCTAssertEqual(
            ProjectFileFormat.normalizedProjectFileURL(url).pathExtension,
            "varfont"
        )
    }

    func testUnqualifiedURLGetsVarfExtension() {
        let url = URL(fileURLWithPath: "/tmp/Playfair")
        XCTAssertEqual(
            ProjectFileFormat.normalizedProjectFileURL(url).pathExtension,
            "varf"
        )
    }
}
