import AppKit
import Combine
import Foundation
import VarFontCore

struct InstancerOpenRequest: Equatable {
    /// WindowGroup value — one window per project workspace (`project|{id}`).
    let windowKey: String
    let token: UUID
}

/// One Instancer window's open file tabs (Review-style).
@MainActor
final class InstancerWorkspace: ObservableObject {
    let windowKey: String
    var projectID: String?
    @Published var tabKeys: [String] = []
    @Published var selectedTabKey: String?

    init(windowKey: String, projectID: String? = nil) {
        self.windowKey = windowKey
        self.projectID = projectID
    }

    var hasTabs: Bool { !tabKeys.isEmpty }
}

enum InstancerFilterKind: String, Equatable, CaseIterable, Identifiable {
    case all
    case clean
    case custom
    case collision
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .clean: return "Clean"
        case .custom: return "Custom"
        case .collision: return "Collision"
        case .attention: return "Needs attention"
        }
    }

    var hint: String {
        switch self {
        case .all: return "Show everything."
        case .clean: return "No naming or coordinate problems — ready to generate as-is."
        case .custom: return "Added here, not in the source font — only becomes a real stop if sent to Studio."
        case .collision: return "Two rows share either an output name or a coordinate — same output name overwrites on disk; same coordinates means an identical design under different names."
        case .attention: return "fvar naming is incomplete — falling back to STAT. Best fixed in Studio, not patched per file."
        }
    }
}

@MainActor
final class InstancerSessionState: ObservableObject {
    let sessionKey: String
    var projectID: String?
    var fontID: String?

    @Published var sourceDisplayName: String = ""
    @Published var sourcePath: String = ""
    @Published var sourceBookmark: Data?
    /// Sandbox-safe copy for the Python helper (cached on first generate).
    @Published var helperCachedPath: String?
    /// Cache key for `SourceFontAccess.helperSourcePath` (font id or synthetic).
    var sourceAccessID: String = ""
    @Published var isStudioExport: Bool = false
    @Published var axisTags: [String] = []
    @Published var rows: [InstancerRow] = []
    @Published var selectedIDs: Set<String> = []
    @Published var psPrefix: String = ""
    @Published var psInferred: String = ""
    @Published var psSourceLabel: String = "inferred"
    @Published var filterKind: InstancerFilterKind = .all
    @Published var filterText: String = ""
    @Published var isLoading = false
    /// Short progressive status shown while `isLoading` (and in the status bar).
    @Published var loadStatus: String = ""
    @Published var loadError: String?
    @Published var statusHint: String = "Reading font…"
    @Published var editingRowID: String?
    @Published var showComposer = false
    @Published var composerName = ""
    @Published var composerCoords: [String: Double] = [:]
    @Published var composerWarning: String?
    @Published var composerForcePending = false
    /// Format 3 weight-link target — drives Bold RIBBI for source and custom rows.
    @Published var boldLinkedWght: Double?
    @Published var isGenerating = false
    @Published var generatingRowID: String?
    @Published var generateCompletedCount = 0
    @Published var generateTotalCount = 0
    @Published var generateStatus: String = ""
    @Published var lastOutputDir: String?

    init(sessionKey: String, projectID: String? = nil, fontID: String? = nil) {
        self.sessionKey = sessionKey
        self.projectID = projectID
        self.fontID = fontID
        self.sourceAccessID = fontID ?? sessionKey
    }

    var hasSource: Bool { !sourcePath.isEmpty }

    var collisions: [String: InstancerCollisionKind] {
        InstancerNaming.classifyCollisions(rows: rows, axisTags: axisTags)
    }

    var visibleRows: [InstancerRow] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let collisions = self.collisions
        return rows.filter { row in
            let isCollision = collisions[row.id] != nil
            let isFallback = InstancerNaming.usesSTATFallback(row) || InstancerNaming.willFail(row)
            switch filterKind {
            case .all: break
            case .clean:
                if isCollision || isFallback { return false }
            case .custom:
                if row.origin != .custom { return false }
            case .collision:
                if !isCollision { return false }
            case .attention:
                if !isFallback { return false }
            }
            if q.isEmpty { return true }
            let blob = [
                InstancerNaming.resolvedName(for: row) ?? "",
                row.fvarName ?? "",
                row.statName ?? "",
                axisTags.map { "\($0) \(InstancerNaming.formatCoord(row.coords[$0] ?? InstancerAxisDefaults.value(for: $0)))" }.joined(separator: " "),
                InstancerNaming.outputFileName(psPrefix: psPrefix, row: row) ?? "",
            ].joined(separator: " ").lowercased()
            return blob.contains(q)
        }
        .sorted { InstancerNaming.compareRows($0, $1, axisTags: axisTags) }
    }

    var selectedCount: Int { selectedIDs.count }

    var sourceAttentionCount: Int {
        rows.filter { $0.origin == .source && (InstancerNaming.usesSTATFallback($0) || InstancerNaming.willFail($0)) }.count
    }

    var customCount: Int { rows.filter { $0.origin == .custom }.count }

    var generateBlockedReason: String? {
        if !hasSource { return "Open a variable font first" }
        if isLoading { return "Still reading the font…" }
        if selectedIDs.isEmpty { return "Select at least one instance" }
        let collisions = self.collisions
        for id in selectedIDs {
            guard let row = rows.first(where: { $0.id == id }) else { continue }
            if InstancerNaming.willFail(row) {
                return "Some selected instances have no usable name — resolve them or deselect before generating"
            }
            if collisions[id] != nil {
                return "Resolve the flagged rows in your selection before generating"
            }
        }
        return nil
    }

    var canGenerate: Bool { generateBlockedReason == nil }

    func applyBuilt(_ built: InstancerSessionBuilder.BuiltSession, sourcePath: String, isStudioExport: Bool) {
        self.sourceDisplayName = built.sourceDisplayName
        self.sourcePath = sourcePath
        self.isStudioExport = isStudioExport
        self.axisTags = built.axisTags
        self.rows = built.rows
        self.boldLinkedWght = built.boldLinkedWght
        self.psInferred = built.inferredPSPrefix
        self.psPrefix = built.inferredPSPrefix
        self.psSourceLabel = isStudioExport ? "nameID 25 / inferred" : "inferred"
        self.selectedIDs = InstancerNaming.defaultSelectedIDs(rows: built.rows, axisTags: built.axisTags)
        self.filterKind = .all
        self.filterText = ""
        self.loadError = nil
        self.loadStatus = ""
        self.statusHint = "Click a badge to isolate · click again for all"
        self.showComposer = false
        resetComposer()
    }

    func resetComposer() {
        composerName = ""
        composerWarning = nil
        composerForcePending = false
        var coords: [String: Double] = [:]
        for tag in axisTags {
            coords[tag] = InstancerAxisDefaults.value(for: tag)
        }
        if axisTags.contains("wght") {
            coords.removeValue(forKey: "wght")
        }
        composerCoords = coords
    }

    func styleBits(for coords: [String: Double]) -> (bold: Bool, italic: Bool) {
        InstancerSessionBuilder.inferStyleBits(coords: coords, boldLinkedWght: boldLinkedWght)
    }

    func updateRow(_ id: String, _ transform: (inout InstancerRow) -> Void) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        transform(&rows[index])
    }

    /// Keep Style (RIBBI) in sync when axis coordinates change.
    func updateRowCoords(_ id: String, tag: String, value: Double?) {
        updateRow(id) { row in
            if let value {
                row.coords[tag] = value
            } else {
                row.coords.removeValue(forKey: tag)
            }
            let bits = InstancerSessionBuilder.inferStyleBits(
                coords: row.coords,
                boldLinkedWght: boldLinkedWght
            )
            row.isBold = bits.bold
            row.isItalic = bits.italic
        }
    }

    func filterCounts() -> (all: Int, clean: Int, custom: Int, collision: Int, attention: Int) {
        let collisions = self.collisions
        var clean = 0, custom = 0, collision = 0, attention = 0
        for row in rows {
            let isCollision = collisions[row.id] != nil
            let isFallback = InstancerNaming.usesSTATFallback(row) || InstancerNaming.willFail(row)
            if row.origin == .custom { custom += 1 }
            if isCollision { collision += 1 }
            if isFallback { attention += 1 }
            if !isCollision && !isFallback { clean += 1 }
        }
        return (rows.count, clean, custom, collision, attention)
    }
}

/// Instancer chrome + session orchestration (mirrors SaveReviewStore shape).
@MainActor
final class InstancerStore: ObservableObject {
    weak var host: EditorViewModel?

    @Published private(set) var openRequest: InstancerOpenRequest?
    @Published private(set) var workspaces: [String: InstancerWorkspace] = [:]
    @Published private(set) var sessions: [String: InstancerSessionState] = [:]
    @Published private(set) var explicitlyOpenedKeys: Set<String> = []
    /// Only one VF may generate at a time (CPU-heavy Python helper).
    @Published private(set) var activeGenerateSessionKey: String?

    var isGenerateBusy: Bool { activeGenerateSessionKey != nil }

    static func sessionKey(projectID: String, fontID: String) -> String {
        "\(projectID)|\(fontID)"
    }

    static func projectWindowKey(projectID: String) -> String {
        "project|\(projectID)"
    }

    /// filesystem-safe id for helper cache copies (session keys may contain `/` and `|`).
    static func helperCacheID(for sessionKey: String) -> String {
        sessionKey
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    func workspace(forKey key: String) -> InstancerWorkspace? {
        workspaces[key]
    }

    func session(forKey key: String) -> InstancerSessionState? {
        sessions[key]
    }

    func selectedSession(forWindowKey windowKey: String) -> InstancerSessionState? {
        guard let workspace = workspaces[windowKey],
              let tab = workspace.selectedTabKey else { return nil }
        return sessions[tab]
    }

    /// Session shown in the Instancer window — real tab when present, else a durable unpopulated shell.
    func displaySession(forWindowKey windowKey: String) -> InstancerSessionState {
        if let selected = selectedSession(forWindowKey: windowKey) {
            return selected
        }
        return ensureUnpopulatedSession(forWindowKey: windowKey)
    }

    private func ensureUnpopulatedSession(forWindowKey windowKey: String) -> InstancerSessionState {
        let key = unpopulatedSessionKey(forWindowKey: windowKey)
        if let existing = sessions[key] {
            return existing
        }
        let state = InstancerSessionState(sessionKey: key, projectID: nil, fontID: nil)
        state.statusHint = "Choose a font tab above."
        sessions[key] = state
        return state
    }

    private func unpopulatedSessionKey(forWindowKey windowKey: String) -> String {
        "unpopulated|\(windowKey)"
    }

    func windowKey(containingSessionKey sessionKey: String) -> String? {
        for (key, workspace) in workspaces where workspace.tabKeys.contains(sessionKey) {
            return key
        }
        return nil
    }

    /// Reopen the Instancer window that owns the in-flight generate.
    func revealActiveGenerateWindow() {
        guard let sessionKey = activeGenerateSessionKey,
              let windowKey = windowKey(containingSessionKey: sessionKey) else {
            return
        }
        if let workspace = workspaces[windowKey] {
            workspace.selectedTabKey = sessionKey
        }
        requestOpen(windowKey: windowKey)
    }

    func requestOpen(windowKey: String) {
        explicitlyOpenedKeys.insert(windowKey)
        openRequest = InstancerOpenRequest(windowKey: windowKey, token: UUID())
    }

    @discardableResult
    private func ensureWorkspace(windowKey: String, projectID: String? = nil) -> InstancerWorkspace {
        if let existing = workspaces[windowKey] {
            if projectID != nil { existing.projectID = projectID }
            return existing
        }
        let workspace = InstancerWorkspace(windowKey: windowKey, projectID: projectID)
        workspaces[windowKey] = workspace
        return workspace
    }

    private func selectTab(_ sessionKey: String, in workspace: InstancerWorkspace) {
        if !workspace.tabKeys.contains(sessionKey) {
            workspace.tabKeys.append(sessionKey)
        }
        workspace.selectedTabKey = sessionKey
        objectWillChange.send()
    }

    func selectTab(sessionKey: String, windowKey: String) {
        guard let workspace = workspaces[windowKey] else { return }
        guard workspace.tabKeys.contains(sessionKey) else { return }
        workspace.selectedTabKey = sessionKey
        objectWillChange.send()
    }

    func closeTab(sessionKey: String, windowKey: String) {
        guard let workspace = workspaces[windowKey] else { return }
        workspace.tabKeys.removeAll { $0 == sessionKey }
        sessions[sessionKey] = nil
        if workspace.selectedTabKey == sessionKey {
            workspace.selectedTabKey = workspace.tabKeys.last
        }
        if workspace.tabKeys.isEmpty {
            workspace.selectedTabKey = nil
            _ = ensureUnpopulatedSession(forWindowKey: windowKey)
        }
        objectWillChange.send()
    }

    /// Open Instancer for a Studio project — all project fonts as tabs, analysis after paint.
    func presentInstancerWindow(projectID: String? = nil, fontID: String? = nil) {
        guard let host else { return }
        let projectID = projectID ?? host.activeProjectID
        guard let projectID,
              let open = host.openProject(for: projectID),
              !open.document.fonts.isEmpty else {
            return
        }

        let fonts = open.document.fonts
        let preferredFontID = fontID
            ?? (projectID == host.activeProjectID ? host.selectedFontID : nil)
            ?? fonts.first?.id
        let windowKey = Self.projectWindowKey(projectID: projectID)
        let workspace = ensureWorkspace(windowKey: windowKey, projectID: projectID)

        var tabKeys: [String] = []
        for font in fonts {
            let key = Self.sessionKey(projectID: projectID, fontID: font.id)
            tabKeys.append(key)
            let state = sessions[key] ?? InstancerSessionState(
                sessionKey: key,
                projectID: projectID,
                fontID: font.id
            )
            state.projectID = projectID
            state.fontID = font.id
            state.sourceAccessID = font.id
            state.sourceBookmark = host.sourceBookmarks[font.id]
            if state.sourceDisplayName.isEmpty || state.sourcePath != font.sourcePath {
                state.sourceDisplayName = URL(fileURLWithPath: font.sourcePath).lastPathComponent
                state.sourcePath = font.sourcePath
                state.isStudioExport = font.outputPath != nil
                state.statusHint = "Reading \(state.sourceDisplayName)…"
            }
            sessions[key] = state
        }
        workspace.tabKeys = tabKeys
        if let preferredFontID {
            let preferredKey = Self.sessionKey(projectID: projectID, fontID: preferredFontID)
            workspace.selectedTabKey = tabKeys.contains(preferredKey) ? preferredKey : tabKeys.first
        } else {
            workspace.selectedTabKey = tabKeys.first
        }

        requestOpen(windowKey: windowKey)

        // Load every project font so switching tabs is already warm.
        for font in fonts {
            let key = Self.sessionKey(projectID: projectID, fontID: font.id)
            guard let state = sessions[key] else { continue }
            loadSessionAsync(
                state,
                path: font.sourcePath,
                bookmark: state.sourceBookmark,
                isStudioExport: font.outputPath != nil,
                psOverride: font.options.familyPSPrefix
            )
        }
    }

    func toggleInstancerWindow(projectID: String? = nil, fontID: String? = nil) {
        guard let host else { return }
        let projectID = projectID ?? host.activeProjectID
        guard let projectID,
              let open = host.openProject(for: projectID),
              !open.document.fonts.isEmpty else {
            return
        }
        let windowKey = Self.projectWindowKey(projectID: projectID)
        if isInstancerWindowOpen(windowKey: windowKey) {
            closeInstancerWindow(windowKey: windowKey)
        } else {
            presentInstancerWindow(projectID: projectID, fontID: fontID)
        }
    }

    func windowTitle(forWindowKey windowKey: String) -> String {
        if windowKey.hasPrefix("project|"),
           let projectID = workspaces[windowKey]?.projectID,
           let open = host?.openProject(for: projectID) {
            let name = open.document.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let name, !name.isEmpty {
                return "Instance — \(name)"
            }
            let family = open.document.familyLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !family.isEmpty {
                return "Instance — \(family)"
            }
        }
        return "Instance Static Fonts"
    }

    func isInstancerWindowOpen(windowKey: String) -> Bool {
        let title = windowTitle(forWindowKey: windowKey)
        return NSApplication.shared.windows.contains { window in
            guard InstancerWindowLifecycle.isInstancerWindow(window) else { return false }
            return window.title == title || window.title.hasPrefix(title)
        }
    }

    func closeInstancerWindow(windowKey: String) {
        let title = windowTitle(forWindowKey: windowKey)
        for window in NSApplication.shared.windows where InstancerWindowLifecycle.isInstancerWindow(window) {
            if window.title == title || window.title.hasPrefix(title) {
                window.close()
            }
        }
    }

    /// Reload Instancer tab after export promoted or refreshed the working font path.
    func reloadSessionAfterExport(projectID: String, fontID: String) {
        let sessionKey = Self.sessionKey(projectID: projectID, fontID: fontID)
        guard let host,
              let font = host.font(forProjectID: projectID, fontID: fontID),
              let state = sessions[sessionKey] else {
            return
        }
        state.rows = []
        state.selectedIDs = []
        state.loadError = nil
        state.sourcePath = font.sourcePath
        state.sourceDisplayName = URL(fileURLWithPath: font.sourcePath).lastPathComponent
        state.sourceBookmark = host.sourceBookmarks[fontID]
        state.isStudioExport = true
        loadSessionAsync(
            state,
            path: font.sourcePath,
            bookmark: state.sourceBookmark,
            isStudioExport: true,
            psOverride: font.options.familyPSPrefix,
            forceReload: true
        )
    }

    func loadSessionAsync(
        _ state: InstancerSessionState,
        path: String,
        bookmark: Data?,
        isStudioExport: Bool,
        psOverride: String?,
        forceReload: Bool = false
    ) {
        // Skip re-read when we already have rows for this path (re-open same session).
        if !forceReload,
           !state.rows.isEmpty, state.sourcePath == path, state.loadError == nil, !state.isLoading {
            return
        }
        state.isLoading = true
        state.loadError = nil
        state.loadStatus = "Reading \(URL(fileURLWithPath: path).lastPathComponent)…"
        state.statusHint = state.loadStatus
        let displayName = URL(fileURLWithPath: path).lastPathComponent
        objectWillChange.send()

        Task { @MainActor in
            do {
                let built = try await Task.detached(priority: .userInitiated) {
                    let analysis = try SourceFontAccess.withReadableSourceURL(
                        bookmark: bookmark,
                        fallbackPath: path
                    ) { url in
                        try FontAnalysisReader.analyzeForCommitDiff(url: url)
                    }
                    var session = InstancerSessionBuilder.build(from: analysis)
                    if let override = psOverride?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
                        session.inferredPSPrefix = override
                    }
                    return session
                }.value
                guard self.sessions[state.sessionKey] === state else { return }
                state.loadStatus = "Building instance list…"
                state.statusHint = state.loadStatus
                state.applyBuilt(built, sourcePath: path, isStudioExport: isStudioExport)
            } catch {
                guard self.sessions[state.sessionKey] === state else { return }
                state.loadError = error.localizedDescription
                state.rows = []
                state.sourceDisplayName = displayName
                state.sourcePath = path
                state.isStudioExport = isStudioExport
                state.loadStatus = ""
                state.statusHint = "Couldn't read font"
            }
            state.isLoading = false
            if state.loadError == nil {
                state.loadStatus = ""
            }
            self.objectWillChange.send()
        }
    }

    /// Synchronous path kept for tests; prefer `loadSessionAsync` from UI.
    func loadSession(_ state: InstancerSessionState, font: FontDocument) {
        state.isLoading = true
        state.loadError = nil
        let bookmark = host?.sourceBookmarks[font.id] ?? state.sourceBookmark
        let path = font.sourcePath
        let isExport = font.outputPath != nil
        do {
            let analysis = try SourceFontAccess.withReadableSourceURL(
                bookmark: bookmark,
                fallbackPath: path
            ) { url in
                try FontAnalysisReader.analyzeForCommitDiff(url: url)
            }
            var built = InstancerSessionBuilder.build(from: analysis)
            if let override = font.options.familyPSPrefix?
                .trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
                built.inferredPSPrefix = override
            }
            state.applyBuilt(built, sourcePath: path, isStudioExport: isExport)
        } catch {
            state.loadError = error.localizedDescription
            state.rows = []
            state.sourceDisplayName = URL(fileURLWithPath: path).lastPathComponent
            state.sourcePath = path
        }
        state.isLoading = false
    }

    func focusStudioForNaming(session: InstancerSessionState) {
        guard let fontID = session.fontID, let projectID = session.projectID else {
            host?.postStatusMessage("Open this font in Studio to fix naming there.")
            return
        }
        host?.activateProject(id: projectID)
        host?.focusInspectorProjectScope(fontID: fontID, fileNaming: .section)
        MainWindowLifecycle.focusExistingMainWindow()
    }

    /// Review-style Generate: folder panel → `{PSPrefix} Static` nest when needed → write.
    func presentGenerate(session: InstancerSessionState) async -> GenerateOutcome? {
        guard session.canGenerate, !session.isGenerating else { return nil }
        if isGenerateBusy, activeGenerateSessionKey != session.sessionKey {
            return .failure(userMessage: "Another font is still generating statics — wait for it to finish.")
        }

        let sourceParent = accessibleStartDirectory(for: session)
        let psLabel = session.psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderLabel = psLabel.isEmpty ? nil : psLabel
        let nestedHint = CommitRequestBuilder.nestedFolderName(folderLabel: folderLabel, kind: .staticFonts)

        guard let chosen = await StudioOutputFolderPicker.choose(
            title: "Generate Static Fonts",
            message: "Choose a folder. If you pick the source folder, a “\(nestedHint)” subfolder is created automatically.",
            startingDirectory: sourceParent
        ) else {
            return nil
        }

        return await runGenerate(
            session: session,
            chosenDirectory: chosen,
            folderLabel: folderLabel
        )
    }

    /// Generate every ready font tab in a workspace (Review “Export All” counterpart).
    func presentGenerateAll(windowKey: String) async -> GenerateOutcome? {
        guard let workspace = workspaces[windowKey] else { return nil }
        let targets = workspace.tabKeys.compactMap { sessions[$0] }.filter(\.canGenerate)
        guard !targets.isEmpty else {
            return .failure(userMessage: "No fonts are ready to generate — select instances without collisions or naming failures.")
        }
        if isGenerateBusy {
            return .failure(userMessage: "Another font is still generating statics — wait for it to finish.")
        }

        let lead = targets[0]
        let psLabel = lead.psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderLabel = psLabel.isEmpty ? nil : psLabel
        let nestedHint = CommitRequestBuilder.nestedFolderName(folderLabel: folderLabel, kind: .staticFonts)

        guard let chosen = await StudioOutputFolderPicker.choose(
            title: "Generate Static Fonts",
            message: "Choose a folder for all \(targets.count) file\(targets.count == 1 ? "" : "s"). If you pick a source folder, a “\(nestedHint)” subfolder is created automatically.",
            startingDirectory: accessibleStartDirectory(for: lead)
        ) else {
            return nil
        }

        let accessed = chosen.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                chosen.stopAccessingSecurityScopedResource()
            }
        }

        var totalWritten = 0
        var totalFailed = 0
        var lastReveal: String?
        var nestedBecauseOfCollision = false
        var filesSucceeded = 0

        for session in targets {
            selectTab(sessionKey: session.sessionKey, windowKey: windowKey)
            // Let the tab/content paint before the helper run starts.
            await Task.yield()

            let label = session.psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = CommitRequestBuilder.packageExportDirectory(
                chosenDirectory: chosen,
                sourcePaths: [session.sourcePath],
                folderLabel: label.isEmpty ? nil : label,
                nestedKind: .staticFonts
            )
            do {
                try FileManager.default.createDirectory(
                    at: resolved.directory,
                    withIntermediateDirectories: true
                )
            } catch {
                totalFailed += 1
                host?.postStatusMessage("\(session.sourceDisplayName): Couldn't create output folder")
                continue
            }

            let result = await generate(
                session: session,
                outputDir: resolved.directory,
                overwrite: true
            )
            switch result {
            case .success(let instanceResult):
                let written = instanceResult.written.count
                totalWritten += written
                totalFailed += instanceResult.errors.count
                if written > 0 {
                    filesSucceeded += 1
                    lastReveal = instanceResult.written.first?.path
                        ?? instanceResult.outputDir
                        ?? resolved.directory.path
                    if resolved.nestedBecauseOfCollision {
                        nestedBecauseOfCollision = true
                    }
                }
            case .failure(let error):
                totalFailed += 1
                host?.postStatusMessage("\(session.sourceDisplayName): \(Self.userFacingGenerateError(error))")
            }
        }

        guard totalWritten > 0 else {
            return .failure(userMessage: totalFailed > 0 ? "No fonts were written." : "No fonts were written.")
        }
        let reveal = lastReveal ?? chosen.path
        let message: String
        if totalFailed > 0 {
            message = "Wrote \(totalWritten) font\(totalWritten == 1 ? "" : "s") from \(filesSucceeded) file\(filesSucceeded == 1 ? "" : "s"); \(totalFailed) failed"
        } else if nestedBecauseOfCollision {
            message = "Wrote \(totalWritten) static font\(totalWritten == 1 ? "" : "s") (created beside the source)"
        } else {
            message = "Wrote \(totalWritten) static font\(totalWritten == 1 ? "" : "s") from \(filesSucceeded) file\(filesSucceeded == 1 ? "" : "s")"
        }
        return .success(message: message, revealPath: reveal)
    }

    private func runGenerate(
        session: InstancerSessionState,
        chosenDirectory: URL,
        folderLabel: String?,
        alreadyScoped: Bool = false
    ) async -> GenerateOutcome {
        let resolved = CommitRequestBuilder.packageExportDirectory(
            chosenDirectory: chosenDirectory,
            sourcePaths: [session.sourcePath],
            folderLabel: folderLabel,
            nestedKind: .staticFonts
        )

        do {
            try FileManager.default.createDirectory(
                at: resolved.directory,
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(userMessage: "Couldn't create output folder: \(error.localizedDescription)")
        }

        let accessed = alreadyScoped ? false : chosenDirectory.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                chosenDirectory.stopAccessingSecurityScopedResource()
            }
        }

        let result = await generate(
            session: session,
            outputDir: resolved.directory,
            overwrite: true
        )

        switch result {
        case .success(let instanceResult):
            let written = instanceResult.written.count
            let failed = instanceResult.errors.count
            let folderName = resolved.directory.lastPathComponent
            if written > 0 {
                let reveal = instanceResult.written.first?.path
                    ?? instanceResult.outputDir
                    ?? resolved.directory.path
                let message: String
                if failed > 0 {
                    message = "Wrote \(written) font\(written == 1 ? "" : "s") to \(folderName); \(failed) failed"
                } else if resolved.nestedBecauseOfCollision {
                    message = "Wrote \(written) static font\(written == 1 ? "" : "s") to \(folderName) (created beside the source)"
                } else {
                    message = "Wrote \(written) static font\(written == 1 ? "" : "s") to \(folderName)"
                }
                return .success(message: message, revealPath: reveal)
            }
            let message = instanceResult.errors.first?.message ?? "No fonts were written."
            return .failure(userMessage: message)
        case .failure(let error):
            return .failure(userMessage: Self.userFacingGenerateError(error))
        }
    }

    /// Directory for the Generate folder panel — only if AppKit can see it.
    /// Passing an inaccessible Downloads path as `directoryURL` triggers a system
    /// “file doesn’t exist” alert even when the font was opened via Open / drop.
    private func accessibleStartDirectory(for session: InstancerSessionState) -> URL? {
        if let bookmark = session.sourceBookmark,
           let scoped = try? SourceFontAccess.resolveURL(bookmark: bookmark) {
            let accessed = scoped.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    scoped.stopAccessingSecurityScopedResource()
                }
            }
            let parent = scoped.deletingLastPathComponent()
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return parent
            }
        }

        guard !session.sourcePath.isEmpty else { return nil }
        let parent = URL(fileURLWithPath: session.sourcePath).deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return parent
    }

    enum GenerateOutcome {
        case success(message: String, revealPath: String)
        case failure(userMessage: String)
    }

    /// Build a request from the current selection and write static fonts via `vfinstance`.
    func generate(
        session: InstancerSessionState,
        outputDir: URL,
        overwrite: Bool
    ) async -> Result<InstanceResult, Error> {
        guard let host else {
            return .failure(InstanceServiceError.helperFailed("Editor host unavailable"))
        }
        guard session.hasSource else {
            return .failure(InstanceServiceError.helperFailed("No font open"))
        }
        guard session.canGenerate else {
            return .failure(
                InstanceServiceError.helperFailed(session.generateBlockedReason ?? "Cannot generate")
            )
        }
        if isGenerateBusy, activeGenerateSessionKey != session.sessionKey {
            return .failure(InstanceServiceError.helperFailed("Another generate is already running"))
        }

        session.isGenerating = true
        activeGenerateSessionKey = session.sessionKey
        session.generateCompletedCount = 0
        session.generatingRowID = nil
        defer {
            session.isGenerating = false
            session.generatingRowID = nil
            session.generateStatus = ""
            if activeGenerateSessionKey == session.sessionKey {
                activeGenerateSessionKey = nil
            }
            if session.loadError == nil, session.hasSource {
                session.statusHint = "Click a badge to isolate · click again for all"
            }
        }

        // Match the table order (opsz → wdth → wght → …), not raw fvar order.
        let selected = session.rows
            .filter { session.selectedIDs.contains($0.id) }
            .sorted { InstancerNaming.compareRows($0, $1, axisTags: session.axisTags) }
        session.generateTotalCount = selected.count
        session.generateStatus = "Preparing \(selected.count) instance\(selected.count == 1 ? "" : "s")…"
        session.statusHint = session.generateStatus

        let axisTags = session.axisTags
        let psPrefix = session.psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let specs: [InstanceSpec] = selected.compactMap { row in
            guard let name = InstancerNaming.resolvedName(for: row) else { return nil }
            var coords: [String: Double] = [:]
            for tag in axisTags {
                coords[tag] = row.coords[tag] ?? InstancerAxisDefaults.value(for: tag)
            }
            let style = InstancerNaming.outputStyleToken(for: row) ?? name.replacingOccurrences(
                of: "\\s+",
                with: "",
                options: .regularExpression
            )
            let postscript: String?
            if psPrefix.isEmpty {
                postscript = style
            } else {
                postscript = "\(psPrefix)-\(style)"
            }
            return InstanceSpec(id: row.id, name: name, coordinates: coords, postscriptName: postscript)
        }

        do {
            let helperSourcePath = try await resolveHelperSourcePath(for: session)
            let request = InstanceRequest(
                sourcePath: helperSourcePath,
                outputDir: outputDir.path,
                dryRun: false,
                psPrefix: psPrefix.isEmpty ? nil : psPrefix,
                keepStat: false,
                overwrite: overwrite,
                instances: specs
            )
            let result = try await host.instanceService.instance(request) { [weak session] event in
                Task { @MainActor in
                    guard let session else { return }
                    self.applyGenerateProgress(event, to: session)
                }
            }
            if result.ok || !result.written.isEmpty {
                session.lastOutputDir = result.outputDir ?? outputDir.path
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    private func resolveHelperSourcePath(for session: InstancerSessionState) async throws -> String {
        if let cached = session.helperCachedPath,
           FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        let bookmark = session.sourceBookmark
            ?? session.fontID.flatMap { host?.sourceBookmarks[$0] }
        let path = session.sourcePath
        let accessID = session.sourceAccessID.isEmpty
            ? Self.helperCacheID(for: session.sessionKey)
            : session.sourceAccessID
        let helperSourcePath = try await Task.detached(priority: .userInitiated) {
            try SourceFontAccess.helperSourcePath(
                bookmark: bookmark,
                fallbackPath: path,
                fontID: accessID
            )
        }.value
        session.helperCachedPath = helperSourcePath
        return helperSourcePath
    }

    private func applyGenerateProgress(_ event: InstanceProgressEvent, to session: InstancerSessionState) {
        let label = event.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (label?.isEmpty == false) ? label! : "instance"
        let step = event.index + 1
        let total = max(event.total, 1)

        switch event.event {
        case "start":
            session.generatingRowID = event.id
            session.generateStatus = "Instancing \(name) (\(step) of \(total))…"
            session.statusHint = session.generateStatus
        case "written":
            if let id = event.id {
                session.selectedIDs.remove(id)
                if session.generatingRowID == id {
                    session.generatingRowID = nil
                }
            }
            session.generateCompletedCount = step
            session.generateStatus = "Wrote \(name) (\(step) of \(total))"
            session.statusHint = session.generateStatus
        case "error":
            // Leave failed rows selected so the user can retry.
            if let id = event.id, session.generatingRowID == id {
                session.generatingRowID = nil
            }
            let detail = event.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let detail, !detail.isEmpty {
                session.generateStatus = "Failed \(name) (\(step) of \(total)): \(detail)"
            } else {
                session.generateStatus = "Failed \(name) (\(step) of \(total))"
            }
            session.statusHint = session.generateStatus
        default:
            break
        }
        objectWillChange.send()
    }

    static func userFacingGenerateError(_ error: Error) -> String {
        switch error {
        case InstanceServiceError.helperNotFound:
            return "Instancer helper not found — vfinstance.py is missing from Tools/vfinstance."
        case let InstanceServiceError.helperUnavailable(path):
            return "Instancer helper unavailable at \(path)."
        case let InstanceServiceError.helperFailed(detail):
            return detail.isEmpty ? "Instancer helper failed." : detail
        case let InstanceServiceError.invalidHelperOutput(detail):
            return "Instancer returned invalid output: \(detail)"
        default:
            return error.localizedDescription
        }
    }
}
