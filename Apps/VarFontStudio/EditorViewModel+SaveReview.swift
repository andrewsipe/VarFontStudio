import AppKit
import Foundation
import VarFontCore

extension EditorViewModel {
    // MARK: - Save Review chrome (facades → SaveReviewStore)

    var saveReviewWindowTitle: String { saveReview.saveReviewWindowTitle }
    func saveReviewWindowTitle(forProjectID projectID: String) -> String {
        saveReview.saveReviewWindowTitle(forProjectID: projectID)
    }
    func fontsForSaveReview(projectID: String) -> [FontDocument] {
        saveReview.fontsForSaveReview(projectID: projectID)
    }
    func saveReviewSelectedFontID(forProjectID projectID: String) -> String? {
        saveReview.saveReviewSelectedFontID(forProjectID: projectID)
    }
    func saveReviewSession(forProjectID projectID: String, fontID: String? = nil) -> CommitPreflightSession? {
        saveReview.saveReviewSession(forProjectID: projectID, fontID: fontID)
    }
    func saveReviewUIState(forProjectID projectID: String) -> SaveReviewUIState {
        saveReview.saveReviewUIState(forProjectID: projectID)
    }
    func updateSaveReviewUIState(forProjectID projectID: String, _ transform: (inout SaveReviewUIState) -> Void) {
        saveReview.updateSaveReviewUIState(forProjectID: projectID, transform)
    }
    func isSaveReviewLoading(forProjectID projectID: String, fontID: String? = nil) -> Bool {
        saveReview.isSaveReviewLoading(forProjectID: projectID, fontID: fontID)
    }
    func selectSaveReviewFont(projectID: String, fontID: String) {
        saveReview.selectSaveReviewFont(projectID: projectID, fontID: fontID)
    }
    func saveReviewWasExplicitlyOpened(forProjectID projectID: String) -> Bool {
        saveReview.saveReviewWasExplicitlyOpened(forProjectID: projectID)
    }
    func presentSaveReviewWindow(forProjectID projectID: String? = nil) {
        saveReview.presentSaveReviewWindow(forProjectID: projectID)
    }
    func toggleSaveReviewWindow(forProjectID projectID: String? = nil) {
        saveReview.toggleSaveReviewWindow(forProjectID: projectID)
    }
    func presentShortcutsHelp() { showShortcutsHelp = true }
    func isSaveReviewWindowOpen(forProjectID projectID: String) -> Bool {
        saveReview.isSaveReviewWindowOpen(forProjectID: projectID)
    }
    func closeSaveReviewWindow(forProjectID projectID: String) {
        saveReview.closeSaveReviewWindow(forProjectID: projectID)
    }
    func clearSaveReviewState(forProjectID projectID: String? = nil, fontID: String? = nil) {
        saveReview.clearSaveReviewState(forProjectID: projectID, fontID: fontID)
    }
    func canPreviewSaveReview(forProjectID projectID: String, fontID: String) -> Bool {
        saveReview.canPreviewSaveReview(forProjectID: projectID, fontID: fontID)
    }
    func canPreviewSaveReview(forProjectID projectID: String) -> Bool {
        saveReview.canPreviewSaveReview(forProjectID: projectID)
    }
    var canPreviewSaveReview: Bool { saveReview.canPreviewSaveReview }
}
