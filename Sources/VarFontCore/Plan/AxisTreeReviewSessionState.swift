import Foundation

public struct AxisTreeReviewSessionState: Equatable, Sendable {
    public enum Scope: Equatable, Sendable {
        case full
        case axis(String)
    }

    public var scope: Scope
    public var initialTotal: Int
    public var completedCount: Int

    public init(scope: Scope, initialTotal: Int, completedCount: Int = 0) {
        self.scope = scope
        self.initialTotal = initialTotal
        self.completedCount = completedCount
    }

    public func displayPosition() -> (current: Int, total: Int)? {
        guard initialTotal > 0 else { return nil }
        let current = min(completedCount + 1, initialTotal)
        return (current, initialTotal)
    }

    public func scopedQueue(from items: [AxisTreeReviewItem]) -> [AxisTreeReviewItem] {
        switch scope {
        case .full:
            return items
        case .axis(let tag):
            return AxisTreeReviewQueue.filter(items, axisTag: tag)
        }
    }
}
