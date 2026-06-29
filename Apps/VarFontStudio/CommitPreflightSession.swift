import Foundation
import VarFontCore

/// Dry-run result shown before writing a patched font copy.
struct CommitPreflightSession: Identifiable {
    let id = UUID()
    let baseRequest: CommitRequest
    let preflight: CommitResult
}
