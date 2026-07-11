import XCTest
@testable import VarFontCore

final class CommitWorkerTests: XCTestCase {
    func testWorkerFallsBackToOneShotWhenScriptMissing() async throws {
        let missingHelper = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-vfcommit-\(UUID().uuidString)/vfcommit.py")
        let service = CommitService(helperURL: missingHelper)
        let request = try FixtureLoader.decode(CommitRequest.self, from: "playfair-roman-commit-request.json")

        do {
            _ = try await service.commit(request, preferWorker: true)
            XCTFail("Expected helper failure")
        } catch {
            XCTAssertTrue(error is CommitServiceError)
        }
    }
}
