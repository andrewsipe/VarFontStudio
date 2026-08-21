import SwiftUI

/// Ensures only one `AuxiliaryWindowOpenBridge` instance handles a given open token.
///
/// The bridge is mounted on Main, Review, and Instancer so any surface can reopen the
/// others when the main window is closed. Without a gate, every mounted bridge reacts
/// to the same `openRequest` and each calls `openWindow`, which occasionally creates
/// duplicate Scene windows for the same project value.
enum AuxiliaryWindowOpenGate {
    private static var claimedTokens = Set<UUID>()

    /// Returns true the first time `token` is seen; false for later bridges.
    static func claim(_ token: UUID) -> Bool {
        if claimedTokens.contains(token) { return false }
        claimedTokens.insert(token)
        if claimedTokens.count > 64 {
            claimedTokens = [token]
        }
        return true
    }

    #if DEBUG
    static func resetForTests() {
        claimedTokens.removeAll()
    }
    #endif
}

/// Isolates `openWindow` observers so host views stay type-checkable.
/// Mounted on the main editor and Instancer so either window can reopen the other.
struct AuxiliaryWindowOpenBridge: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var saveReview: SaveReviewStore
    @EnvironmentObject private var instancer: InstancerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: editor.mainWindowOpenRequest) { _, request in
                guard request != nil else { return }
                if MainWindowLifecycle.focusExistingMainWindow() { return }
                openWindow(id: "main")
            }
            .onChange(of: saveReview.openRequest) { _, request in
                guard let request else { return }
                guard AuxiliaryWindowOpenGate.claim(request.token) else { return }
                if SaveReviewWindowLifecycle.focusExisting(projectID: request.projectID) {
                    return
                }
                openWindow(id: "save-review", value: request.projectID)
            }
            .onChange(of: instancer.openRequest) { _, request in
                guard let request else { return }
                guard AuxiliaryWindowOpenGate.claim(request.token) else { return }
                if InstancerWindowLifecycle.focusExisting(windowKey: request.windowKey) {
                    return
                }
                openWindow(id: "instancer", value: request.windowKey)
            }
    }
}
