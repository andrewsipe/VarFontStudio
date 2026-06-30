import Foundation
import VarFontCore

/// Dry-run result and diff report shown before writing a patched font copy.
struct CommitPreflightSession: Identifiable {
    let id = UUID()
    let projectID: String
    let fontID: String
    let dryRunRequest: CommitRequest
    let baseRequest: CommitRequest
    let preflight: CommitResult
    let diffReport: CommitDiffReport
}

struct SaveReviewOpenRequest: Equatable {
    let projectID: String
    let token: UUID
}
