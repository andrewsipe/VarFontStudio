import AppKit
import Foundation
import UniformTypeIdentifiers
import VarFontCore

extension EditorViewModel {
    // MARK: - Export / font write path

    func saveCopy() {
        refreshCommitDiffPreview(presentSheet: true)
    }

    func requestSaveToOriginal() {
        guard canSave else {
            postStatusMessage("Nothing to export — make an edit first.")
            return
        }
        Task {
            guard let projectID = activeProjectID, let fontID = selectedFontID else { return }
            guard let session = await ensureSaveReviewSession(projectID: projectID, fontID: fontID) else { return }
            guard session.preflight.ok else {
                postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return
            }
            saveReview.confirmSaveToOriginal = session
        }
    }

    func confirmSaveToOriginalAction() {
        guard let session = saveReview.confirmSaveToOriginal,
              let font = font(forProjectID: session.projectID, fontID: session.fontID) else { return }
        saveReview.confirmSaveToOriginal = nil
        Task {
            await performSave(
                session: session,
                to: URL(fileURLWithPath: font.sourcePath),
                inPlace: true
            )
        }
    }

    func saveToOriginalConfirmationMessage(for session: CommitPreflightSession) -> String {
        guard let font = font(forProjectID: session.projectID, fontID: session.fontID) else {
            return "Overwrite the original font file? This cannot be undone."
        }
        return "Overwrite \(URL(fileURLWithPath: font.sourcePath).lastPathComponent)? A .vfstudio-backup copy is written beside the original first."
    }

    /// User-facing: Export — write to `font.outputPath` when set; otherwise open Review (same as Export…).
    func save() {
        guard canSave else {
            postStatusMessage("Nothing to export — make an edit first.")
            return
        }
        Task {
            await saveActiveFontUsingRememberedPathOrReview()
        }
    }

    func canSaveToRememberedPath(forProjectID projectID: String, fontID: String) -> Bool {
        rememberedOutputURL(forProjectID: projectID, fontID: fontID) != nil
    }

    var canSaveToRememberedPathForSelection: Bool {
        guard let projectID = activeProjectID, let fontID = selectedFontID else { return false }
        return canSaveToRememberedPath(forProjectID: projectID, fontID: fontID)
    }

    func savedOutputLabel(for font: FontDocument) -> String? {
        guard let outputPath = font.outputPath else { return nil }
        return URL(fileURLWithPath: outputPath).lastPathComponent
    }

    private func rememberedOutputURL(forProjectID projectID: String, fontID: String) -> URL? {
        guard let font = font(forProjectID: projectID, fontID: fontID),
              let path = font.outputPath else { return nil }
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        let parent = url.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return url
    }

    @MainActor
    private func saveActiveFontUsingRememberedPathOrReview() async {
        guard let projectID = activeProjectID, let fontID = selectedFontID else { return }

        if let outputURL = rememberedOutputURL(forProjectID: projectID, fontID: fontID),
           let font = font(forProjectID: projectID, fontID: fontID) {
            guard let session = await ensureSaveReviewSession(projectID: projectID, fontID: fontID) else { return }
            guard session.preflight.ok else {
                postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return
            }
            if Self.normalizedPath(outputURL) == Self.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                saveReview.confirmSaveToOriginal = session
                return
            }
            await performSave(session: session, to: outputURL)
            return
        }

        saveCopy()
    }

    @MainActor
    func ensureSaveReviewSession(
        projectID: String,
        fontID: String,
        preferWorker: Bool = true
    ) async -> CommitPreflightSession? {
        if let session = saveReviewSession(forProjectID: projectID, fontID: fontID),
           session.preflight.ok {
            return session
        }
        return await refreshCommitDiffPreviewAsync(
            forProjectID: projectID,
            fontID: fontID,
            preferWorker: preferWorker
        )
    }

    @discardableResult
    @MainActor
    func refreshCommitDiffPreviewAsync(
        forProjectID projectID: String? = nil,
        fontID: String? = nil,
        presentSheet: Bool = false,
        preferWorker: Bool = true
    ) async -> CommitPreflightSession? {
        let targetProjectID = projectID ?? activeProjectID
        guard let targetProjectID,
              let open = openProject(for: targetProjectID) else {
            if presentSheet {
                postStatusMessage("Nothing to save — open a font first.")
            }
            return nil
        }

        let targetFontID = fontID
            ?? saveReviewSelectedFontID(forProjectID: targetProjectID)
            ?? open.selectedFontID
        guard let targetFontID,
              let font = open.document.fonts.first(where: { $0.id == targetFontID }),
              let plan = instancePlan(forProjectID: targetProjectID, fontID: targetFontID) else {
            if presentSheet {
                postStatusMessage("Nothing to save — open a font first.")
            }
            return nil
        }

        let projectDoc = open.document

        let duplicateIncluded = plan.instances.filter { $0.included && $0.duplicate }
        if !duplicateIncluded.isEmpty {
            postStatusMessage("Resolve duplicate instance names before saving.")
            return nil
        }

        guard FileManager.default.fileExists(atPath: font.sourcePath) else {
            postStatusMessage("Source font file is missing — re-open the original file.")
            return nil
        }

        let bookmark = sourceBookmarks[font.id]
        let outputPath = font.outputPath ?? CommitRequestBuilder.suggestedOutputPath(for: font.sourcePath)
        var dryRunRequest = CommitRequestBuilder.make(
            font: font,
            naming: projectDoc.naming,
            plan: plan,
            outputPath: outputPath,
            dryRun: true,
            nameidStrategy: projectDoc.nameidStrategy
        )

        saveReview.beginLoading(projectID: targetProjectID, fontID: targetFontID)
        defer { saveReview.endLoading(projectID: targetProjectID, fontID: targetFontID) }

        do {
            let analysis = try SourceFontAccess.withReadableSourceURL(
                bookmark: bookmark,
                fallbackPath: font.sourcePath
            ) { sourceURL in
                try FontAnalysisReader.analyzeForCommitDiff(url: sourceURL)
            }
            let helperSourcePath = try SourceFontAccess.helperSourcePath(
                bookmark: bookmark,
                fallbackPath: font.sourcePath,
                fontID: font.id
            )
            dryRunRequest.sourcePath = helperSourcePath
            let result = try await commitService.commit(dryRunRequest, preferWorker: preferWorker)
            if result.ok {
                let diffReport = CommitDiffBuilder.build(
                    analysis: analysis,
                    font: font,
                    plan: plan,
                    result: result
                )
                let presentation = SaveReviewPresentationBuilder.build(
                    analysis: analysis,
                    font: font,
                    plan: plan,
                    report: diffReport,
                    diff: result.diff
                )
                var writeRequest = CommitRequestBuilder.make(
                    font: font,
                    naming: projectDoc.naming,
                    plan: plan,
                    outputPath: outputPath,
                    dryRun: false,
                    nameidStrategy: projectDoc.nameidStrategy
                )
                writeRequest.sourcePath = helperSourcePath
                let session = CommitPreflightSession(
                    projectID: targetProjectID,
                    fontID: font.id,
                    dryRunRequest: dryRunRequest,
                    baseRequest: writeRequest,
                    preflight: result,
                    diffReport: diffReport,
                    presentation: presentation,
                    informationalNotes: OpenTypeAxisAudit.allInformationalMessages(
                        analysis: analysis,
                        font: font
                    )
                )
                saveReview.storeSession(session, projectID: targetProjectID, fontID: font.id)
                if presentSheet {
                    saveReview.presentSheet()
                }
                return session
            }
            let message = result.errors.first?.message ?? "Export preview failed. Check the Review window for details."
            var writeRequest = CommitRequestBuilder.make(
                font: font,
                naming: projectDoc.naming,
                plan: plan,
                outputPath: outputPath,
                dryRun: false,
                nameidStrategy: projectDoc.nameidStrategy
            )
            writeRequest.sourcePath = dryRunRequest.sourcePath
            let failedSession = CommitPreflightSession(
                projectID: targetProjectID,
                fontID: font.id,
                dryRunRequest: dryRunRequest,
                baseRequest: writeRequest,
                preflight: result,
                diffReport: CommitDiffBuilder.empty,
                presentation: .empty,
                informationalNotes: []
            )
            saveReview.storeSession(failedSession, projectID: targetProjectID, fontID: font.id)
            postStatusMessage(message)
            if presentSheet {
                saveReview.presentSheet()
            }
            return failedSession
        } catch {
            postSaveFailure(commitFailureMessage(error))
            return nil
        }
    }

    func dismissCommitDiffSheet() {
        saveReview.dismissSheet()
    }

    /// Re-read the source font and run vfcommit dry-run to build the save review diff.
    func refreshCommitDiffPreview(
        forProjectID projectID: String? = nil,
        fontID: String? = nil,
        presentSheet: Bool = false
    ) {
        Task {
            await refreshCommitDiffPreviewAsync(
                forProjectID: projectID,
                fontID: fontID,
                presentSheet: presentSheet
            )
        }
    }

    func exportCommitJSON(session: CommitPreflightSession) {
        let panel = NSOpenPanel()
        panel.title = "Export Commit JSON"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        panel.message = "Choose a folder for CommitRequest, CommitResult, and CommitDiffReport JSON files."

        panel.begin { [weak self] response in
            guard response == .OK, let directory = panel.url else { return }
            Task { @MainActor in
                self?.writeCommitJSON(session: session, to: directory)
            }
        }
    }

    private func writeCommitJSON(session: CommitPreflightSession, to directory: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")

        do {
            try encoder.encode(session.dryRunRequest).write(
                to: directory.appendingPathComponent("\(stamp)-commit-request.json")
            )
            try encoder.encode(session.preflight).write(
                to: directory.appendingPathComponent("\(stamp)-commit-result.json")
            )
            try encoder.encode(session.diffReport).write(
                to: directory.appendingPathComponent("\(stamp)-commit-diff-report.json")
            )
            postStatusMessage("Exported save plan to \(directory.lastPathComponent)")
        } catch {
            postStatusMessage("JSON export failed: \(error.localizedDescription)")
        }
    }

    func presentSavePanel(for session: CommitPreflightSession) {
        guard let font = font(forProjectID: session.projectID, fontID: session.fontID) else { return }

        let panel = NSSavePanel()
        panel.title = "Export Font"
        panel.canCreateDirectories = true
        // Suggest -patched beside the source so same-folder export doesn't collide with the original.
        // User can rename or pick another folder; macOS warns if the chosen name already exists.
        let suggested = CommitRequestBuilder.suggestedOutputPath(for: font.sourcePath)
        let suggestedURL = URL(fileURLWithPath: suggested)
        panel.nameFieldStringValue = suggestedURL.lastPathComponent
        let sourceURL = URL(fileURLWithPath: font.sourcePath)
        panel.directoryURL = sourceURL.deletingLastPathComponent()
        let ext = sourceURL.pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [type]
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let normalizedOutput = Self.normalizedPath(url)
            let normalizedSource = Self.normalizedPath(URL(fileURLWithPath: font.sourcePath))
            if normalizedOutput == normalizedSource {
                self?.saveReview.confirmSaveToOriginal = session
                return
            }
            Task { @MainActor in
                await self?.performSave(session: session, to: url)
            }
        }
    }

    func save(session: CommitPreflightSession) {
        Task {
            await save(session: session, usingRememberedPath: true)
        }
    }

    @MainActor
    private func save(session: CommitPreflightSession, usingRememberedPath: Bool) async {
        guard session.preflight.ok else {
            postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
            return
        }

        if usingRememberedPath,
           let url = rememberedOutputURL(forProjectID: session.projectID, fontID: session.fontID),
           let font = font(forProjectID: session.projectID, fontID: session.fontID) {
            if Self.normalizedPath(url) == Self.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                saveReview.confirmSaveToOriginal = session
                return
            }
            await performSave(session: session, to: url)
            return
        }

        presentSavePanel(for: session)
    }

    func saveAllFiles(inProjectID projectID: String? = nil) {
        Task {
            await saveAllFilesAsync(inProjectID: projectID)
        }
    }

    @MainActor
    private func saveAllFilesAsync(inProjectID projectID: String? = nil) async {
        guard let projectID = projectID ?? activeProjectID,
              let open = openProject(for: projectID) else { return }

        let fontsToWrite = open.document.fonts.filter(\.dirty)
        let targets = fontsToWrite.isEmpty ? open.document.fonts : fontsToWrite
        guard !targets.isEmpty else {
            postStatusMessage("Nothing to export.")
            return
        }

        for font in targets {
            guard let plan = instancePlan(forProjectID: projectID, fontID: font.id) else {
                postStatusMessage("Couldn't prepare the export preview. Try again, or check that the font file hasn't moved or changed.")
                return
            }
            if plan.instances.contains(where: { $0.included && $0.duplicate }) {
                postStatusMessage("Resolve duplicate instance names in \(fontBasename(for: font)) before saving.")
                return
            }
        }

        var sessions: [String: CommitPreflightSession] = [:]
        await withTaskGroup(of: (String, CommitPreflightSession?).self) { group in
            for font in targets {
                let fontID = font.id
                group.addTask { @MainActor in
                    let session = await self.ensureSaveReviewSession(
                        projectID: projectID,
                        fontID: fontID,
                        preferWorker: false
                    )
                    return (fontID, session)
                }
            }
            for await (fontID, session) in group {
                sessions[fontID] = session
            }
        }

        for font in targets {
            guard let session = sessions[font.id] else {
                postStatusMessage("Export preview failed for \(fontBasename(for: font)). Check the Review window for details.")
                return
            }
            guard session.preflight.ok else {
                postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return
            }
        }

        var outputURLs: [String: URL] = [:]
        for font in targets {
            if let url = rememberedOutputURL(forProjectID: projectID, fontID: font.id) {
                if url.path == font.sourcePath {
                    postStatusMessage("Export All cannot overwrite originals — use Export to Original… per file.")
                    return
                }
                outputURLs[font.id] = url
            }
        }

        var outputDirectory: URL?
        if targets.contains(where: { outputURLs[$0.id] == nil }) {
            guard let directory = await chooseOutputDirectory(
                title: "Export Fonts",
                message: "Choose a folder. Fonts keep their original filenames."
            ) else { return }
            outputDirectory = directory
            for font in targets where outputURLs[font.id] == nil {
                outputURLs[font.id] = URL(
                    fileURLWithPath: CommitRequestBuilder.packageOutputPath(
                        for: font.sourcePath,
                        in: directory
                    )
                )
            }
        }

        for font in targets {
            guard let url = outputURLs[font.id] else { continue }
            if Self.normalizedPath(url) == Self.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                postStatusMessage("Export All cannot overwrite originals — use Export to Original… per file.")
                return
            }
        }

        isBusy = true
        defer { isBusy = false }

        for font in targets {
            guard let session = sessions[font.id], let url = outputURLs[font.id] else { continue }
            await performSave(session: session, to: url, manageBusyState: false)
        }

        let folderLabel = outputDirectory?.lastPathComponent
            ?? outputURLs.values.first?.deletingLastPathComponent().lastPathComponent
            ?? "output folder"
        postStatusMessage("Exported \(targets.count) fonts to \(folderLabel)")
    }

    private func chooseOutputDirectory(title: String, message: String) async -> URL? {
        await withCheckedContinuation { continuation in
            let panel = NSOpenPanel()
            panel.title = title
            panel.message = message
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Choose Folder"
            panel.begin { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    var isSaveActionBlocked: Bool {
        if isBusy { return true }
        guard let projectID = activeProjectID else { return false }
        return isSaveReviewLoading(forProjectID: projectID)
    }

    func performSave(
        session: CommitPreflightSession,
        to outputURL: URL,
        inPlace: Bool = false,
        manageBusyState: Bool = true
    ) async {
        guard let projectIndex = openProjects.firstIndex(where: { $0.id == session.projectID }),
              let fontIndex = openProjects[projectIndex].document.fonts.firstIndex(where: { $0.id == session.fontID }) else {
            return
        }

        let originalSourcePath = openProjects[projectIndex].document.fonts[fontIndex].sourcePath
        guard FileManager.default.fileExists(atPath: originalSourcePath) else {
            postStatusMessage("Source font file is missing — re-open the original file.")
            return
        }

        var request = session.baseRequest
        request.outputPath = outputURL.path
        request.originalSourcePath = originalSourcePath
        request.allowInPlace = inPlace
        request.dryRun = false
        request.requestID = UUID().uuidString.lowercased()

        if manageBusyState { isBusy = true }
        defer { if manageBusyState { isBusy = false } }

        do {
            let result = try await commitService.commit(request)
            guard result.ok else {
                let message = result.errors.first?.message ?? "Export failed."
                postStatusMessage(message)
                return
            }

            var project = openProjects[projectIndex].document
            if inPlace {
                SourceFontAccess.invalidateCache(fontID: session.fontID)
                let sourceURL = URL(fileURLWithPath: originalSourcePath)
                registerSourceBookmark(url: sourceURL, fontID: session.fontID)
                project.fonts[fontIndex].outputPath = originalSourcePath
            } else {
                project.fonts[fontIndex].outputPath = outputURL.path
            }
            project.fonts[fontIndex].dirty = false
            openProjects[projectIndex].document = project
            publishOpenProjects()
            if activeProjectID == session.projectID {
                self.project = project
                refreshCanSave()
            }
            clearSaveReviewState(forProjectID: session.projectID, fontID: session.fontID)
            saveReview.dismissSheet()

            if inPlace {
                let backupName = URL(fileURLWithPath: originalSourcePath).lastPathComponent + ".vfstudio-backup"
                postStatusMessage("Saved to original (backup: \(backupName))")
            } else if let count = result.summary?.instancesWritten {
                postStatusMessage("Saved \(count) instances to \(outputURL.lastPathComponent)")
            } else {
                postStatusMessage("Saved \(outputURL.lastPathComponent)")
            }
        } catch {
            postSaveFailure(commitFailureMessage(error))
        }
    }

    private func commitFailureMessage(_ error: Error) -> String {
        let userFacingSaveEngineMessage = "Couldn't write the font — the save engine isn't installed. Reinstall VarFont Studio."
        switch error {
        case CommitServiceError.helperNotFound:
            #if DEBUG
            print("Save helper not found — vfcommit.py is missing from Tools/vfcommit.")
            #endif
            return userFacingSaveEngineMessage
        case let CommitServiceError.helperUnavailable(path):
            #if DEBUG
            print("Save helper unavailable at \(path).")
            #endif
            return userFacingSaveEngineMessage
        case let CommitServiceError.helperFailed(detail):
            #if DEBUG
            print("Save helper failed: \(detail)")
            #endif
            return "Couldn't write the font. \(detail)"
        case let CommitServiceError.invalidHelperOutput(detail):
            #if DEBUG
            print("Save helper returned invalid output: \(detail)")
            #endif
            if detail.localizedCaseInsensitiveContains("fonttools")
                || detail.localizedCaseInsensitiveContains("fontTools")
            {
                return userFacingSaveEngineMessage
            }
            return "Couldn't write the font. \(detail)"
        default:
            return "Export failed: \(error.localizedDescription)"
        }
    }
}
