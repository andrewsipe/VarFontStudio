import AppKit
import Foundation
import UniformTypeIdentifiers
import VarFontCore

extension EditorViewModel {
    func presentAddFontPanel(projectID: String? = nil) {
        workspace.pendingAddFontProjectID = projectID ?? activeProjectID
        let panel = NSOpenPanel()
        panel.title = "Add Font to Project"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.fontContentTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.addFont(at: url, toProjectID: self?.workspace.pendingAddFontProjectID ?? self?.activeProjectID)
                self?.workspace.pendingAddFontProjectID = nil
            }
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "New Project — Open Variable Font"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.fontContentTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.createProject(from: url)
            }
        }
    }

    func presentOpenProjectPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.varfontProject]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await self?.openProjectFile(at: url)
            }
        }
    }

    func saveProject() {
        guard let projectID = activeProjectID,
              let open = openProject(for: projectID) else {
            postStatusMessage("No project selected.")
            return
        }
        if let url = open.projectFileURL {
            Task { @MainActor in
                await self.saveProject(document: open.document, to: url, projectID: projectID)
            }
        } else {
            presentSaveProjectAsPanel()
        }
    }

    func saveProjectAs() {
        presentSaveProjectAsPanel()
    }

    func presentSaveProjectAsPanel() {
        guard let projectID = activeProjectID,
              let open = openProject(for: projectID) else {
            postStatusMessage("No project selected.")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Project As"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.varfontProject]
        panel.nameFieldStringValue = defaultProjectFilename(for: open)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let normalized = Self.normalizedProjectFileURL(url)
            Task { @MainActor in
                await self?.saveProject(document: open.document, to: normalized, projectID: projectID)
            }
        }
    }

    func defaultProjectFilename(for open: OpenProject) -> String {
        if let url = open.projectFileURL {
            return url.lastPathComponent
        }
        let base = projectTabLabel(for: open)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = base.isEmpty ? "Untitled" : base
        return ProjectFileFormat.defaultFilename(stem: sanitized.isEmpty ? "Untitled" : sanitized)
    }

    static func normalizedProjectFileURL(_ url: URL) -> URL {
        ProjectFileFormat.normalizedProjectFileURL(url)
    }

    @MainActor
    func saveProject(document: ProjectDocument, to url: URL, projectID: String) async {
        guard let idx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try ProjectDocumentStore.save(openProjects[idx].document, to: url)
            openProjects[idx].projectFileURL = url
            openProjects[idx].projectFileDirty = false
            publishOpenProjects()
            postStatusMessage("Saved project — \(url.lastPathComponent)")
        } catch {
            postStatusMessage("Could not save project: \(error.localizedDescription)")
        }
    }

    func openProjectFile(at url: URL) async {
        let normalized = url.standardizedFileURL
        if let existing = openProjects.first(where: {
            $0.projectFileURL?.standardizedFileURL == normalized
        }) {
            activateProject(id: existing.id)
            postStatusMessage("Already open — \(normalized.lastPathComponent)")
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let document = try ProjectDocumentStore.load(from: normalized)
            let missing = missingFontEntries(in: document)
            if missing.isEmpty {
                await finishOpeningProject(document: document, projectFileURL: normalized)
            } else {
                workspace.missingFontsRequest = MissingFontsRequest(
                    projectFileURL: normalized,
                    document: document,
                    entries: missing
                )
            }
        } catch {
            postStatusMessage("Could not open project: \(error.localizedDescription)")
        }
    }

    func missingFontEntries(in document: ProjectDocument) -> [MissingFontEntry] {
        document.fonts.compactMap { font in
            let path = font.sourcePath
            guard !FileManager.default.fileExists(atPath: path) else { return nil }
            return MissingFontEntry(fontID: font.id, storedPath: path, resolvedURL: nil)
        }
    }

    func locateMissingFont(fontID: String) {
        guard var request = workspace.missingFontsRequest,
              let entryIndex = request.entries.firstIndex(where: { $0.fontID == fontID }) else { return }

        let panel = NSOpenPanel()
        panel.title = "Locate Font"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.fontContentTypes
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            request.entries[entryIndex].resolvedURL = url.standardizedFileURL
            self?.workspace.missingFontsRequest = request
        }
    }

    func cancelMissingFontsRequest() {
        workspace.missingFontsRequest = nil
    }

    func completeMissingFontsRequest() {
        guard let request = workspace.missingFontsRequest, request.allResolved else { return }
        var document = request.document
        for entry in request.entries {
            guard let resolvedURL = entry.resolvedURL,
                  let fontIndex = document.fonts.firstIndex(where: { $0.id == entry.fontID }) else { continue }
            document.fonts[fontIndex].sourcePath = resolvedURL.path
        }
        let projectURL = request.projectFileURL
        workspace.missingFontsRequest = nil
        Task { @MainActor in
            await self.finishOpeningProject(document: document, projectFileURL: projectURL)
        }
    }

    @MainActor
    func finishOpeningProject(document: ProjectDocument, projectFileURL: URL) async {
        var document = document
        _ = RegistrationAxisFactory.promoteClarifiersToRegistration(&document)

        for font in document.fonts {
            let url = URL(fileURLWithPath: font.sourcePath)
            registerSourceBookmark(url: url, fontID: font.id)
        }

        let open = OpenProject(
            document: document,
            selectedFontID: document.preferredSelectedFontID,
            projectFileURL: projectFileURL,
            projectFileDirty: false
        )
        openProjects.append(open)
        activateProject(id: open.id)
        selectedInstanceKey = nil
        selectedInstanceKeys = []
        selectedAxisStopID = nil
        clearUndoHistory()
        // Axis Tree is primary: bring naming chips in line without forcing a dirty save
        // unless the project would already need one for other reasons.
        _ = reconcileNamingToAxisTreeOrder(
            projectID: open.id,
            authorityFontID: open.selectedFontID,
            markProjectDirtyIfChanged: false
        )
        regeneratePlan()
        canSave = document.fonts.contains(where: \.dirty)
        postStatusMessage("Opened project — \(projectFileURL.lastPathComponent)")
    }

    func handleApplicationTerminateRequest() -> Bool {
        guard firstProjectNeedingProjectFileSave() != nil else { return true }
        workspace.confirmQuitRequested = true
        return false
    }

    func completeApplicationTermination() {
        Task {
            await shutdownCommitWorker()
            await MainActor.run {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        }
    }

    func shutdownCommitWorker() async {
        await CommitService.shutdownWorker()
    }

    func confirmQuitDiscardAction() {
        workspace.confirmQuitRequested = false
        for project in openProjects {
            clearSaveReviewState(forProjectID: project.id)
            for font in project.document.fonts {
                removeSourceBookmark(fontID: font.id)
            }
        }
        openProjects.removeAll()
        activeProjectID = nil
        completeApplicationTermination()
    }

    func confirmQuitCancelAction() {
        workspace.confirmQuitRequested = false
        NSApplication.shared.reply(toApplicationShouldTerminate: false)
    }

    func confirmQuitSaveProjectAction() {
        guard let projectID = firstProjectNeedingProjectFileSave() else { return }
        saveProjectThenContinueQuit(projectID: projectID)
    }

    func continueQuitAfterHandlingProjectSaves() {
        if firstProjectNeedingProjectFileSave() != nil {
            confirmQuitSaveProjectAction()
            return
        }
        workspace.confirmQuitRequested = false
        completeApplicationTermination()
    }

    func saveProjectThenContinueQuit(projectID: String) {
        guard let open = openProject(for: projectID) else {
            continueQuitAfterHandlingProjectSaves()
            return
        }
        if let url = open.projectFileURL {
            Task { @MainActor in
                await self.saveProject(document: open.document, to: url, projectID: projectID)
                if self.openProject(for: projectID)?.projectFileDirty == false {
                    self.continueQuitAfterHandlingProjectSaves()
                }
            }
        } else {
            presentSaveProjectAsPanelForQuit(projectID: projectID)
        }
    }

    func presentSaveProjectAsPanelForQuit(projectID: String) {
        guard let open = openProject(for: projectID) else { return }
        let panel = NSSavePanel()
        panel.title = "Save Project Before Quit"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.varfontProject]
        panel.nameFieldStringValue = defaultProjectFilename(for: open)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                self?.confirmQuitCancelAction()
                return
            }
            let normalized = Self.normalizedProjectFileURL(url)
            Task { @MainActor in
                await self?.saveProject(document: open.document, to: normalized, projectID: projectID)
                if self?.openProject(for: projectID)?.projectFileDirty == false {
                    self?.continueQuitAfterHandlingProjectSaves()
                }
            }
        }
    }

    /// Opens a new project tab with the font at `url`.
    func createProject(from url: URL) async {
        if let existing = findFont(normalizedPath: Self.normalizedPath(url)) {
            activateProject(id: existing.projectID)
            selectFont(id: existing.fontID)
            postStatusMessage("Already open — \(url.lastPathComponent)")
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let analysis = try analyzeSourceFont(sourcePath: url.path)
            try validateVariableFont(analysis)
            var imported = ProjectImporter.newProject(from: analysis, sourceURL: url)
            applyDefaultNameIDStrategy(to: &imported)
            if let fontID = imported.fonts.first?.id {
                registerSourceBookmark(url: url, fontID: fontID)
            }
            let open = OpenProject(
                document: imported,
                selectedFontID: imported.preferredSelectedFontID,
                projectFileURL: nil,
                projectFileDirty: true
            )
            openProjects.append(open)
            activateProject(id: open.id)
            selectedInstanceKey = nil
            selectedInstanceKeys = []
            selectedAxisStopID = nil
            clearUndoHistory()
            _ = reconcileNamingToAxisTreeOrder(
                projectID: open.id,
                authorityFontID: open.selectedFontID,
                markProjectDirtyIfChanged: true
            )
            regeneratePlan()
            postStatusMessage("Opened \(url.lastPathComponent)")
            canSave = false
        } catch let error as FontImportError {
            postStatusMessage(error.localizedDescription)
        } catch {
            postStatusMessage("Could not open font: \(error.localizedDescription)")
        }
    }

    func openFont(at url: URL) async {
        await createProject(from: url)
    }

    func addFont(at url: URL, toProjectID: String? = nil, selectAfterAdd: Bool = true) async {
        let targetID = toProjectID ?? activeProjectID
        if openProjects.isEmpty {
            await createProject(from: url)
            return
        }
        guard let targetID,
              openProjects.contains(where: { $0.id == targetID }) else {
            postStatusMessage("No project selected.")
            return
        }

        if let existing = findFont(normalizedPath: Self.normalizedPath(url)) {
            activateProject(id: existing.projectID)
            selectFont(id: existing.fontID)
            postStatusMessage("Already open — \(url.lastPathComponent)")
            return
        }

        isBusy = true
        defer { isBusy = false }
        do {
            let analysis = try analyzeSourceFont(sourcePath: url.path)
            try validateVariableFont(analysis)
            guard let idx = openProjects.firstIndex(where: { $0.id == targetID }) else { return }
            ProjectImporter.addFont(analysis, sourceURL: url, to: &openProjects[idx].document)
            let newFontID = openProjects[idx].document.fonts.last?.id
            if let newFontID {
                registerSourceBookmark(url: url, fontID: newFontID)
            }
            markProjectFileDirty(projectID: targetID)
            activateProject(id: targetID)
            if selectAfterAdd, let newFontID {
                selectFont(id: newFontID)
            }
            // Keep family naming chips aligned to the newly selected / added Axis Tree.
            _ = reconcileNamingToAxisTreeOrder(
                projectID: targetID,
                authorityFontID: newFontID ?? openProjects[idx].selectedFontID,
                markProjectDirtyIfChanged: true
            )
            publishOpenProjects()
            regeneratePlan()
            postStatusMessage("Added \(url.lastPathComponent)")
        } catch let error as FontImportError {
            postStatusMessage(error.localizedDescription)
        } catch {
            postStatusMessage("Could not add font: \(error.localizedDescription)")
        }
    }

}
