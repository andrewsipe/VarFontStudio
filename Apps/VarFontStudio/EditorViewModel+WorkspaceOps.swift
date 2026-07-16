import AppKit
import Foundation
import UniformTypeIdentifiers
import VarFontCore

extension EditorViewModel {
    func activateProject(id: String) {
        guard openProjects.contains(where: { $0.id == id }) else { return }
        activeProjectID = id
        selectedInstanceKey = nil
        selectedInstanceKeys = []
        selectedAxisStopID = nil
        refreshCanSave()
        regeneratePlan()
    }

    func selectFont(id: String) {
        selectedFontID = id
        selectedInstanceKey = nil
        selectedInstanceKeys = []
        regeneratePlan()
    }

    func selectMasterFont(for projectID: String? = nil) {
        let targetID = projectID ?? activeProjectID
        guard let targetID, let masterID = masterFontID(for: targetID) else { return }
        if targetID == activeProjectID {
            selectFont(id: masterID)
        } else if let idx = openProjects.firstIndex(where: { $0.id == targetID }) {
            openProjects[idx].selectedFontID = masterID
        }
    }

    func focusInspectorProjectScope(
        fontID: String? = nil,
        fileNaming: InspectorFileNamingFocus? = nil
    ) {
        if let fontID {
            selectFont(id: fontID)
        }
        inspectorFocus.revealProjectScope(fileNaming: fileNaming)
    }

    func clearInspectorFileNamingFocus() {
        inspectorFocus.clearFileNamingFocus()
    }

    func updateInspectorScopeForSelection() {
        inspectorFocus.updateScopeForInstanceSelection(
            hasInspectableInstance: inspectorInspectableInstance != nil
        )
    }

    func renameProject(id: String, displayName: String) {
        guard let idx = openProjects.firstIndex(where: { $0.id == id }) else { return }
        pushUndoSnapshot()
        syncProjectDisplayNameAndPrefix(
            normalizedProjectNaming(displayName),
            on: &openProjects[idx].document
        )
        openProjects[idx].document.modified = Date()
        publishOpenProjects()
        canSave = true
        regeneratePlan()
    }

    /// Inspector subtitle after file count — paired master PostScript prefix when set.
    func projectNamingSubtitle(for openProject: OpenProject) -> String {
        let prefix = masterFamilyPSPrefix(for: openProject.id)
        if !prefix.isEmpty { return prefix }
        if let name = openProject.document.displayName, !name.isEmpty { return name }
        return openProject.document.familyLabel
    }

    func masterFamilyPSPrefix(for projectID: String) -> String {
        guard let masterID = masterFontID(for: projectID),
              let font = font(forProjectID: projectID, fontID: masterID) else { return "" }
        return font.options.familyPSPrefix ?? ""
    }

    func projectTabLabel(for openProject: OpenProject) -> String {
        if let url = openProject.projectFileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        if let name = openProject.document.displayName, !name.isEmpty {
            return name
        }
        if !openProject.document.familyLabel.isEmpty {
            return openProject.document.familyLabel
        }
        if let first = openProject.document.fonts.first {
            return fontBasename(for: first)
        }
        return "Project"
    }

    func fontBasename(for font: FontDocument) -> String {
        URL(fileURLWithPath: font.sourcePath).deletingPathExtension().lastPathComponent
    }

    func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func instanceCountLabel(for font: FontDocument) -> String {
        guard activeProjectID != nil,
              let project,
              project.fonts.contains(where: { $0.id == font.id }) else { return "—" }
        if font.id == selectedFontID, let plan = instancePlan {
            return "\(plan.formula.totalGenerated)"
        }
        let estimate = font.axes.filter { $0.role == .instance }.map(\.values.count).reduce(1, *)
        return "~\(estimate)"
    }

    func isFontDirty(fontID: String) -> Bool {
        project?.fonts.first { $0.id == fontID }?.dirty ?? false
    }

    func clarifierSlotState(category: FileClarifierCategory, for fontID: String) -> ClarifierSlotState {
        guard let font = project?.fonts.first(where: { $0.id == fontID }) else {
            return .editable
        }
        let count = project?.fonts.count ?? 1
        return ClarifierSlotCoverage.slotState(category: category, font: font, projectFontCount: count)
    }

    func hasEditableClarifierSlots(for fontID: String) -> Bool {
        guard let font = project?.fonts.first(where: { $0.id == fontID }) else { return false }
        let count = project?.fonts.count ?? 1
        if ClarifierSlotCoverage.isMultiFileMaster(font: font, projectFontCount: count) {
            return false
        }
        if ClarifierSlotCoverage.hasEditableInferSlots(font: font, projectFontCount: count) {
            return true
        }
        // Allow Infer to fill an empty PostScript prefix even when clarifier slots are covered.
        let prefix = font.options.familyPSPrefix?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return prefix.isEmpty
    }

    func requestRemoveFont(projectID: String, fontID: String) {
        guard openProjects.contains(where: { $0.id == projectID }),
              openProjects.first(where: { $0.id == projectID })?
                .document.fonts.contains(where: { $0.id == fontID }) == true else { return }
        workspace.confirmRemoveFont = FontRemovalRequest(projectID: projectID, fontID: fontID)
    }

    func confirmRemoveFontAction() {
        guard let request = workspace.confirmRemoveFont else { return }
        workspace.confirmRemoveFont = nil
        removeFont(id: request.fontID, fromProjectID: request.projectID)
    }

    func removeFont(id fontID: String, fromProjectID projectID: String) {
        guard let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }
        let removedWasMaster = masterFontID(for: projectID) == fontID
        openProjects[pIdx].document.fonts.removeAll { $0.id == fontID }
        removeSourceBookmark(fontID: fontID)

        if openProjects[pIdx].document.fonts.isEmpty {
            closeProject(id: projectID, force: true)
            postStatusMessage("Project closed — no files remaining")
            return
        }

        if removedWasMaster {
            promoteFirstFontToMaster(projectIndex: pIdx)
        }

        if openProjects[pIdx].selectedFontID == fontID {
            openProjects[pIdx].selectedFontID = openProjects[pIdx].document.fonts.first?.id
        }

        activateProject(id: projectID)
        markProjectFileDirty(projectID: projectID)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
        postStatusMessage("Removed font from project")
    }

    func isMasterFont(fontID: String, projectID: String) -> Bool {
        masterFontID(for: projectID) == fontID
    }

    func reorderFont(draggedID: String, before anchorID: String, projectID: String) {
        guard draggedID != anchorID,
              let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }
        var fonts = openProjects[pIdx].document.fonts
        guard let fromIndex = fonts.firstIndex(where: { $0.id == draggedID }),
              let anchorIndex = fonts.firstIndex(where: { $0.id == anchorID }) else { return }
        let insertIndex = fromIndex < anchorIndex ? anchorIndex - 1 : anchorIndex
        guard fromIndex != insertIndex else { return }

        pushUndoSnapshot()
        let item = fonts.remove(at: fromIndex)
        fonts.insert(item, at: insertIndex)
        openProjects[pIdx].document.fonts = fonts
        openProjects[pIdx].document.modified = Date()
        promoteFirstFontToMaster(projectIndex: pIdx)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
    }

    func moveFontToEnd(draggedID: String, projectID: String) {
        guard let pIdx = openProjects.firstIndex(where: { $0.id == projectID }) else { return }
        var fonts = openProjects[pIdx].document.fonts
        guard let fromIndex = fonts.firstIndex(where: { $0.id == draggedID }),
              fromIndex < fonts.count - 1 else { return }

        pushUndoSnapshot()
        let item = fonts.remove(at: fromIndex)
        fonts.append(item)
        openProjects[pIdx].document.fonts = fonts
        openProjects[pIdx].document.modified = Date()
        promoteFirstFontToMaster(projectIndex: pIdx)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
    }

    func presentMoveFontPicker(fontID: String, fromProjectID: String) {
        workspace.projectTargetPickerMode = .moveFont(fontID: fontID, fromProjectID: fromProjectID)
    }

    func presentCombineProjectsPicker(into targetProjectID: String) {
        workspace.projectTargetPickerMode = .combineInto(targetProjectID: targetProjectID)
    }

    func cancelProjectTargetPicker() {
        workspace.projectTargetPickerMode = nil
    }

    func completeProjectTargetPicker(selectedProjectID: String) {
        guard let mode = workspace.projectTargetPickerMode else { return }
        workspace.projectTargetPickerMode = nil
        switch mode {
        case let .moveFont(fontID, fromProjectID):
            requestMoveFont(fontID: fontID, fromProjectID: fromProjectID, toProjectID: selectedProjectID)
        case let .combineInto(targetProjectID):
            requestCombineProjects(sourceID: selectedProjectID, intoTargetID: targetProjectID)
        }
    }

    func requestMoveFont(fontID: String, fromProjectID: String, toProjectID: String) {
        guard fromProjectID != toProjectID,
              let fromIdx = openProjects.firstIndex(where: { $0.id == fromProjectID }),
              openProjects[fromIdx].document.fonts.contains(where: { $0.id == fontID }) else { return }

        workspace.confirmMoveFont = FontMoveRequest(
            fontID: fontID,
            fromProjectID: fromProjectID,
            toProjectID: toProjectID
        )
    }

    func confirmMoveFontAction() {
        guard let request = workspace.confirmMoveFont else { return }
        workspace.confirmMoveFont = nil
        moveFont(
            fontID: request.fontID,
            fromProjectID: request.fromProjectID,
            toProjectID: request.toProjectID
        )
    }

    func moveFont(fontID: String, fromProjectID: String, toProjectID: String) {
        guard fromProjectID != toProjectID,
              let fromIdx = openProjects.firstIndex(where: { $0.id == fromProjectID }),
              let toIdx = openProjects.firstIndex(where: { $0.id == toProjectID }),
              let fontIdx = openProjects[fromIdx].document.fonts.firstIndex(where: { $0.id == fontID }) else { return }

        let font = openProjects[fromIdx].document.fonts[fontIdx]
        let normalizedPath = Self.normalizedPath(URL(fileURLWithPath: font.sourcePath))
        if openProjects[toIdx].document.fonts.contains(where: {
            Self.normalizedPath(URL(fileURLWithPath: $0.sourcePath)) == normalizedPath
        }) {
            postStatusMessage("Already in target project — \(fontBasename(for: font))")
            return
        }

        openProjects[fromIdx].document.fonts.remove(at: fontIdx)
        mergeNamingOrder(for: font, intoProjectAt: toIdx)
        openProjects[toIdx].document.fonts.append(font)
        openProjects[toIdx].document.modified = Date()

        if openProjects[fromIdx].document.fonts.isEmpty {
            closeProject(id: fromProjectID, force: true)
        } else if openProjects[fromIdx].selectedFontID == fontID {
            openProjects[fromIdx].selectedFontID = openProjects[fromIdx].document.fonts.first?.id
        }

        activateProject(id: toProjectID)
        selectFont(id: fontID)
        markProjectFileDirty(projectID: fromProjectID)
        markProjectFileDirty(projectID: toProjectID)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
        postStatusMessage("Moved \(fontBasename(for: font))")
    }

    func requestSplitFontToNewProject(fontID: String, fromProjectID: String) {
        guard canSplitFont(fontID: fontID, fromProjectID: fromProjectID) else { return }
        workspace.confirmSplitFont = FontSplitRequest(fontID: fontID, fromProjectID: fromProjectID)
    }

    func confirmSplitFontAction() {
        guard let request = workspace.confirmSplitFont else { return }
        workspace.confirmSplitFont = nil
        splitFontToNewProject(fontID: request.fontID, fromProjectID: request.fromProjectID)
    }

    func splitFontToNewProject(fontID: String, fromProjectID: String) {
        guard canSplitFont(fontID: fontID, fromProjectID: fromProjectID),
              let fromIdx = openProjects.firstIndex(where: { $0.id == fromProjectID }),
              let fontIdx = openProjects[fromIdx].document.fonts.firstIndex(where: { $0.id == fontID }) else { return }

        let sourceDoc = openProjects[fromIdx].document
        let font = openProjects[fromIdx].document.fonts.remove(at: fontIdx)

        var naming = sourceDoc.naming
        naming.order = Self.mergedNamingOrder(
            projectOrder: naming.order,
            axisTags: font.axes.map(\.tag)
        )

        let newDocument = ProjectDocument(
            schemaVersion: sourceDoc.schemaVersion,
            created: Date(),
            modified: Date(),
            familyLabel: sourceDoc.familyLabel,
            displayName: nil,
            naming: naming,
            template: sourceDoc.template,
            fonts: [font]
        )

        let newOpen = OpenProject(
            document: newDocument,
            selectedFontID: font.id,
            projectFileURL: nil,
            projectFileDirty: true
        )
        openProjects.append(newOpen)

        if openProjects[fromIdx].selectedFontID == fontID {
            openProjects[fromIdx].selectedFontID = openProjects[fromIdx].document.fonts.first?.id
        }
        openProjects[fromIdx].document.modified = Date()
        markProjectFileDirty(projectID: fromProjectID)

        activateProject(id: newOpen.id)
        selectFont(id: font.id)
        publishOpenProjects()
        refreshCanSave()
        regeneratePlan()
        postStatusMessage("Moved \(fontBasename(for: font)) to new project")
    }

    func requestCombineProjects(sourceID: String, intoTargetID targetID: String) {
        guard sourceID != targetID,
              openProjects.contains(where: { $0.id == sourceID }),
              openProjects.contains(where: { $0.id == targetID }) else { return }

        workspace.confirmCombineProjects = ProjectCombineRequest(
            sourceProjectID: sourceID,
            targetProjectID: targetID
        )
    }

    func confirmCombineProjectsAction() {
        guard let request = workspace.confirmCombineProjects else { return }
        workspace.confirmCombineProjects = nil
        combineProjects(sourceID: request.sourceProjectID, intoTargetID: request.targetProjectID)
    }

    func combineProjects(sourceID: String, intoTargetID targetID: String) {
        guard sourceID != targetID,
              let sourceIdx = openProjects.firstIndex(where: { $0.id == sourceID }),
              let targetIdx = openProjects.firstIndex(where: { $0.id == targetID }) else { return }

        let sourceFonts = openProjects[sourceIdx].document.fonts
        var movedCount = 0
        var skippedCount = 0
        var firstMovedFontID: String?

        for font in sourceFonts {
            let normalizedPath = Self.normalizedPath(URL(fileURLWithPath: font.sourcePath))
            if openProjects[targetIdx].document.fonts.contains(where: {
                Self.normalizedPath(URL(fileURLWithPath: $0.sourcePath)) == normalizedPath
            }) {
                skippedCount += 1
                continue
            }

            mergeNamingOrder(for: font, intoProjectAt: targetIdx)
            openProjects[targetIdx].document.fonts.append(font)
            if firstMovedFontID == nil {
                firstMovedFontID = font.id
            }
            movedCount += 1
        }

        openProjects[targetIdx].document.modified = Date()
        markProjectFileDirty(projectID: targetID)
        closeProject(id: sourceID, force: true)

        if movedCount > 0 {
            activateProject(id: targetID)
            if let firstMovedFontID {
                selectFont(id: firstMovedFontID)
            }
            publishOpenProjects()
            refreshCanSave()
            regeneratePlan()
        }

        if movedCount > 0, skippedCount > 0 {
            postStatusMessage(
                "Combined \(movedCount) file\(movedCount == 1 ? "" : "s"); skipped \(skippedCount) duplicate\(skippedCount == 1 ? "" : "s")"
            )
        } else if movedCount > 0 {
            postStatusMessage("Combined \(movedCount) file\(movedCount == 1 ? "" : "s") into project")
        } else {
            postStatusMessage("Nothing to combine — all files already in project")
        }
    }

    func mergeNamingOrder(for font: FontDocument, intoProjectAt projectIndex: Int) {
        openProjects[projectIndex].document.naming.order = Self.mergedNamingOrder(
            projectOrder: openProjects[projectIndex].document.naming.order,
            axisTags: font.axes.map(\.tag)
        )
    }

    func requestCloseProject(id: String) {
        guard openProjects.contains(where: { $0.id == id }) else { return }
        if projectNeedsCloseConfirmation(projectID: id) {
            workspace.confirmCloseProjectID = id
            return
        }
        closeProject(id: id, force: true)
    }

    func projectNeedsCloseConfirmation(projectID: String) -> Bool {
        // Only the .varf project file gates close/quit. Font `dirty` means “needs Export”,
        // which is optional and must not block discarding the in-memory workspace.
        projectNeedsProjectFileSave(projectID: projectID)
    }

    func firstProjectNeedingCloseConfirmation() -> String? {
        openProjects.first(where: { projectNeedsCloseConfirmation(projectID: $0.id) })?.id
    }

    func confirmCloseProjectDiscardAction() {
        guard let id = workspace.confirmCloseProjectID else { return }
        workspace.confirmCloseProjectID = nil
        closeProject(id: id, force: true)
    }

    func confirmCloseProjectSaveAction() {
        guard let projectID = workspace.confirmCloseProjectID,
              let open = openProject(for: projectID) else { return }
        if let url = open.projectFileURL {
            Task { @MainActor in
                await self.saveProject(document: open.document, to: url, projectID: projectID)
                if self.openProject(for: projectID)?.projectFileDirty == false {
                    self.workspace.confirmCloseProjectID = nil
                    self.closeProject(id: projectID, force: true)
                }
            }
        } else {
            workspace.confirmCloseProjectID = projectID
            presentSaveProjectAsPanelForClose(projectID: projectID)
        }
    }

    func presentSaveProjectAsPanelForClose(projectID: String) {
        guard let open = openProject(for: projectID) else { return }
        let panel = NSSavePanel()
        panel.title = "Save Project Before Closing"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.varfontProject]
        panel.nameFieldStringValue = defaultProjectFilename(for: open)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let normalized = Self.normalizedProjectFileURL(url)
            Task { @MainActor in
                await self?.saveProject(document: open.document, to: normalized, projectID: projectID)
                if self?.openProject(for: projectID)?.projectFileDirty == false {
                    self?.workspace.confirmCloseProjectID = nil
                    self?.closeProject(id: projectID, force: true)
                }
            }
        }
    }

    func confirmCloseProjectAction() {
        confirmCloseProjectDiscardAction()
    }

    func closeProject(id: String, force: Bool) {
        guard let idx = openProjects.firstIndex(where: { $0.id == id }) else { return }
        if !force, projectNeedsCloseConfirmation(projectID: id) {
            workspace.confirmCloseProjectID = id
            return
        }

        for font in openProjects[idx].document.fonts {
            removeSourceBookmark(fontID: font.id)
        }
        openProjects.remove(at: idx)
        clearSaveReviewState(forProjectID: id)

        if openProjects.isEmpty {
            activeProjectID = nil
            selectedFontID = nil
            instancePlan = nil
            instanceListDisplay = .empty
            canSave = false
            return
        }

        if activeProjectID == id {
            let neighborIndex = min(idx, openProjects.count - 1)
            activeProjectID = openProjects[neighborIndex].id
        }

        selectedInstanceKey = nil
        selectedInstanceKeys = []
        selectedAxisStopID = nil
        refreshCanSave()
        regeneratePlan()
    }

    func revealActiveFontInFinder() {
        guard let path = selectedFont?.sourcePath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    func revealFontInFinder(fontID: String, projectID: String) {
        guard let project = openProjects.first(where: { $0.id == projectID }),
              let font = project.document.fonts.first(where: { $0.id == fontID }) else { return }
        NSWorkspace.shared.selectFile(font.sourcePath, inFileViewerRootedAtPath: "")
    }

    func removeFontConfirmationMessage(for request: FontRemovalRequest) -> String {
        guard let font = fontDocument(fontID: request.fontID, projectID: request.projectID) else {
            return "Remove this file from the project?"
        }
        let name = fontBasename(for: font)
        return "Remove \(name) from this project?"
    }

    func moveFontConfirmationMessage(for request: FontMoveRequest) -> String {
        guard let font = fontDocument(fontID: request.fontID, projectID: request.fromProjectID),
              let target = openProjects.first(where: { $0.id == request.toProjectID }) else {
            return "Move this file to another project?"
        }
        let name = fontBasename(for: font)
        let targetName = projectTabLabel(for: target)
        return "Move \(name) into \(targetName)?"
    }

    func splitFontConfirmationMessage(for request: FontSplitRequest) -> String {
        guard let font = fontDocument(fontID: request.fontID, projectID: request.fromProjectID) else {
            return "Move this file to a new project?"
        }
        let name = fontBasename(for: font)
        return "Move \(name) to a new project?"
    }

    func combineProjectsConfirmationMessage(for request: ProjectCombineRequest) -> String {
        guard let source = openProjects.first(where: { $0.id == request.sourceProjectID }),
              let target = openProjects.first(where: { $0.id == request.targetProjectID }) else {
            return "Combine these projects?"
        }
        let sourceName = projectTabLabel(for: source)
        let targetName = projectTabLabel(for: target)
        let fileCount = source.document.fonts.count
        let filePhrase = "\(fileCount) file\(fileCount == 1 ? "" : "s")"
        return "Move \(filePhrase) from \(sourceName) into \(targetName) and close \(sourceName)?"
    }

    func closeProjectConfirmationMessage(for projectID: String) -> String {
        guard let project = openProjects.first(where: { $0.id == projectID }) else {
            return "Close this project?"
        }
        let name = projectTabLabel(for: project)
        if projectNeedsProjectFileSave(projectID: projectID) {
            return "Close \(name)? The project file has unsaved changes."
        }
        return "Close \(name)?"
    }

    func fontDocument(fontID: String, projectID: String) -> FontDocument? {
        openProjects.first(where: { $0.id == projectID })?
            .document.fonts.first(where: { $0.id == fontID })
    }

    func importDroppedFonts(_ urls: [URL], target: WorkspaceDropTarget) async {
        // Dragged Finder URLs are security-scoped; start access before existence checks.
        let scopedAccess = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer {
            for (url, accessing) in scopedAccess where accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let projectURLs = Self.collectProjectURLs(from: urls).filter { url in
            let path = url.path
            return !path.contains("/TemporaryItems/") && !path.contains("/VarFontDrop/")
        }
        if projectURLs.isEmpty,
           urls.contains(where: { Self.isProjectFile($0) }) {
            postStatusMessage("Couldn't open that project drop — use File → Open Project…")
        }
        for projectURL in projectURLs {
            await openProjectFile(at: projectURL)
        }

        let valid = Self.collectFontURLs(from: urls)
        guard !valid.isEmpty else {
            if projectURLs.isEmpty {
                postStatusMessage("No supported font or project files")
            }
            return
        }

        switch target {
        case .newProject:
            await createProjectWithFonts(valid)
        case .project(let projectID):
            for url in valid {
                await addFont(at: url, toProjectID: projectID, selectAfterAdd: false)
            }
            selectMasterFont(for: projectID)
        case .reorderFont, .reorderFontEnd:
            break
        }
    }

    /// First font opens the project tab; remaining fonts are added to it.
    func createProjectWithFonts(_ urls: [URL]) async {
        guard let first = urls.first else { return }
        await createProject(from: first)
        guard let projectID = activeProjectID else { return }
        for url in urls.dropFirst() {
            await addFont(at: url, toProjectID: projectID, selectAfterAdd: false)
        }
        selectMasterFont(for: projectID)
    }

    func suggestsSameFamily(analysis: FontAnalysis, project: ProjectDocument) -> Bool {
        let family = analysis.source.familyName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let label = project.familyLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !family.isEmpty, !label.isEmpty else { return false }
        return label.contains(family) || family.contains(label)
    }

    func suggestedDropProjectID(for analysis: FontAnalysis) -> String? {
        guard let activeProjectID,
              let active = openProjects.first(where: { $0.id == activeProjectID }),
              suggestsSameFamily(analysis: analysis, project: active.document) else {
            return openProjects.first?.id
        }
        return activeProjectID
    }

}
