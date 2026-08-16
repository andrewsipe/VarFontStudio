import SwiftUI

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
                openWindow(id: "save-review", value: request.projectID)
            }
            .onChange(of: instancer.openRequest) { _, request in
                guard let request else { return }
                openWindow(id: "instancer", value: request.windowKey)
            }
    }
}
