import XCTest
import VarFontCore
@testable import VarFontStudio

@MainActor
final class IssueResolverStoreTests: XCTestCase {
    func testPresentAndDismissConflictClearsOptionalReviewSession() {
        let store = IssueResolverStore()
        let bundle = AxisConflictBundle(
            axisTag: "wght",
            axisLabel: "Weight",
            kind: .duplicateName,
            groups: [
                AxisConflictGroup(id: "g1", duplicateName: "Bold", stopIDs: ["a", "b"]),
            ],
            involvedStopIDs: ["a", "b"]
        )

        store.startReviewSession(state: AxisTreeReviewSessionState(scope: .full, initialTotal: 2))
        store.presentConflict(bundle: bundle, reviewPosition: 1, reviewTotal: 2)

        XCTAssertNotNil(store.conflictResolverRequest)
        XCTAssertEqual(store.conflictResolverRequest?.bundle.axisTag, "wght")
        XCTAssertEqual(store.conflictResolverRequest?.reviewPosition, 1)
        XCTAssertTrue(store.hasActiveReviewSession)

        store.dismissConflictResolver(clearReviewSession: true)
        XCTAssertNil(store.conflictResolverRequest)
        XCTAssertFalse(store.hasActiveReviewSession)
    }

    func testPresentPlanIssueAndClearBoth() {
        let store = IssueResolverStore()
        let warning = PlanWarning(code: "empty_axis", axis: "wght", message: "No stops")
        store.startReviewSession(state: AxisTreeReviewSessionState(scope: .axis("wght"), initialTotal: 1))
        store.presentPlanIssue(warning: warning, reviewPosition: 1, reviewTotal: 1)
        store.presentConflict(
            bundle: AxisConflictBundle(
                axisTag: "wght",
                axisLabel: "Weight",
                kind: .duplicateValue,
                groups: [],
                involvedStopIDs: []
            ),
            reviewPosition: nil,
            reviewTotal: nil
        )

        XCTAssertNotNil(store.planIssueResolverRequest)
        XCTAssertNotNil(store.conflictResolverRequest)

        store.clearBothResolversAndReviewSession()
        XCTAssertNil(store.planIssueResolverRequest)
        XCTAssertNil(store.conflictResolverRequest)
        XCTAssertFalse(store.hasActiveReviewSession)
    }

    func testReviewSessionPositionTracksCompletedCount() {
        let store = IssueResolverStore()
        store.startReviewSession(state: AxisTreeReviewSessionState(scope: .full, initialTotal: 3))
        XCTAssertEqual(store.reviewSessionPosition()?.current, 1)
        XCTAssertEqual(store.reviewSessionPosition()?.total, 3)

        store.updateReviewSession { $0.state.completedCount = 1 }
        XCTAssertEqual(store.reviewSessionPosition()?.current, 2)

        store.endReviewSession()
        XCTAssertNil(store.reviewSessionPosition())
    }
}
