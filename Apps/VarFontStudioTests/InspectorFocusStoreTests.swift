import XCTest
@testable import VarFontStudio

@MainActor
final class InspectorFocusStoreTests: XCTestCase {
    func testRevealProjectScopeBumpsTokenAndSetsFocus() {
        let store = InspectorFocusStore()
        XCTAssertEqual(store.revealToken, 0)
        XCTAssertNil(store.fileNamingFocus)

        store.revealProjectScope(fileNaming: .postScriptPrefix)
        XCTAssertEqual(store.panelScope, .project)
        XCTAssertEqual(store.fileNamingFocus, .postScriptPrefix)
        XCTAssertEqual(store.revealToken, 1)

        store.clearFileNamingFocus()
        XCTAssertNil(store.fileNamingFocus)
        XCTAssertEqual(store.revealToken, 1)
    }

    func testUpdateScopeForInstanceSelection() {
        let store = InspectorFocusStore()
        store.updateScopeForInstanceSelection(hasInspectableInstance: true)
        XCTAssertEqual(store.panelScope, .instance)
        store.updateScopeForInstanceSelection(hasInspectableInstance: false)
        XCTAssertEqual(store.panelScope, .project)
    }

    func testRequestAxisTreeFocus() {
        let store = InspectorFocusStore()
        store.requestAxisTreeFocus(axisTag: "wght", stopID: "stop-1")
        XCTAssertEqual(store.axisTreeFocusRequest?.axisTag, "wght")
        XCTAssertEqual(store.axisTreeFocusRequest?.stopID, "stop-1")
        XCTAssertNotNil(store.axisTreeFocusRequest?.token)
    }
}
