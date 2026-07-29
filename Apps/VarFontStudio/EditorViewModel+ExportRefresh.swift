import Foundation
import VarFontCore

struct PostExportInstancerRecommendation: Equatable {
    let projectID: String
    let fontID: String
    let token: UUID
}

extension EditorViewModel {
    /// Reconcile project paths and UI after a successful Review export.
    @MainActor
    func refreshProjectAfterExport(
        projectID: String,
        fontID: String,
        writtenPath: String,
        inPlace: Bool,
        previousSourcePath: String
    ) async {
        guard let projectIndex = openProjects.firstIndex(where: { $0.id == projectID }),
              let fontIndex = openProjects[projectIndex].document.fonts.firstIndex(where: { $0.id == fontID }) else {
            return
        }

        var project = openProjects[projectIndex].document
        let normalizedWritten = Self.normalizedPath(writtenPath)

        if inPlace {
            SourceFontAccess.invalidateCache(fontID: fontID)
            let sourceURL = URL(fileURLWithPath: previousSourcePath)
            registerSourceBookmark(url: sourceURL, fontID: fontID)
            project.fonts[fontIndex].outputPath = previousSourcePath
        } else {
            if project.fonts[fontIndex].importPath == nil {
                project.fonts[fontIndex].importPath = previousSourcePath
            }
            project.fonts[fontIndex].sourcePath = normalizedWritten
            project.fonts[fontIndex].outputPath = normalizedWritten
            SourceFontAccess.invalidateCache(fontID: fontID)
            registerSourceBookmark(url: URL(fileURLWithPath: normalizedWritten), fontID: fontID)
        }

        project.fonts[fontIndex].dirty = false
        project.modified = Date()
        openProjects[projectIndex].document = project
        publishOpenProjects()

        if activeProjectID == projectID {
            self.project = project
            refreshCanSave()
            if selectedFontID == fontID {
                regeneratePlan()
            }
        }

        markProjectFileDirty(projectID: projectID)
        instancer.reloadSessionAfterExport(projectID: projectID, fontID: fontID)

        ensureMainWindowVisible()
        postExportInstancerRecommendation = PostExportInstancerRecommendation(
            projectID: projectID,
            fontID: fontID,
            token: UUID()
        )
    }

    func dismissPostExportInstancerRecommendation() {
        postExportInstancerRecommendation = nil
    }

    func acceptPostExportInstancerRecommendation() {
        guard let offer = postExportInstancerRecommendation else { return }
        dismissPostExportInstancerRecommendation()
        activateProject(id: offer.projectID)
        selectFont(id: offer.fontID)
        presentInstancerWindow(projectID: offer.projectID, fontID: offer.fontID)
    }
}
