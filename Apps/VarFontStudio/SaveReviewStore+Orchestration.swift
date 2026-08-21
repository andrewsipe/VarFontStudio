import AppKit
import Foundation
import UniformTypeIdentifiers
import VarFontCore

extension SaveReviewStore {
    // MARK: - Save Review chrome

    var saveReviewWindowTitle: String {
        guard let activeProjectID = requireHost.activeProjectID else { return "Review" }
        return saveReviewWindowTitle(forProjectID: activeProjectID)
    }

    func saveReviewWindowTitle(forProjectID projectID: String) -> String {
        if let open = requireHost.openProject(for: projectID) {
            return "Review — \(requireHost.projectTabLabel(for: open))"
        }
        return "Review"
    }

    func fontsForSaveReview(projectID: String) -> [FontDocument] {
        requireHost.openProject(for: projectID)?.document.fonts ?? []
    }

    func saveReviewSelectedFontID(forProjectID projectID: String) -> String? {
        if let selected = selectedFontID(projectID: projectID) {
            return selected
        }
        return requireHost.openProject(for: projectID)?.selectedFontID
    }

    func saveReviewSession(forProjectID projectID: String, fontID: String? = nil) -> CommitPreflightSession? {
        guard let fontID = fontID ?? saveReviewSelectedFontID(forProjectID: projectID) else { return nil }
        return session(projectID: projectID, fontID: fontID)
    }

    func saveReviewUIState(forProjectID projectID: String) -> SaveReviewUIState {
        uiState(forProjectID: projectID)
    }

    func updateSaveReviewUIState(forProjectID projectID: String, _ transform: (inout SaveReviewUIState) -> Void) {
        updateUIState(forProjectID: projectID, transform)
    }

    func isSaveReviewLoading(forProjectID projectID: String, fontID: String? = nil) -> Bool {
        isLoading(projectID: projectID, fontID: fontID)
    }

    func selectSaveReviewFont(projectID: String, fontID: String) {
        selectFont(projectID: projectID, fontID: fontID)
        guard canPreviewSaveReview(forProjectID: projectID, fontID: fontID) else { return }
        let projects = requireHost.openProjects
        let isDirty = projects
            .first(where: { $0.id == projectID })?
            .document.fonts.first(where: { $0.id == fontID })?
            .dirty ?? false
        if saveReviewSession(forProjectID: projectID, fontID: fontID) == nil || isDirty {
            refreshCommitDiffPreview(forProjectID: projectID, fontID: fontID)
        }
    }

    func saveReviewWasExplicitlyOpened(forProjectID projectID: String) -> Bool {
        wasExplicitlyOpened(projectID: projectID)
    }

    func presentSaveReviewWindow(forProjectID projectID: String? = nil) {
        let targetID = projectID ?? requireHost.activeProjectID
        guard let targetID else {
            requireHost.postStatusMessage("Open a project first.")
            return
        }
        guard canPreviewSaveReview(forProjectID: targetID) else {
            requireHost.postStatusMessage("Nothing to preview — select a font in this project first.")
            return
        }
        if let fontID = requireHost.selectedFont(forProjectID: targetID)?.id {
            ensureSelectedFont(projectID: targetID, fontID: fontID)
        }
        let fontID = saveReviewSelectedFontID(forProjectID: targetID)
        let hasFreshSession: Bool = {
            guard let fontID,
                  let session = session(projectID: targetID, fontID: fontID),
                  session.preflight.ok,
                  let font = requireHost.font(forProjectID: targetID, fontID: fontID) else {
                return false
            }
            // Clean fonts keep the last successful session.
            if !font.dirty { return true }
            // Dirty fonts reuse a prefetched session only when the plan has not changed since.
            return session.planRevision == requireHost.planRevision
                && fontID == requireHost.selectedFontID
                && targetID == requireHost.activeProjectID
        }()
        if !hasFreshSession {
            refreshCommitDiffPreview(forProjectID: targetID, fontID: fontID, presentSheet: false)
        }
        markExplicitlyOpened(projectID: targetID)
        resetUIState(forProjectID: targetID)
        if !SaveReviewWindowLifecycle.focusExisting(
            projectID: targetID,
            title: saveReviewWindowTitle(forProjectID: targetID)
        ) {
            requestOpen(projectID: targetID)
        }
    }

    func toggleSaveReviewWindow(forProjectID projectID: String? = nil) {
        let targetID = projectID ?? requireHost.activeProjectID
        guard let targetID else {
            requireHost.postStatusMessage("Open a project first.")
            return
        }
        if isSaveReviewWindowOpen(forProjectID: targetID) {
            closeSaveReviewWindow(forProjectID: targetID)
            return
        }
        presentSaveReviewWindow(forProjectID: targetID)
    }


    func isSaveReviewWindowOpen(forProjectID projectID: String) -> Bool {
        !SaveReviewWindowLifecycle.existingWindows(
            projectID: projectID,
            title: saveReviewWindowTitle(forProjectID: projectID)
        ).isEmpty
    }

    func closeSaveReviewWindow(forProjectID projectID: String) {
        let title = saveReviewWindowTitle(forProjectID: projectID)
        for window in SaveReviewWindowLifecycle.existingWindows(projectID: projectID, title: title) {
            window.close()
        }
    }

    /// Drop save-review payload when quitting or closing a restored auxiliary window.
    func clearSaveReviewState(forProjectID projectID: String? = nil, fontID: String? = nil) {
        clear(projectID: projectID, fontID: fontID)
    }

    func canPreviewSaveReview(forProjectID projectID: String, fontID: String) -> Bool {
        guard let open = requireHost.openProject(for: projectID),
              open.document.fonts.contains(where: { $0.id == fontID }) else { return false }
        return requireHost.instancePlan(forProjectID: projectID, fontID: fontID) != nil
    }

    func canPreviewSaveReview(forProjectID projectID: String) -> Bool {
        guard let open = requireHost.openProject(for: projectID) else { return false }
        return open.document.fonts.contains { canPreviewSaveReview(forProjectID: projectID, fontID: $0.id) }
    }

    var canPreviewSaveReview: Bool {
        guard let activeProjectID = requireHost.activeProjectID else { return false }
        return canPreviewSaveReview(forProjectID: activeProjectID)
    }

}

extension SaveReviewStore {
    // MARK: - Export / font write path

    func saveCopy() {
        refreshCommitDiffPreview(presentSheet: true)
    }

    func requestSaveToOriginal() {
        guard requireHost.canSave else {
            requireHost.postStatusMessage("Nothing to export — make an edit first.")
            return
        }
        Task {
            guard let projectID = requireHost.activeProjectID, let fontID = requireHost.selectedFontID else { return }
            guard let session = await ensureSaveReviewSession(projectID: projectID, fontID: fontID) else { return }
            guard session.preflight.ok else {
                requireHost.postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return
            }
            confirmSaveToOriginal = session
        }
    }

    func confirmSaveToOriginalAction() {
        guard let session = confirmSaveToOriginal,
              let font = requireHost.font(forProjectID: session.projectID, fontID: session.fontID) else { return }
        confirmSaveToOriginal = nil
        Task {
            await performSave(
                session: session,
                to: URL(fileURLWithPath: font.sourcePath),
                inPlace: true
            )
        }
    }

    func saveToOriginalConfirmationMessage(for session: CommitPreflightSession) -> String {
        guard let font = requireHost.font(forProjectID: session.projectID, fontID: session.fontID) else {
            return "Overwrite the original font file? This cannot be undone."
        }
        return "Overwrite \(URL(fileURLWithPath: font.sourcePath).lastPathComponent)? A .vfstudio-backup copy is written beside the original first."
    }

    /// Confirm overwrite of every source font in the active (or given) project.
    func requestSaveAllToOriginal(inProjectID projectID: String? = nil) {
        guard requireHost.canSave else {
            requireHost.postStatusMessage("Nothing to export — make an edit first.")
            return
        }
        Task {
            guard let prepared = await prepareExportAllTargets(inProjectID: projectID) else { return }
            guard prepared.fonts.count > 1 else {
                // Single-file projects use Export to Original… instead.
                if let font = prepared.fonts.first,
                   let session = prepared.sessions[font.id] {
                    confirmSaveToOriginal = session
                }
                return
            }
            confirmSaveAllToOriginalProjectID = prepared.projectID
        }
    }

    func confirmSaveAllToOriginalAction() {
        guard let projectID = confirmSaveAllToOriginalProjectID else { return }
        confirmSaveAllToOriginalProjectID = nil
        Task {
            await saveAllFilesToOriginalAsync(projectID: projectID)
        }
    }

    func saveAllToOriginalConfirmationMessage(forProjectID projectID: String) -> String {
        let count = requireHost.openProject(for: projectID)?.document.fonts.count ?? 0
        let noun = count == 1 ? "font file" : "font files"
        return "Overwrite \(count) original \(noun)? A .vfstudio-backup copy is written beside each file first."
    }

    /// User-facing: Export — write to `font.outputPath` when set; otherwise open Review (same as Export…).
    func save() {
        requireHost.flushPendingPlanRegeneration()
        guard requireHost.canSave else {
            requireHost.postStatusMessage("Nothing to export — make an edit first.")
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
        guard let projectID = requireHost.activeProjectID, let fontID = requireHost.selectedFontID else { return false }
        return canSaveToRememberedPath(forProjectID: projectID, fontID: fontID)
    }

    func savedOutputLabel(for font: FontDocument) -> String? {
        guard let outputPath = font.outputPath else { return nil }
        let outputURL = URL(fileURLWithPath: outputPath)
        let sourceURL = URL(fileURLWithPath: font.sourcePath)
        if EditorViewModel.normalizedPath(outputURL) == EditorViewModel.normalizedPath(sourceURL) {
            return "original"
        }
        // Package exports keep the same basename — show the destination folder instead.
        if outputURL.lastPathComponent == sourceURL.lastPathComponent {
            let folder = outputURL.deletingLastPathComponent().lastPathComponent
            return folder.isEmpty ? outputURL.lastPathComponent : folder
        }
        return outputURL.lastPathComponent
    }

    private func rememberedOutputURL(forProjectID projectID: String, fontID: String) -> URL? {
        guard let font = requireHost.font(forProjectID: projectID, fontID: fontID),
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
        requireHost.flushPendingPlanRegeneration()
        guard let projectID = requireHost.activeProjectID, let fontID = requireHost.selectedFontID else { return }

        if let outputURL = rememberedOutputURL(forProjectID: projectID, fontID: fontID),
           let font = requireHost.font(forProjectID: projectID, fontID: fontID) {
            guard let session = await ensureSaveReviewSession(projectID: projectID, fontID: fontID) else { return }
            guard session.preflight.ok else {
                requireHost.postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return
            }
            if EditorViewModel.normalizedPath(outputURL) == EditorViewModel.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                confirmSaveToOriginal = session
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
        let targetProjectID = projectID ?? requireHost.activeProjectID
        guard let targetProjectID,
              let open = requireHost.openProject(for: targetProjectID) else {
            if presentSheet {
                requireHost.postStatusMessage("Nothing to save — open a font first.")
            }
            return nil
        }

        let targetFontID = fontID
            ?? saveReviewSelectedFontID(forProjectID: targetProjectID)
            ?? open.selectedFontID
        guard let targetFontID,
              let font = open.document.fonts.first(where: { $0.id == targetFontID }),
              let plan = requireHost.instancePlan(forProjectID: targetProjectID, fontID: targetFontID) else {
            if presentSheet {
                requireHost.postStatusMessage("Nothing to save — open a font first.")
            }
            return nil
        }

        let projectDoc = open.document

        // Included duplicate composed names are advisory — Review and Export stay available.
        // They surface as a preflight warning on the session (see `includedDuplicateComposedNameWarning`).

        guard FileManager.default.fileExists(atPath: font.sourcePath) else {
            requireHost.postStatusMessage("Source font file is missing — re-open the original file.")
            return nil
        }

        let bookmark = requireHost.sourceBookmarks[font.id]
        let outputPath = font.outputPath ?? CommitRequestBuilder.suggestedOutputPath(for: font.sourcePath)

        beginLoading(projectID: targetProjectID, fontID: targetFontID)
        defer { endLoading(projectID: targetProjectID, fontID: targetFontID) }

        let revisionAtStart = requireHost.planRevision

        do {
            if preferWorker {
                await requireHost.commitService.ensureWorkerReady()
            }
            let bookmarkData = bookmark
            let sourcePath = font.sourcePath
            let cacheFontID = font.id
            let analysisAndHelper = try await Task.detached(priority: .userInitiated) {
                let captured = try SourceFontAccess.withReadableSourceURL(
                    bookmark: bookmarkData,
                    fallbackPath: sourcePath
                ) { sourceURL -> (FontAnalysis, SourceFontFingerprint?) in
                    let analysis = try FontAnalysisReader.analyzeForCommitDiff(url: sourceURL)
                    let fingerprint = SourceFontFingerprint.capture(url: sourceURL, analysis: analysis)
                    return (analysis, fingerprint)
                }
                let helperSourcePath = try SourceFontAccess.helperSourcePath(
                    bookmark: bookmarkData,
                    fallbackPath: sourcePath,
                    fontID: cacheFontID
                )
                return (captured.0, helperSourcePath, captured.1)
            }.value
            var analysis = analysisAndHelper.0
            let helperSourcePath = analysisAndHelper.1
            let liveFingerprint = analysisAndHelper.2
            if let otResult = try? await requireHost.commitService.analyzeOTFeatures(sourcePath: helperSourcePath) {
                analysis.mergingOTFeatures(otResult)
            }
            let driftProbe: SourceFontFingerprint.ProbeResult
            if let liveFingerprint {
                driftProbe = SourceFontFingerprint.compare(
                    stored: font.analysisSnapshotID,
                    current: liveFingerprint
                )
            } else {
                driftProbe = SourceFontFingerprint.probe(
                    stored: font.analysisSnapshotID,
                    url: URL(fileURLWithPath: sourcePath),
                    analysis: analysis
                )
            }
            if driftProbe.missingBaseline, let snapshot = driftProbe.current?.serialized {
                // Legacy projects: capture quietly so future Reviews can detect drift.
                requireHost.updateAnalysisSnapshotID(
                    projectID: targetProjectID,
                    fontID: font.id,
                    snapshotID: snapshot,
                    markProjectDirty: true
                )
            }
            var dryRunRequest = CommitRequestBuilder.make(
                font: font,
                naming: projectDoc.naming,
                plan: plan,
                outputPath: outputPath,
                dryRun: true,
                nameidStrategy: font.options.nameidStrategy,
                windowsNameTable: analysis.windowsNameTable,
                otFeatureLabels: analysis.otFeatureLabels
            )
            dryRunRequest.sourcePath = helperSourcePath
            var result = try await requireHost.commitService.commit(dryRunRequest, preferWorker: preferWorker)
            Self.mergeIncludedDuplicateWarning(into: &result, plan: plan)
            SourceFontFingerprint.mergeWarnings(into: &result, probe: driftProbe)
            if result.ok {
                // Drop stale interactive Review results if the plan or project moved mid-flight.
                // Export All / ensureSaveReviewSession pass an explicit fontID and must keep
                // sessions for non-selected siblings — do not require selectedFontID match then.
                guard requireHost.planRevision == revisionAtStart,
                      requireHost.activeProjectID == targetProjectID else {
                    return nil
                }
                let refreshingExplicitFont = fontID != nil
                if !refreshingExplicitFont || presentSheet {
                    guard requireHost.selectedFontID == font.id else { return nil }
                }
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
                    diff: result.diff,
                    naming: projectDoc.naming
                )
                var writeRequest = CommitRequestBuilder.make(
                    font: font,
                    naming: projectDoc.naming,
                    plan: plan,
                    outputPath: outputPath,
                    dryRun: false,
                    nameidStrategy: font.options.nameidStrategy,
                    windowsNameTable: analysis.windowsNameTable,
                    otFeatureLabels: analysis.otFeatureLabels
                )
                writeRequest.sourcePath = helperSourcePath
                let informationalNotes = driftProbe.notes
                    + OpenTypeAxisAudit.allInformationalMessages(
                        analysis: analysis,
                        font: font
                    )
                let session = CommitPreflightSession(
                    projectID: targetProjectID,
                    fontID: font.id,
                    planRevision: revisionAtStart,
                    dryRunRequest: dryRunRequest,
                    baseRequest: writeRequest,
                    preflight: result,
                    diffReport: diffReport,
                    presentation: presentation,
                    informationalNotes: informationalNotes
                )
                storeSession(session, projectID: targetProjectID, fontID: font.id)
                if presentSheet {
                    presentCommitDiffSheet = true
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
                nameidStrategy: font.options.nameidStrategy,
                windowsNameTable: analysis.windowsNameTable,
                otFeatureLabels: analysis.otFeatureLabels
            )
            writeRequest.sourcePath = dryRunRequest.sourcePath
            let failedSession = CommitPreflightSession(
                projectID: targetProjectID,
                fontID: font.id,
                planRevision: revisionAtStart,
                dryRunRequest: dryRunRequest,
                baseRequest: writeRequest,
                preflight: result,
                diffReport: CommitDiffBuilder.empty,
                presentation: .empty,
                informationalNotes: []
            )
            storeSession(failedSession, projectID: targetProjectID, fontID: font.id)
            requireHost.postStatusMessage(message)
            if presentSheet {
                presentCommitDiffSheet = true
            }
            return failedSession
        } catch {
            requireHost.postSaveFailure(commitFailureMessage(error))
            return nil
        }
    }

    func dismissCommitDiffSheet() {
        dismissSheet()
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

    /// Debounced background dry-run so opening Review after edits is often a cache hit.
    func scheduleCommitDiffPrefetch(forProjectID projectID: String, fontID: String) {
        commitDiffPrefetchTask?.cancel()
        commitDiffPrefetchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            // Skip if a fresh session for this plan revision already exists.
            if let existing = session(projectID: projectID, fontID: fontID),
               existing.preflight.ok,
               existing.planRevision == requireHost.planRevision {
                return
            }
            // Avoid stacking on an in-flight load for the same key.
            guard !isLoading(projectID: projectID, fontID: fontID) else { return }
            await refreshCommitDiffPreviewAsync(
                forProjectID: projectID,
                fontID: fontID,
                presentSheet: false
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
            requireHost.postStatusMessage("Exported save plan to \(directory.lastPathComponent)")
        } catch {
            requireHost.postStatusMessage("JSON export failed: \(error.localizedDescription)")
        }
    }

    func presentSavePanel(for session: CommitPreflightSession) {
        guard let font = requireHost.font(forProjectID: session.projectID, fontID: session.fontID) else { return }

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
            let normalizedOutput = EditorViewModel.normalizedPath(url)
            let normalizedSource = EditorViewModel.normalizedPath(URL(fileURLWithPath: font.sourcePath))
            if normalizedOutput == normalizedSource {
                self?.confirmSaveToOriginal = session
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            Task { @MainActor in
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
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
        requireHost.flushPendingPlanRegeneration()
        guard session.preflight.ok else {
            requireHost.postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
            return
        }

        if usingRememberedPath,
           let url = rememberedOutputURL(forProjectID: session.projectID, fontID: session.fontID),
           let font = requireHost.font(forProjectID: session.projectID, fontID: session.fontID) {
            if EditorViewModel.normalizedPath(url) == EditorViewModel.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                confirmSaveToOriginal = session
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

    private struct ExportAllPrepared {
        var projectID: String
        var fonts: [FontDocument]
        var sessions: [String: CommitPreflightSession]
    }

    /// Shared preflight for Export All / Export All to Original.
    @MainActor
    private func prepareExportAllTargets(inProjectID projectID: String?) async -> ExportAllPrepared? {
        guard let projectID = projectID ?? requireHost.activeProjectID,
              let open = requireHost.openProject(for: projectID) else { return nil }

        let targets = open.document.fonts
        guard !targets.isEmpty else {
            requireHost.postStatusMessage("Nothing to export.")
            return nil
        }

        for font in targets {
            guard requireHost.instancePlan(forProjectID: projectID, fontID: font.id) != nil else {
                requireHost.postStatusMessage("Couldn't prepare the export preview. Try again, or check that the font file hasn't moved or changed.")
                return nil
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
                requireHost.postStatusMessage("Export preview failed for \(requireHost.fontBasename(for: font)). Check the Review window for details.")
                return nil
            }
            guard session.preflight.ok else {
                requireHost.postStatusMessage(session.preflight.errors.first?.message ?? "Export preview failed. Check the Review window for details.")
                return nil
            }
        }

        return ExportAllPrepared(projectID: projectID, fonts: targets, sessions: sessions)
    }

    @MainActor
    private func saveAllFilesAsync(inProjectID projectID: String? = nil) async {
        requireHost.flushPendingPlanRegeneration()
        guard let prepared = await prepareExportAllTargets(inProjectID: projectID) else { return }
        let projectID = prepared.projectID
        let targets = prepared.fonts
        let sessions = prepared.sessions

        var outputURLs: [String: URL] = [:]
        for font in targets {
            if let url = rememberedOutputURL(forProjectID: projectID, fontID: font.id) {
                if EditorViewModel.normalizedPath(url) == EditorViewModel.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                    requireHost.postStatusMessage("Export All cannot overwrite originals — choose a folder or use Export All to Original….")
                    return
                }
                outputURLs[font.id] = url
            }
        }

        var outputDirectory: URL?
        var nestedBecauseOfCollision = false
        if targets.contains(where: { outputURLs[$0.id] == nil }) {
            guard let chosen = await StudioOutputFolderPicker.choose(
                title: "Export Fonts",
                message: "Choose a folder. Fonts keep their original filenames. If you pick the source folder, a “Patched” subfolder is created automatically."
            ) else { return }

            let open = requireHost.openProject(for: projectID)
            let folderLabel = open?.document.displayName
                ?? open?.document.familyLabel
            let resolved = CommitRequestBuilder.packageExportDirectory(
                chosenDirectory: chosen,
                sourcePaths: targets.map(\.sourcePath),
                folderLabel: folderLabel
            )
            nestedBecauseOfCollision = resolved.nestedBecauseOfCollision
            outputDirectory = resolved.directory

            do {
                try FileManager.default.createDirectory(
                    at: resolved.directory,
                    withIntermediateDirectories: true
                )
            } catch {
                requireHost.postStatusMessage("Couldn't create export folder: \(error.localizedDescription)")
                return
            }

            for font in targets where outputURLs[font.id] == nil {
                outputURLs[font.id] = URL(
                    fileURLWithPath: CommitRequestBuilder.packageOutputPath(
                        for: font.sourcePath,
                        in: resolved.directory
                    )
                )
            }
        }

        for font in targets {
            guard let url = outputURLs[font.id] else { continue }
            if EditorViewModel.normalizedPath(url) == EditorViewModel.normalizedPath(URL(fileURLWithPath: font.sourcePath)) {
                requireHost.postStatusMessage("Export All cannot overwrite originals — choose a different folder or use Export All to Original….")
                return
            }
        }

        requireHost.beginBusyWork(status: "Exporting fonts…", progress: 0)
        defer { requireHost.endBusyWork() }

        let total = max(targets.count, 1)
        var exportedCount = 0
        var failedNames: [String] = []
        for (index, font) in targets.enumerated() {
            guard let session = sessions[font.id], let url = outputURLs[font.id] else { continue }
            let name = requireHost.fontBasename(for: font)
            requireHost.clearPersistentSaveError()
            requireHost.updateBusyWork(
                status: "Exporting \(name) (\(index + 1) of \(total))…",
                progress: Double(index) / Double(total)
            )
            await Task.yield()
            await performSave(
                session: session,
                to: url,
                manageBusyState: false,
                closeReviewOnSuccess: false
            )
            if requireHost.font(forProjectID: projectID, fontID: font.id)?.dirty == false {
                exportedCount += 1
            } else {
                failedNames.append(name)
            }
            requireHost.updateBusyWork(
                status: "Finished \(name) (\(index + 1) of \(total))",
                progress: Double(index + 1) / Double(total)
            )
            await Task.yield()
        }

        clearSaveReviewState(forProjectID: projectID)
        dismissSheet()
        closeSaveReviewWindow(forProjectID: projectID)

        let folderLabel = outputDirectory?.lastPathComponent
            ?? outputURLs.values.first?.deletingLastPathComponent().lastPathComponent
            ?? "output folder"
        if !failedNames.isEmpty {
            let listed = failedNames.joined(separator: ", ")
            requireHost.postSaveFailure(
                "Export finished with issues for \(listed). \(exportedCount) of \(targets.count) fonts exported to \(folderLabel)."
            )
        } else if nestedBecauseOfCollision {
            requireHost.postStatusMessage(
                "Exported \(exportedCount) fonts to \(folderLabel) (created to avoid overwriting originals)"
            )
        } else {
            requireHost.postStatusMessage("Exported \(exportedCount) fonts to \(folderLabel)")
        }
    }

    @MainActor
    private func saveAllFilesToOriginalAsync(projectID: String) async {
        guard let prepared = await prepareExportAllTargets(inProjectID: projectID) else { return }
        let targets = prepared.fonts
        let sessions = prepared.sessions

        requireHost.beginBusyWork(status: "Writing fonts to originals…", progress: 0)
        defer { requireHost.endBusyWork() }

        let total = max(targets.count, 1)
        var exportedCount = 0
        for (index, font) in targets.enumerated() {
            guard let session = sessions[font.id] else { continue }
            let name = requireHost.fontBasename(for: font)
            requireHost.updateBusyWork(
                status: "Writing \(name) to original (\(index + 1) of \(total))…",
                progress: Double(index) / Double(total)
            )
            await Task.yield()
            await performSave(
                session: session,
                to: URL(fileURLWithPath: font.sourcePath),
                inPlace: true,
                manageBusyState: false,
                closeReviewOnSuccess: false
            )
            if requireHost.font(forProjectID: projectID, fontID: font.id)?.dirty == false {
                exportedCount += 1
            }
            requireHost.updateBusyWork(
                status: "Finished \(name) (\(index + 1) of \(total))",
                progress: Double(index + 1) / Double(total)
            )
            await Task.yield()
        }

        clearSaveReviewState(forProjectID: projectID)
        dismissSheet()
        closeSaveReviewWindow(forProjectID: projectID)

        let noun = exportedCount == 1 ? "font" : "fonts"
        requireHost.postStatusMessage("Overwrote \(exportedCount) original \(noun)")
    }

    var isSaveActionBlocked: Bool {
        if requireHost.isBusy { return true }
        guard let projectID = requireHost.activeProjectID else { return false }
        return isSaveReviewLoading(forProjectID: projectID)
    }

    func performSave(
        session: CommitPreflightSession,
        to outputURL: URL,
        inPlace: Bool = false,
        manageBusyState: Bool = true,
        closeReviewOnSuccess: Bool = true
    ) async {
        guard let projectIndex = requireHost.openProjects.firstIndex(where: { $0.id == session.projectID }),
              let fontIndex = requireHost.openProjects[projectIndex].document.fonts.firstIndex(where: { $0.id == session.fontID }) else {
            return
        }

        let originalSourcePath = requireHost.openProjects[projectIndex].document.fonts[fontIndex].sourcePath
        guard FileManager.default.fileExists(atPath: originalSourcePath) else {
            requireHost.postSaveFailure("Source font file is missing — re-open the original file.")
            return
        }

        requireHost.clearPersistentSaveError()

        var request = session.baseRequest
        request.outputPath = outputURL.path
        request.originalSourcePath = originalSourcePath
        request.allowInPlace = inPlace
        request.dryRun = false
        request.requestID = UUID().uuidString.lowercased()

        let fontName = requireHost.fontBasename(for: requireHost.openProjects[projectIndex].document.fonts[fontIndex])
        if manageBusyState {
            requireHost.beginBusyWork(
                status: inPlace ? "Writing \(fontName) to original…" : "Exporting \(fontName)…",
                progress: 0.15
            )
        } else {
            requireHost.updateBusyWork(
                status: inPlace ? "Writing \(fontName) to original…" : "Writing \(fontName)…"
            )
        }
        defer { if manageBusyState { requireHost.endBusyWork() } }

        do {
            await Task.yield()
            let result = try await requireHost.commitService.commit(request)
            guard result.ok else {
                let raw = result.errors.first?.message ?? "Export failed."
                requireHost.postSaveFailure(
                    "\(fontName): \(friendlyExportFailureMessage(raw))"
                )
                return
            }

            let writtenPath = inPlace ? originalSourcePath : outputURL.path
            guard FileManager.default.fileExists(atPath: writtenPath) else {
                requireHost.postSaveFailure(
                    "Export finished without writing \(URL(fileURLWithPath: writtenPath).lastPathComponent). Try another folder or check disk permissions."
                )
                return
            }

            if manageBusyState {
                requireHost.updateBusyWork(status: "Finishing \(fontName)…", progress: 0.9)
                await Task.yield()
            }

            await requireHost.refreshProjectAfterExport(
                projectID: session.projectID,
                fontID: session.fontID,
                writtenPath: writtenPath,
                inPlace: inPlace,
                previousSourcePath: originalSourcePath
            )

            clearSaveReviewState(forProjectID: session.projectID, fontID: session.fontID)
            dismissSheet()
            if closeReviewOnSuccess {
                closeSaveReviewWindow(forProjectID: session.projectID)
            }

            if manageBusyState {
                requireHost.updateBusyWork(status: "Exported \(fontName)", progress: 1)
            }

            if inPlace {
                let backupName = URL(fileURLWithPath: originalSourcePath).lastPathComponent + ".vfstudio-backup"
                requireHost.postStatusMessage("Saved to original (backup: \(backupName)) — ready to instance static fonts.")
            } else if let count = result.summary?.instancesWritten {
                requireHost.postStatusMessage("Saved \(count) instances to \(outputURL.lastPathComponent) — ready to instance static fonts.")
            } else {
                requireHost.postStatusMessage("Saved \(outputURL.lastPathComponent) — ready to instance static fonts.")
            }
        } catch {
            requireHost.postSaveFailure(commitFailureMessage(error))
        }
    }

    private func friendlyExportFailureMessage(_ detail: String) -> String {
        if detail.localizedCaseInsensitiveContains("KeyError"),
           detail.localizedCaseInsensitiveContains("ital")
        {
            return "Couldn't write the font — a naming-only ital axis is still present in fvar and needs a coordinate on every instance. Re-export with the updated save engine, or set the ital naming stop to the fvar pin (e.g. −12)."
        }
        return detail
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
            let friendly = friendlyExportFailureMessage(detail)
            if friendly != detail { return friendly }
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
            let friendly = friendlyExportFailureMessage(detail)
            if friendly != detail { return friendly }
            return "Couldn't write the font. \(detail)"
        default:
            return "Export failed: \(error.localizedDescription)"
        }
    }

    /// Soft-gate companion: included duplicate composed names no longer abort Review/Export.
    /// Surface them at the top of preflight warnings so the write preview stays usable.
    private static func mergeIncludedDuplicateWarning(into result: inout CommitResult, plan: InstancePlan) {
        let duplicateKeys = plan.instances
            .filter { $0.included && $0.duplicate }
            .map(\.key)
        guard !duplicateKeys.isEmpty else { return }
        guard !result.warnings.contains(where: { $0.code == "duplicate_composed_name" }) else { return }

        let count = duplicateKeys.count
        result.warnings.insert(
            PlanWarning(
                code: "duplicate_composed_name",
                keys: duplicateKeys,
                message: count == 1
                    ? "1 included instance shares its composed name with another instance."
                    : "\(count) included instances share composed names with other instances.",
                hint: "Rename stops, exclude duplicates from export, or proceed if intentional — naming quality is advisory."
            ),
            at: 0
        )
    }
}
