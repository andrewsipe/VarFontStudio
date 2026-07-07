import XCTest
@testable import VarFontCore

final class AxisTreeReviewSessionStateTests: XCTestCase {
    func testDisplayPositionAtStart() {
        let state = AxisTreeReviewSessionState(scope: .full, initialTotal: 5)
        let position = state.displayPosition()
        XCTAssertEqual(position?.current, 1)
        XCTAssertEqual(position?.total, 5)
    }

    func testDisplayPositionAfterAdvances() {
        var state = AxisTreeReviewSessionState(scope: .full, initialTotal: 5, completedCount: 2)
        var position = state.displayPosition()
        XCTAssertEqual(position?.current, 3)
        XCTAssertEqual(position?.total, 5)
        state.completedCount = 5
        position = state.displayPosition()
        XCTAssertEqual(position?.current, 5)
        XCTAssertEqual(position?.total, 5)
    }

    func testFilterAxisScopedQueue() {
        let wdthWarning = PlanWarning(
            code: "multiple_elidable",
            axis: "wdth",
            message: "wdth"
        )
        let wghtWarning = PlanWarning(
            code: "multiple_elidable",
            axis: "wght",
            message: "wght"
        )
        let wdthBundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )
        let wghtBundle = AxisConflictBundle(
            axisTag: "wght",
            axisLabel: "Weight",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["c", "d"]
        )
        let items: [AxisTreeReviewItem] = [
            .planIssue(wdthWarning),
            .axisConflict(wdthBundle),
            .planIssue(wghtWarning),
            .axisConflict(wghtBundle),
        ]

        let filtered = AxisTreeReviewQueue.filter(items, axisTag: "wdth")
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.axisTag == "wdth" })
    }

    func testScopedQueueFromSessionState() {
        let state = AxisTreeReviewSessionState(scope: .axis("wdth"), initialTotal: 2)
        let items: [AxisTreeReviewItem] = [
            .planIssue(PlanWarning(code: "multiple_elidable", axis: "wdth", message: "wdth")),
            .planIssue(PlanWarning(code: "multiple_elidable", axis: "wght", message: "wght")),
        ]
        XCTAssertEqual(state.scopedQueue(from: items).count, 1)
        XCTAssertEqual(state.scopedQueue(from: items).first?.axisTag, "wdth")
    }
}
