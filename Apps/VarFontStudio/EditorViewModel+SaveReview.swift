import AppKit
import Foundation
import UniformTypeIdentifiers
import VarFontCore

extension EditorViewModel {
    // MARK: - Save Review chrome

    var saveReviewWindowTitle: String {
        guard let activeProjectID else { return "Review" }
        return saveReviewWindowTitle(forProjectID: activeProjectID)
    }

    func saveReviewWindowTitle(forProjectID projectID: String) -> String {
        if let open = openProject(for: projectID) {
            return "Review — \(projectTabLabel(for: open))"
        }
        return "Review"
    }

    func fontsForSaveReview(projectID: String) -> [FontDocument] {
        openProject(for: projectID)?.document.fonts ?? []
    }

    func saveReviewSelectedFontID(forProjectID projectID: String) -> String? {
        if let selected = saveReview.selectedFontID(projectID: projectID) {
            return selected
        }
        return openProject(for: projectID)?.selectedFontID
    }

    func saveReviewSession(forProjectID projectID: String, fontID: String? = nil) -> CommitPreflightSession? {
        guard let fontID = fontID ?? saveReviewSelectedFontID(forProjectID: projectID) else { return nil }
        return saveReview.session(projectID: projectID, fontID: fontID)
    }

    func saveReviewUIState(forProjectID projectID: String) -> SaveReviewUIState {
        saveReview.uiState(forProjectID: projectID)
    }

    func updateSaveReviewUIState(forProjectID projectID: String, _ transform: (inout SaveReviewUIState) -> Void) {
        saveReview.updateUIState(forProjectID: projectID, transform)
    }

    func isSaveReviewLoading(forProjectID projectID: String, fontID: String? = nil) -> Bool {
        saveReview.isLoading(projectID: projectID, fontID: fontID)
    }

    func selectSaveReviewFont(projectID: String, fontID: String) {
        saveReview.selectFont(projectID: projectID, fontID: fontID)
        guard canPreviewSaveReview(forProjectID: projectID, fontID: fontID) else { return }
        let isDirty = openProjects
            .first(where: { $0.id == projectID })?
            .document.fonts.first(where: { $0.id == fontID })?
            .dirty ?? false
        if saveReviewSession(forProjectID: projectID, fontID: fontID) == nil || isDirty {
            refreshCommitDiffPreview(forProjectID: projectID, fontID: fontID)
        }
    }

    func saveReviewWasExplicitlyOpened(forProjectID projectID: String) -> Bool {
        saveReview.wasExplicitlyOpened(projectID: projectID)
    }

    func presentSaveReviewWindow(forProjectID projectID: String? = nil) {
        let targetID = projectID ?? activeProjectID
        guard let targetID else {
            postStatusMessage("Open a project first.")
            return
        }
        guard canPreviewSaveReview(forProjectID: targetID) else {
            postStatusMessage("Nothing to preview — select a font in this project first.")
            return
        }
        if let fontID = selectedFont(forProjectID: targetID)?.id {
            saveReview.ensureSelectedFont(projectID: targetID, fontID: fontID)
        }
        let fontID = saveReviewSelectedFontID(forProjectID: targetID)
        refreshCommitDiffPreview(forProjectID: targetID, fontID: fontID, presentSheet: false)
        saveReview.markExplicitlyOpened(projectID: targetID)
        saveReview.resetUIState(forProjectID: targetID)
        saveReview.requestOpen(projectID: targetID)
        Task {
            await commitService.ensureWorkerReady()
        }
    }

    func toggleSaveReviewWindow(forProjectID projectID: String? = nil) {
        let targetID = projectID ?? activeProjectID
        guard let targetID else {
            postStatusMessage("Open a project first.")
            return
        }
        if isSaveReviewWindowOpen(forProjectID: targetID) {
            closeSaveReviewWindow(forProjectID: targetID)
            return
        }
        presentSaveReviewWindow(forProjectID: targetID)
    }

    func presentShortcutsHelp() {
        showShortcutsHelp = true
    }

    func isSaveReviewWindowOpen(forProjectID projectID: String) -> Bool {
        let title = saveReviewWindowTitle(forProjectID: projectID)
        return NSApplication.shared.windows.contains { window in
            SaveReviewWindowLifecycle.isSaveReviewWindow(window) && window.title == title
        }
    }

    func closeSaveReviewWindow(forProjectID projectID: String) {
        let title = saveReviewWindowTitle(forProjectID: projectID)
        for window in NSApplication.shared.windows where SaveReviewWindowLifecycle.isSaveReviewWindow(window) && window.title == title {
            window.close()
        }
    }

    /// Drop save-review payload when quitting or closing a restored auxiliary window.
    func clearSaveReviewState(forProjectID projectID: String? = nil, fontID: String? = nil) {
        saveReview.clear(projectID: projectID, fontID: fontID)
    }

    func canPreviewSaveReview(forProjectID projectID: String, fontID: String) -> Bool {
        guard let open = openProject(for: projectID),
              open.document.fonts.contains(where: { $0.id == fontID }) else { return false }
        return instancePlan(forProjectID: projectID, fontID: fontID) != nil
    }

    func canPreviewSaveReview(forProjectID projectID: String) -> Bool {
        guard let open = openProject(for: projectID) else { return false }
        return open.document.fonts.contains { canPreviewSaveReview(forProjectID: projectID, fontID: $0.id) }
    }

    var canPreviewSaveReview: Bool {
        guard let activeProjectID else { return false }
        return canPreviewSaveReview(forProjectID: activeProjectID)
    }

}
