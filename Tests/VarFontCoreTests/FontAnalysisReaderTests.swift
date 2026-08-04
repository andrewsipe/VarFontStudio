import XCTest
@testable import VarFontCore

final class FontAnalysisReaderTests: XCTestCase {
    private var robotoPath: String {
        NSHomeDirectory()
            + "/Downloads/RobotoFlex-VariableFont_GRAD,XOPQ,XTRA,YOPQ,YTAS,YTDE,YTFI,YTLC,YTUC,opsz,slnt,wdth,wght.ttf"
    }

    func testAnalyzeRobotoFlexWhenAvailable() throws {
        let path = robotoPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Roboto Flex fixture font not in ~/Downloads")
        }

        let analysis = try FontAnalysisReader.analyze(url: URL(fileURLWithPath: path))
        XCTAssertEqual(analysis.schemaVersion, 1)
        XCTAssertTrue(analysis.readiness.hasFvar)
        XCTAssertTrue(analysis.readiness.hasStat)
        XCTAssertEqual(analysis.instancesExistingMeta?.total, 20)
        XCTAssertEqual(analysis.inferred.gridAxisTags, ["slnt", "wght"])
        XCTAssertEqual(analysis.axes.count, 13)

        let fixture = try FixtureLoader.decode(FontAnalysis.self, from: "roboto-flex-analysis.json")
        XCTAssertEqual(analysis.inferred.gridAxisTags, fixture.inferred.gridAxisTags)
        XCTAssertEqual(analysis.instancesExistingMeta?.total, fixture.instancesExistingMeta?.total)
        XCTAssertEqual(analysis.axes.count, fixture.axes.count)
    }

    func testAnalyzePlayfairRomanWhenAvailable() throws {
        let path = NSHomeDirectory() + "/Downloads/PlayfairRomanVF.woff2"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Playfair Roman VF not in ~/Downloads")
        }

        let analysis = try FontAnalysisReader.analyze(url: URL(fileURLWithPath: path))
        XCTAssertEqual(analysis.instancesExistingMeta?.total, 252)
        XCTAssertTrue(analysis.inferred.gridAxisTags.contains("wght"))
        XCTAssertEqual(analysis.inferred.namingOrderSuggested.prefix(3), ["opsz", "wdth", "wght"])
        XCTAssertFalse(analysis.nameAudit.used.isEmpty)
        XCTAssertGreaterThan(analysis.nameAudit.freeStart, 256)
        XCTAssertTrue(analysis.readiness.writable)
    }

    func testAnalyzeForInstancerSkipsNameAuditWhenAvailable() throws {
        let path = robotoPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("Roboto Flex fixture font not in ~/Downloads")
        }

        let url = URL(fileURLWithPath: path)
        let full = try FontAnalysisReader.analyzeForCommitDiff(url: url)
        let light = try FontAnalysisReader.analyzeForInstancer(url: url)

        XCTAssertEqual(light.instancesExisting.count, full.instancesExisting.count)
        XCTAssertEqual(light.instancesExistingMeta?.total, full.instancesExistingMeta?.total)
        XCTAssertTrue(light.nameAudit.used.isEmpty)
        XCTAssertFalse(full.nameAudit.used.isEmpty)

        let built = InstancerSessionBuilder.build(from: light)
        XCTAssertFalse(built.rows.isEmpty)
        XCTAssertEqual(built.rows.count, light.instancesExisting.count)
    }
}
