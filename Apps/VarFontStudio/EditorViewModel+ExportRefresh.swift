import Foundation
import VarFontCore

struct PostExportInstancerRecommendation: Equatable {
    let projectID: String
    let fontID: String
    let token: UUID
}

extension EditorViewModel {
    /// Persist a source fingerprint after export or silent legacy migrate.
    @MainActor
    func updateAnalysisSnapshotID(
        projectID: String,
        fontID: String,
        snapshotID: String,
        markProjectDirty: Bool
    ) {
        guard let projectIndex = openProjects.firstIndex(where: { $0.id == projectID }),
              let fontIndex = openProjects[projectIndex].document.fonts.firstIndex(where: { $0.id == fontID }) else {
            return
        }
        guard openProjects[projectIndex].document.fonts[fontIndex].analysisSnapshotID != snapshotID else {
            return
        }
        openProjects[projectIndex].document.fonts[fontIndex].analysisSnapshotID = snapshotID
        openProjects[projectIndex].document.modified = Date()
        publishOpenProjects()
        if activeProjectID == projectID {
            project = openProjects[projectIndex].document
        }
        if markProjectDirty {
            markProjectFileDirty(projectID: projectID)
        }
    }

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
        let snapshotURL = URL(fileURLWithPath: project.fonts[fontIndex].sourcePath)
        if let snapshot = SourceFontFingerprint.capture(url: snapshotURL) {
            project.fonts[fontIndex].analysisSnapshotID = snapshot.serialized
        }
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
