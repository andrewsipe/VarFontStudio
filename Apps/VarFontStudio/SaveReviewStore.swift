import Combine
import Foundation
import VarFontCore

/// Chrome and session state for the Review / export flow.
/// Owned by `EditorViewModel`; export I/O and project lookups stay on the editor.
@MainActor
final class SaveReviewStore: ObservableObject {
    @Published private(set) var sessionsByKey: [String: CommitPreflightSession] = [:]
    @Published var presentCommitDiffSheet = false
    @Published private(set) var openRequest: SaveReviewOpenRequest?
    @Published private(set) var loadingKeys: Set<String> = []
    @Published private(set) var selectedFontIDByProjectID: [String: String] = [:]
    @Published private(set) var explicitlyOpenedProjectIDs: Set<String> = []
    @Published var uiStateByProjectID: [String: SaveReviewUIState] = [:]
    @Published var confirmSaveToOriginal: CommitPreflightSession?
    @Published var persistentSaveError: String?

    func sessionKey(projectID: String, fontID: String) -> String {
        "\(projectID)|\(fontID)"
    }

    func session(projectID: String, fontID: String) -> CommitPreflightSession? {
        sessionsByKey[sessionKey(projectID: projectID, fontID: fontID)]
    }

    func uiState(forProjectID projectID: String) -> SaveReviewUIState {
        uiStateByProjectID[projectID] ?? SaveReviewUIState()
    }

    func updateUIState(forProjectID projectID: String, _ transform: (inout SaveReviewUIState) -> Void) {
        var state = uiState(forProjectID: projectID)
        transform(&state)
        uiStateByProjectID[projectID] = state
    }

    func resetUIState(forProjectID projectID: String) {
        uiStateByProjectID[projectID] = SaveReviewUIState()
    }

    func isLoading(projectID: String, fontID: String? = nil) -> Bool {
        if let fontID {
            return loadingKeys.contains(sessionKey(projectID: projectID, fontID: fontID))
        }
        return loadingKeys.contains { $0.hasPrefix("\(projectID)|") }
    }

    func wasExplicitlyOpened(projectID: String) -> Bool {
        explicitlyOpenedProjectIDs.contains(projectID)
    }

    func selectFont(projectID: String, fontID: String) {
        let previous = selectedFontIDByProjectID[projectID]
        selectedFontIDByProjectID[projectID] = fontID
        if previous != fontID {
            updateUIState(forProjectID: projectID) { $0.searchQuery = "" }
        }
    }

    func ensureSelectedFont(projectID: String, fontID: String) {
        if selectedFontIDByProjectID[projectID] == nil {
            selectedFontIDByProjectID[projectID] = fontID
        }
    }

    func selectedFontID(projectID: String) -> String? {
        selectedFontIDByProjectID[projectID]
    }

    func markExplicitlyOpened(projectID: String) {
        explicitlyOpenedProjectIDs.insert(projectID)
    }

    func requestOpen(projectID: String) {
        openRequest = SaveReviewOpenRequest(projectID: projectID, token: UUID())
    }

    func beginLoading(projectID: String, fontID: String) {
        loadingKeys.insert(sessionKey(projectID: projectID, fontID: fontID))
    }

    func endLoading(projectID: String, fontID: String) {
        loadingKeys.remove(sessionKey(projectID: projectID, fontID: fontID))
    }

    func storeSession(_ session: CommitPreflightSession, projectID: String, fontID: String) {
        sessionsByKey[sessionKey(projectID: projectID, fontID: fontID)] = session
    }

    func clear(projectID: String? = nil, fontID: String? = nil) {
        if let projectID, let fontID {
            let key = sessionKey(projectID: projectID, fontID: fontID)
            sessionsByKey.removeValue(forKey: key)
            loadingKeys.remove(key)
        } else if let projectID {
            for key in sessionsByKey.keys where key.hasPrefix("\(projectID)|") {
                sessionsByKey.removeValue(forKey: key)
            }
            for key in loadingKeys where key.hasPrefix("\(projectID)|") {
                loadingKeys.remove(key)
            }
            selectedFontIDByProjectID.removeValue(forKey: projectID)
            explicitlyOpenedProjectIDs.remove(projectID)
            uiStateByProjectID.removeValue(forKey: projectID)
        } else {
            sessionsByKey.removeAll()
            loadingKeys.removeAll()
            selectedFontIDByProjectID.removeAll()
            explicitlyOpenedProjectIDs.removeAll()
            uiStateByProjectID.removeAll()
        }
        presentCommitDiffSheet = false
    }

    func dismissSheet() {
        presentCommitDiffSheet = false
    }

    func presentSheet() {
        presentCommitDiffSheet = true
    }

    func setPersistentError(_ message: String?) {
        persistentSaveError = message
    }
}
