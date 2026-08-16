import Combine
import Foundation
import VarFontCore

struct AxisConflictResolverSession: Identifiable {
    let id = UUID()
    let bundle: AxisConflictBundle
    let reviewPosition: Int?
    let reviewTotal: Int?
}

struct PlanIssueResolverSession: Identifiable {
    let id = UUID()
    let warning: PlanWarning
    let reviewPosition: Int?
    let reviewTotal: Int?
}

struct FvarStatConflictSession: Identifiable {
    let id = UUID()
    var conflicts: [FvarStopSeeder.NameConflict]
    var index: Int

    var current: FvarStopSeeder.NameConflict? {
        guard conflicts.indices.contains(index) else { return nil }
        return conflicts[index]
    }

    var reviewPosition: Int? {
        conflicts.isEmpty ? nil : index + 1
    }

    var reviewTotal: Int? {
        conflicts.isEmpty ? nil : conflicts.count
    }
}

struct AxisTreeReviewSession {
    var state: AxisTreeReviewSessionState
}

/// Conflict / plan-issue session state **and** orchestration (via `IssueResolverHost`).
@MainActor
final class IssueResolverStore: ObservableObject {
    /// Set by `EditorViewModel` in `init`.
    weak var host: (any IssueResolverHost)?

    var requireHost: any IssueResolverHost {
        guard let host else {
            preconditionFailure("IssueResolverStore.host was not set")
        }
        return host
    }

    @Published var conflictResolverRequest: AxisConflictResolverSession?
    @Published var planIssueResolverRequest: PlanIssueResolverSession?
    @Published var fvarStatConflictRequest: FvarStatConflictSession?
    /// Pending Import Review sessions (one per font that needs decisions).
    @Published var fvarImportReviewQueue: [FvarImportReviewSession] = []
    /// Active file in the Import Review sheet — nil when the queue is empty.
    @Published var fvarImportReviewSelectedFontID: String?

    /// Selected session, or the first pending one.
    var fvarImportReviewRequest: FvarImportReviewSession? {
        if let selected = fvarImportReviewSelectedFontID,
           let match = fvarImportReviewQueue.first(where: { $0.fontID == selected }) {
            return match
        }
        return fvarImportReviewQueue.first
    }

    private(set) var reviewSession: AxisTreeReviewSession?

    var hasActiveReviewSession: Bool { reviewSession != nil }

    func startReviewSession(state: AxisTreeReviewSessionState) {
        reviewSession = AxisTreeReviewSession(state: state)
    }

    func updateReviewSession(_ transform: (inout AxisTreeReviewSession) -> Void) {
        guard var session = reviewSession else { return }
        transform(&session)
        reviewSession = session
    }

    func endReviewSession() {
        reviewSession = nil
    }

    func reviewSessionPosition() -> (current: Int, total: Int)? {
        reviewSession?.state.displayPosition()
    }

    func presentConflict(
        bundle: AxisConflictBundle,
        reviewPosition: Int?,
        reviewTotal: Int?
    ) {
        conflictResolverRequest = AxisConflictResolverSession(
            bundle: bundle,
            reviewPosition: reviewPosition,
            reviewTotal: reviewTotal
        )
    }

    func presentPlanIssue(
        warning: PlanWarning,
        reviewPosition: Int?,
        reviewTotal: Int?
    ) {
        planIssueResolverRequest = PlanIssueResolverSession(
            warning: warning,
            reviewPosition: reviewPosition,
            reviewTotal: reviewTotal
        )
    }

    func presentFvarStatConflicts(_ conflicts: [FvarStopSeeder.NameConflict]) {
        guard !conflicts.isEmpty else { return }
        fvarStatConflictRequest = FvarStatConflictSession(conflicts: conflicts, index: 0)
    }

    func presentFvarImportReview(report: FvarStopSeeder.Report, fontID: String) {
        guard report.needsReview else { return }
        let session = FvarImportReviewSession(report: report, fontID: fontID)
        if let index = fvarImportReviewQueue.firstIndex(where: { $0.fontID == fontID }) {
            fvarImportReviewQueue[index] = session
        } else {
            fvarImportReviewQueue.append(session)
        }
        if fvarImportReviewSelectedFontID == nil
            || !fvarImportReviewQueue.contains(where: { $0.fontID == fvarImportReviewSelectedFontID }) {
            fvarImportReviewSelectedFontID = fontID
        }
    }

    func selectFvarImportReviewFont(fontID: String) {
        guard fvarImportReviewQueue.contains(where: { $0.fontID == fontID }) else { return }
        fvarImportReviewSelectedFontID = fontID
    }

    func dismissConflictResolver(clearReviewSession: Bool) {
        conflictResolverRequest = nil
        if clearReviewSession {
            reviewSession = nil
        }
    }

    func dismissPlanIssueResolver(clearReviewSession: Bool) {
        planIssueResolverRequest = nil
        if clearReviewSession {
            reviewSession = nil
        }
    }

    func dismissFvarStatConflictResolver() {
        fvarStatConflictRequest = nil
    }

    /// Remove one finished/cancelled Import Review and select the next pending file.
    @discardableResult
    func completeFvarImportReview(fontID: String) -> Bool {
        fvarImportReviewQueue.removeAll { $0.fontID == fontID }
        if fvarImportReviewSelectedFontID == fontID {
            fvarImportReviewSelectedFontID = fvarImportReviewQueue.first?.fontID
        }
        return !fvarImportReviewQueue.isEmpty
    }

    /// Dismiss the whole Import Review queue (sheet closed without finishing remaining files).
    func dismissFvarImportReview() {
        fvarImportReviewQueue = []
        fvarImportReviewSelectedFontID = nil
    }

    func clearBothResolvers() {
        planIssueResolverRequest = nil
        conflictResolverRequest = nil
        fvarStatConflictRequest = nil
        dismissFvarImportReview()
    }

    func clearBothResolversAndReviewSession() {
        clearBothResolvers()
        reviewSession = nil
    }
}
