import Combine
import Foundation

/// Confirmation dialogs and ephemeral workspace chrome (missing fonts, target picker, quit).
/// Owned by `EditorViewModel`; project mutations stay on the editor.
@MainActor
final class ProjectWorkspaceStore: ObservableObject {
    @Published var confirmRemoveFont: FontRemovalRequest?
    @Published var confirmMoveFont: FontMoveRequest?
    @Published var confirmCombineProjects: ProjectCombineRequest?
    @Published var confirmSplitFont: FontSplitRequest?
    @Published var confirmCloseProjectID: String?
    @Published var confirmQuitRequested = false
    @Published var missingFontsRequest: MissingFontsRequest?
    @Published var confirmSetAsMasterFontID: String?
    @Published var confirmPushAxisTree = false
    @Published var pendingAddFontProjectID: String?
    @Published var projectTargetPickerMode: ProjectTargetPickerMode?

    func clearRemoveFont() { confirmRemoveFont = nil }
    func clearMoveFont() { confirmMoveFont = nil }
    func clearCombineProjects() { confirmCombineProjects = nil }
    func clearSplitFont() { confirmSplitFont = nil }
    func clearCloseProject() { confirmCloseProjectID = nil }
    func clearQuit() { confirmQuitRequested = false }
    func clearSetAsMaster() { confirmSetAsMasterFontID = nil }
    func clearPushAxisTree() { confirmPushAxisTree = false }
    func clearTargetPicker() { projectTargetPickerMode = nil }
    func clearMissingFonts() { missingFontsRequest = nil }
}
