import XCTest
@testable import VarFontStudio

@MainActor
final class ProjectWorkspaceStoreTests: XCTestCase {
    func testClearHelpersNilOutRequests() {
        let store = ProjectWorkspaceStore()
        store.confirmRemoveFont = FontRemovalRequest(projectID: "p1", fontID: "f1")
        store.confirmMoveFont = FontMoveRequest(fontID: "f1", fromProjectID: "p1", toProjectID: "p2")
        store.confirmCombineProjects = ProjectCombineRequest(sourceProjectID: "p1", targetProjectID: "p2")
        store.confirmSplitFont = FontSplitRequest(fontID: "f1", fromProjectID: "p1")
        store.confirmCloseProjectID = "p1"
        store.confirmQuitRequested = true
        store.confirmSetAsMasterFontID = "f1"
        store.confirmPushAxisTree = true
        store.projectTargetPickerMode = .combineInto(targetProjectID: "p2")
        store.pendingAddFontProjectID = "p1"

        store.clearRemoveFont()
        store.clearMoveFont()
        store.clearCombineProjects()
        store.clearSplitFont()
        store.clearCloseProject()
        store.clearQuit()
        store.clearSetAsMaster()
        store.clearPushAxisTree()
        store.clearTargetPicker()

        XCTAssertNil(store.confirmRemoveFont)
        XCTAssertNil(store.confirmMoveFont)
        XCTAssertNil(store.confirmCombineProjects)
        XCTAssertNil(store.confirmSplitFont)
        XCTAssertNil(store.confirmCloseProjectID)
        XCTAssertFalse(store.confirmQuitRequested)
        XCTAssertNil(store.confirmSetAsMasterFontID)
        XCTAssertFalse(store.confirmPushAxisTree)
        XCTAssertNil(store.projectTargetPickerMode)
        XCTAssertEqual(store.pendingAddFontProjectID, "p1")
    }
}
