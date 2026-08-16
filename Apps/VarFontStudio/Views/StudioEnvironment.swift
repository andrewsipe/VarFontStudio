import SwiftUI

extension View {
    /// Shared environment for Studio windows: editor + satellite stores that must
    /// observe independently (so Review/Instancer progress does not refresh the main tree).
    func studioEnvironment(editor: EditorViewModel, layout: EditorLayoutPreferences) -> some View {
        self
            .environmentObject(editor)
            .environmentObject(layout)
            .environmentObject(editor.saveReview)
            .environmentObject(editor.instancer)
            .environmentObject(editor.previewInteraction)
            .environment(editor.workspaceDrag)
    }
}
