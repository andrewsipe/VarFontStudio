import Foundation
import VarFontCore

/// Dry-run result and diff report shown before writing a patched font copy.
struct CommitPreflightSession: Identifiable {
    let id = UUID()
    let projectID: String
    let fontID: String
    /// Matches `EditorViewModel.planRevision` when this session was built for the active font.
    /// Used so Review can reuse a prefetched dry-run even while the font is still dirty.
    let planRevision: Int
    let dryRunRequest: CommitRequest
    let baseRequest: CommitRequest
    let preflight: CommitResult
    let diffReport: CommitDiffReport
    /// UI-ready tabbed presentation (built at preflight time).
    let presentation: SaveReviewPresentation
    /// Non-blocking notes (source drift, project fvar scale vs source, registry hints).
    /// Also mirrored into `preflight.warnings` when actionable at Review.
    let informationalNotes: [String]
}

struct SaveReviewOpenRequest: Equatable {
    let projectID: String
    let token: UUID
}

/// Per-project Save Review chrome state (filters, tab, search).
struct SaveReviewUIState: Equatable {
    var selectedTableTab: SaveReviewTableTab = .stat
    var userPickedTableTab: Bool = false
    var hiddenCategories: Set<SaveReviewDisplayCategory> = []
    var isolateCategory: SaveReviewDisplayCategory? = nil
    var searchQuery: String = ""
}
