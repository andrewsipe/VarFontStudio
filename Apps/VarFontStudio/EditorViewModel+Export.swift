import AppKit
import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Export (facades → SaveReviewStore)

    func saveCopy() { saveReview.saveCopy() }
    func requestSaveToOriginal() { saveReview.requestSaveToOriginal() }
    func confirmSaveToOriginalAction() { saveReview.confirmSaveToOriginalAction() }
    func saveToOriginalConfirmationMessage(for session: CommitPreflightSession) -> String {
        saveReview.saveToOriginalConfirmationMessage(for: session)
    }
    func save() { saveReview.save() }
    func canSaveToRememberedPath(forProjectID projectID: String, fontID: String) -> Bool {
        saveReview.canSaveToRememberedPath(forProjectID: projectID, fontID: fontID)
    }
    var canSaveToRememberedPathForSelection: Bool { saveReview.canSaveToRememberedPathForSelection }
    func savedOutputLabel(for font: FontDocument) -> String? {
        saveReview.savedOutputLabel(for: font)
    }
    func ensureSaveReviewSession(projectID: String, fontID: String, preferWorker: Bool = true) async -> CommitPreflightSession? {
        await saveReview.ensureSaveReviewSession(projectID: projectID, fontID: fontID, preferWorker: preferWorker)
    }
    @discardableResult
    func refreshCommitDiffPreviewAsync(
        forProjectID projectID: String? = nil,
        fontID: String? = nil,
        presentSheet: Bool = false,
        preferWorker: Bool = true
    ) async -> CommitPreflightSession? {
        await saveReview.refreshCommitDiffPreviewAsync(
            forProjectID: projectID, fontID: fontID, presentSheet: presentSheet, preferWorker: preferWorker
        )
    }
    func dismissCommitDiffSheet() { saveReview.dismissCommitDiffSheet() }
    func refreshCommitDiffPreview(
        forProjectID projectID: String? = nil,
        fontID: String? = nil,
        presentSheet: Bool = false
    ) {
        saveReview.refreshCommitDiffPreview(forProjectID: projectID, fontID: fontID, presentSheet: presentSheet)
    }
    func exportCommitJSON(session: CommitPreflightSession) {
        saveReview.exportCommitJSON(session: session)
    }
    func presentSavePanel(for session: CommitPreflightSession) {
        saveReview.presentSavePanel(for: session)
    }
    func save(session: CommitPreflightSession) { saveReview.save(session: session) }
    func saveAllFiles(inProjectID projectID: String? = nil) {
        saveReview.saveAllFiles(inProjectID: projectID)
    }
    var isSaveActionBlocked: Bool { saveReview.isSaveActionBlocked }
    func performSave(
        session: CommitPreflightSession,
        to outputURL: URL,
        inPlace: Bool = false,
        manageBusyState: Bool = true
    ) async {
        await saveReview.performSave(
            session: session, to: outputURL, inPlace: inPlace, manageBusyState: manageBusyState
        )
    }
}
