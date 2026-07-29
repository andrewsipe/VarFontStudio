import Foundation

extension EditorViewModel {
    /// True when the active project has at least one font to load into Instancer.
    var canPresentInstancer: Bool {
        guard let id = activeProjectID else { return false }
        return canPresentInstancer(forProjectID: id)
    }

    func canPresentInstancer(forProjectID projectID: String) -> Bool {
        guard let open = openProject(for: projectID) else { return false }
        return !open.document.fonts.isEmpty
    }

    /// Toolbar / ⌃⌘5 — opens Instancer for the active project.
    func toggleInstancerWindow(projectID: String? = nil, fontID: String? = nil) {
        let targetProjectID = projectID ?? activeProjectID
        guard let targetProjectID, canPresentInstancer(forProjectID: targetProjectID) else {
            postStatusMessage(instancerBlockedMessage(projectID: targetProjectID))
            return
        }
        instancer.toggleInstancerWindow(
            projectID: targetProjectID,
            fontID: fontID ?? (targetProjectID == activeProjectID ? selectedFontID : nil)
        )
    }

    /// Project menu / post-export — opens Instancer for a Studio project font.
    func presentInstancerWindow(projectID: String? = nil, fontID: String? = nil) {
        let targetProjectID = projectID ?? activeProjectID
        guard let targetProjectID, canPresentInstancer(forProjectID: targetProjectID) else {
            postStatusMessage(instancerBlockedMessage(projectID: targetProjectID))
            return
        }
        let targetFontID = fontID ?? (targetProjectID == activeProjectID ? selectedFontID : nil)
        instancer.presentInstancerWindow(projectID: targetProjectID, fontID: targetFontID)
    }

    private func instancerBlockedMessage(projectID: String?) -> String {
        if openProjects.isEmpty {
            return "Open a project with at least one font to use Instancer."
        }
        if projectID == nil {
            return "Select a project before opening Instancer."
        }
        if let open = openProject(for: projectID!), open.document.fonts.isEmpty {
            return "Add at least one font to this project before opening Instancer."
        }
        return "Open a project with at least one font to use Instancer."
    }
}
