import XCTest
import VarFontCore
@testable import VarFontStudio

@MainActor
final class SaveReviewStoreTests: XCTestCase {
    func testSessionKeyLoadingAndClearScoped() {
        let store = SaveReviewStore()
        XCTAssertEqual(store.sessionKey(projectID: "p1", fontID: "f1"), "p1|f1")

        store.beginLoading(projectID: "p1", fontID: "f1")
        store.beginLoading(projectID: "p1", fontID: "f2")
        store.beginLoading(projectID: "p2", fontID: "f9")
        XCTAssertTrue(store.isLoading(projectID: "p1", fontID: "f1"))
        XCTAssertTrue(store.isLoading(projectID: "p1"))
        XCTAssertTrue(store.isLoading(projectID: "p2"))

        store.endLoading(projectID: "p1", fontID: "f1")
        XCTAssertFalse(store.isLoading(projectID: "p1", fontID: "f1"))
        XCTAssertTrue(store.isLoading(projectID: "p1", fontID: "f2"))

        store.clear(projectID: "p1")
        XCTAssertFalse(store.isLoading(projectID: "p1"))
        XCTAssertTrue(store.isLoading(projectID: "p2", fontID: "f9"))
    }

    func testSelectFontResetsSearchWhenChanged() {
        let store = SaveReviewStore()
        store.selectFont(projectID: "p1", fontID: "f1")
        store.updateUIState(forProjectID: "p1") { $0.searchQuery = "Bold" }
        XCTAssertEqual(store.uiState(forProjectID: "p1").searchQuery, "Bold")

        store.selectFont(projectID: "p1", fontID: "f1")
        XCTAssertEqual(store.uiState(forProjectID: "p1").searchQuery, "Bold")

        store.selectFont(projectID: "p1", fontID: "f2")
        XCTAssertEqual(store.uiState(forProjectID: "p1").searchQuery, "")
        XCTAssertEqual(store.selectedFontID(projectID: "p1"), "f2")
    }

    func testEnsureSelectedFontDoesNotOverwrite() {
        let store = SaveReviewStore()
        store.ensureSelectedFont(projectID: "p1", fontID: "f1")
        store.ensureSelectedFont(projectID: "p1", fontID: "f2")
        XCTAssertEqual(store.selectedFontID(projectID: "p1"), "f1")
    }

    func testStoreSessionAndClearFontScoped() {
        let store = SaveReviewStore()
        let session = makeSession(projectID: "p1", fontID: "f1")
        store.storeSession(session, projectID: "p1", fontID: "f1")
        store.markExplicitlyOpened(projectID: "p1")
        store.requestOpen(projectID: "p1")

        XCTAssertNotNil(store.session(projectID: "p1", fontID: "f1"))
        XCTAssertTrue(store.wasExplicitlyOpened(projectID: "p1"))
        XCTAssertEqual(store.openRequest?.projectID, "p1")

        store.clear(projectID: "p1", fontID: "f1")
        XCTAssertNil(store.session(projectID: "p1", fontID: "f1"))
        // Project-level open bookkeeping is kept unless clearing the whole project.
        XCTAssertTrue(store.wasExplicitlyOpened(projectID: "p1"))
    }

    func testPersistentErrorAndSheetFlags() {
        let store = SaveReviewStore()
        store.setPersistentError("boom")
        XCTAssertEqual(store.persistentSaveError, "boom")
        store.presentSheet()
        XCTAssertTrue(store.presentCommitDiffSheet)
        store.dismissSheet()
        XCTAssertFalse(store.presentCommitDiffSheet)
        store.setPersistentError(nil)
        XCTAssertNil(store.persistentSaveError)
    }

    private func makeSession(projectID: String, fontID: String) -> CommitPreflightSession {
        let request = CommitRequest(
            schemaVersion: 1,
            requestID: "test",
            sourcePath: "/tmp/source.ttf",
            outputPath: "/tmp/out.ttf",
            dryRun: true,
            options: CommitOptions(),
            naming: NamingPolicy(order: ["wght"], elidedFallback: "Regular"),
            axes: []
        )
        let resultJSON = Data("""
        {
          "schema_version": 1,
          "request_id": "test",
          "ok": true,
          "dry_run": true,
          "warnings": [],
          "errors": []
        }
        """.utf8)
        let result = try! JSONDecoder().decode(CommitResult.self, from: resultJSON)
        return CommitPreflightSession(
            projectID: projectID,
            fontID: fontID,
            dryRunRequest: request,
            baseRequest: request,
            preflight: result,
            diffReport: CommitDiffBuilder.empty,
            presentation: .empty,
            informationalNotes: []
        )
    }
}
