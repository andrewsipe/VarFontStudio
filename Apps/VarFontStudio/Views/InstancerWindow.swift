import AppKit
import SwiftUI
import VarFontCore

struct InstancerWindow: View {
    let windowKey: String
    @EnvironmentObject private var editor: EditorViewModel

    private var session: InstancerSessionState {
        editor.instancer.displaySession(forWindowKey: windowKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let workspace = editor.instancer.workspace(forKey: windowKey), workspace.hasTabs {
                InstancerFileTabBar(windowKey: windowKey)
                Divider()
            }

            InstancerWindowContent(windowKey: windowKey, session: session)
                .environmentObject(session)
                .id(session.sessionKey)
        }
        .frame(minWidth: 880, minHeight: 560)
        .navigationTitle(editor.instancer.windowTitle(forWindowKey: windowKey))
        .background(InstancerWindowConfigurator())
        .background(AuxiliaryWindowOpenBridge())
    }
}

private struct InstancerFileTabBar: View {
    let windowKey: String
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        let workspace = editor.instancer.workspace(forKey: windowKey)
        let tabKeys = workspace?.tabKeys ?? []
        if !tabKeys.isEmpty {
            HStack(spacing: StudioSpacing.controlGap) {
                StudioSectionLabel(title: "File")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StudioSpacing.tightGap) {
                        ForEach(tabKeys, id: \.self) { key in
                            fileChip(sessionKey: key, workspace: workspace)
                        }
                    }
                }
            }
            .padding(.horizontal, InstancerLayout.horizontalPadding)
            .padding(.vertical, StudioSpace.x2)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func fileChip(sessionKey: String, workspace: InstancerWorkspace?) -> some View {
        let session = editor.instancer.session(forKey: sessionKey)
        let isSelected = workspace?.selectedTabKey == sessionKey
        let title = session?.sourceDisplayName.isEmpty == false
            ? (session?.sourceDisplayName ?? "Font")
            : "Font"
        let isLoading = session?.isLoading == true
        let isGenerating = session?.isGenerating == true

        Button {
            editor.instancer.selectTab(sessionKey: sessionKey, windowKey: windowKey)
        } label: {
            StudioTabChip(isSelected: isSelected) {
                Text(title)
                    .font(StudioTypography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            } trailing: {
                HStack(spacing: StudioSpacing.tightGap) {
                    if isLoading || isGenerating {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct InstancerWindowContent: View {
    let windowKey: String
    @ObservedObject var session: InstancerSessionState
    @EnvironmentObject private var editor: EditorViewModel

    @State private var toastMessage: String?
    @State private var toastRevealPath: String?
    @State private var statusOverride: String?

    private var tabCount: Int {
        editor.instancer.workspace(forKey: windowKey)?.tabKeys.count ?? 0
    }

    private var canGenerateAll: Bool {
        guard let workspace = editor.instancer.workspace(forKey: windowKey) else { return false }
        return workspace.tabKeys.contains { key in
            editor.instancer.session(forKey: key)?.canGenerate == true
        } && !editor.instancer.isGenerateBusy
    }

    /// Return should commit inline edits — not trigger Generate.
    private var suppressGenerateShortcut: Bool {
        session.editingRowID != nil || session.showComposer
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryChrome
            toolRow
            headline
            rowList
            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                HStack(spacing: StudioSpace.x3) {
                    Text(toastMessage)
                        .font(StudioTypography.bodyMedium)
                    if let toastRevealPath {
                        StudioFlatButton(title: "Show in Finder", size: .compact) {
                            NSWorkspace.shared.selectFile(
                                toastRevealPath,
                                inFileViewerRootedAtPath: ""
                            )
                        }
                    }
                }
                .padding(.horizontal, StudioSpace.x3)
                .padding(.vertical, StudioSpace.x2)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: StudioRadius.row))
                .padding(.bottom, StudioSpace.x6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Summary (Review-matched top chrome)

    private var summaryChrome: some View {
        VStack(alignment: .leading, spacing: InstancerLayout.chromeSectionGap) {
            HStack(alignment: .top, spacing: StudioSpace.x4) {
                VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    Text("Instance")
                        .font(StudioTypography.emphasis)
                    Text("Generate static fonts from named instances — names follow fvar, with STAT as a fallback.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                    sourceBanner
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                actionBar
            }

            addInstanceBar

            filterBadges
        }
        .padding(.horizontal, InstancerLayout.horizontalPadding)
        .padding(.top, StudioSpace.x4)
        .padding(.bottom, InstancerLayout.chromeSectionGap)
    }

    private var actionBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioFlatButton(
                title: "Generate All…",
                isEnabled: canGenerateAll,
                help: generateAllHelp
            ) {
                Task { await presentGenerateAll() }
            }

            generateThisFileButton
        }
    }

    @ViewBuilder
    private var generateThisFileButton: some View {
        StudioFlatButton(
            title: "Generate This File…",
            role: .primary,
            isEnabled: session.canGenerate && !session.isGenerating && !editor.instancer.isGenerateBusy,
            isDefaultAction: !suppressGenerateShortcut,
            help: generateHelp
        ) {
            Task { await presentGenerate() }
        }
    }

    private var sourceBanner: some View {
        HStack(spacing: StudioSpacing.rowGap) {
            Text("Source")
                .font(StudioTypography.meta)
                .foregroundStyle(.secondary)
            Text(session.hasSource ? session.sourceDisplayName : "None")
                .font(StudioTypography.monoMeta)
                .foregroundStyle(session.hasSource ? .primary : .tertiary)
                .padding(.horizontal, StudioSpacing.pillHorizontalInset)
                .padding(.vertical, StudioSpace.x0_5)
                .background(StudioColors.surfaceLight, in: RoundedRectangle(cornerRadius: StudioRadius.control))
            if session.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text(session.loadStatus.isEmpty ? "Reading…" : session.loadStatus)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if session.isStudioExport {
                Text("Studio export")
                    .font(StudioTypography.pillLabel)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, StudioSpacing.pillHorizontalInset)
                    .padding(.vertical, StudioSpacing.instanceRowVertical)
                    .background(
                        StudioColors.editedFill,
                        in: RoundedRectangle(cornerRadius: 3)
                    )
            }
            if session.fontID != nil, session.projectID != nil {
                StudioPlainLinkButton(
                    title: fixStudioTitle,
                    help: fixStudioHelp
                ) {
                    editor.instancer.focusStudioForNaming(session: session)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Collapsed: Add Instance toggle. Expanded: custom instance composer with Cancel.
    private var addInstanceBar: some View {
        VStack(alignment: .leading, spacing: StudioSpace.x1_5) {
            if session.showComposer {
                composerFields
            } else {
                HStack(spacing: StudioSpacing.controlGap) {
                    StudioFlatButton(
                        title: "Add Instance…",
                        isEnabled: session.hasSource && !session.isLoading,
                        help: "Add a custom instance at any coordinate — not written back to the source font"
                    ) {
                        session.showComposer = true
                        session.resetComposer()
                    }
                    Spacer(minLength: 0)
                }
            }
            if let warning = session.composerWarning {
                HStack(spacing: StudioSpace.x2) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(StudioTypography.meta)
                        .foregroundStyle(StudioColors.warningForeground)
                    Text(warning)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if session.composerForcePending {
                        StudioFlatButton(title: "Add anyway", size: .compact) {
                            session.composerForcePending = false
                            commitCustomInstance(force: true)
                        }
                    }
                    StudioDismissButton(scale: .chip, style: .fill, help: "Dismiss warning") {
                        session.composerWarning = nil
                        session.composerForcePending = false
                    }
                }
                .padding(StudioSpace.x2)
                .background(StudioColors.warningFill, in: RoundedRectangle(cornerRadius: StudioRadius.control))
            }
        }
        .padding(StudioSpace.x2)
        .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: StudioRadius.row))
    }

    private var composerFields: some View {
        let draftBits = session.styleBits(for: composerFilledCoords)
        let draftStyle = InstancerNaming.ribbi(isBold: draftBits.bold, isItalic: draftBits.italic)
        let draftName = session.composerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let draftOutput: String = {
            guard !draftName.isEmpty else { return "—" }
            let token = draftName.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            let prefix = session.psPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            return prefix.isEmpty ? "\(token).ttf" : "\(prefix)-\(token).ttf"
        }()

        return HStack(spacing: StudioSpacing.controlGap) {
            StudioFlatButton(title: "Cancel", help: "Close the custom instance row") {
                dismissComposer()
            }

            StudioTextField(
                placeholder: "Name — e.g. SemiBold",
                text: $session.composerName,
                font: StudioTypography.bodyMedium,
                rowHeight: StudioFieldMetrics.bodyMediumRowHeight
            )
            .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)

            ForEach(session.axisTags, id: \.self) { tag in
                HStack(spacing: StudioSpace.x1) {
                    Text(tag)
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                    StudioNumberField(
                        placeholder: tag == "wght" ? "required" : "0",
                        value: Binding(
                            get: { session.composerCoords[tag] },
                            set: { session.composerCoords[tag] = $0 }
                        ),
                        font: StudioTypography.monoMeta,
                        rowHeight: StudioFieldMetrics.monoValueRowHeight
                    )
                    .frame(width: tag == "wght" ? 78 : 64)
                }
            }

            Text(draftStyle.rawValue)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: InstancerLayout.styleColumnWidth, alignment: .leading)
                .help(composerStyleHelp(draftStyle))

            Text(draftOutput)
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 120, maxWidth: 220, alignment: .leading)
                .help(draftOutput == "—" ? "Output filename preview" : draftOutput)

            Spacer(minLength: 0)
            StudioFlatButton(
                title: session.composerForcePending ? "Confirm" : "Add",
                role: .primary
            ) {
                addCustomInstance()
            }
        }
    }

    /// Filled composer coords (defaults for missing axes) used for live Style preview.
    private var composerFilledCoords: [String: Double] {
        var coords = session.composerCoords
        for tag in session.axisTags where coords[tag] == nil {
            coords[tag] = InstancerAxisDefaults.value(for: tag)
        }
        return coords
    }

    private func composerStyleHelp(_ style: InstancerRIBBI) -> String {
        switch style {
        case .bold, .boldItalic:
            if let wght = session.boldLinkedWght {
                return "Style follows axes — Bold when wght is the Format 3 link target (\(InstancerNaming.formatCoord(wght)))."
            }
            return "Style follows axes — Bold when wght matches the Format 3 weight link."
        case .italic:
            return "Style follows axes — Italic when ital is 1 or slnt is non-zero."
        case .regular:
            return "Style follows axes — Regular unless wght is the Bold link target or the instance is italic."
        }
    }

    private func dismissComposer() {
        session.showComposer = false
        session.resetComposer()
    }

    private var filterBadges: some View {
        let counts = session.filterCounts()
        return HStack(spacing: InstancerLayout.filterBadgeGap) {
            filterBadge(.all, count: counts.all)
            filterBadge(.clean, count: counts.clean)
            if counts.custom > 0 {
                filterBadge(.custom, count: counts.custom, tint: StudioColors.customForeground)
            }
            if counts.collision > 0 {
                filterBadge(.collision, count: counts.collision, tint: StudioColors.collisionForeground)
            }
            if counts.attention > 0 {
                filterBadge(.attention, count: counts.attention, tint: StudioColors.warningForeground)
            }
            Spacer(minLength: 0)
        }
        .onChange(of: counts.custom) { _, value in
            if value == 0, session.filterKind == .custom { session.filterKind = .all }
        }
        .onChange(of: counts.collision) { _, value in
            if value == 0, session.filterKind == .collision { session.filterKind = .all }
        }
        .onChange(of: counts.attention) { _, value in
            if value == 0, session.filterKind == .attention { session.filterKind = .all }
        }
    }

    private func filterBadge(_ kind: InstancerFilterKind, count: Int, tint: Color? = nil) -> some View {
        InstancerFilterBadgeButton(
            kind: kind,
            count: count,
            tint: tint,
            session: session,
            statusOverride: $statusOverride
        )
    }

    private var fixStudioTitle: String {
        let n = session.sourceAttentionCount
        return n > 0 ? "Fix in Studio (\(n))" : "Fix in Studio"
    }

    private var generateHelp: String {
        if session.isGenerating {
            return session.generateStatus.isEmpty ? "Generating static fonts…" : session.generateStatus
        }
        if editor.instancer.isGenerateBusy {
            return "Another font is still generating statics"
        }
        return session.generateBlockedReason
            ?? "Choose a folder. Picking the source folder creates a Static subfolder."
    }

    private var generateAllHelp: String {
        if editor.instancer.isGenerateBusy {
            return "Another font is still generating statics"
        }
        if !canGenerateAll {
            return "No file tabs are ready to generate"
        }
        if tabCount > 1 {
            return "Generate selected instances for all \(tabCount) files in this window"
        }
        return "Generate selected instances for every file tab"
    }

    private var fixStudioHelp: String {
        if session.fontID == nil || session.projectID == nil {
            return "Available when this font is open in a Studio project"
        }
        if session.customCount > 0 {
            return "\(session.customCount) custom instance(s) would be suggested as new Axis Tree stops"
        }
        return "Open this file in Studio"
    }

    // MARK: - Tool row / headline / list

    private var toolRow: some View {
        HStack(spacing: StudioSpace.x3) {
            StudioSearchField(
                text: $session.filterText,
                placeholder: "Search"
            )
            .frame(maxWidth: 220)
            .disabled(!session.hasSource || session.isLoading)
            .opacity(session.hasSource && !session.isLoading ? 1 : 0.45)

            Text("\(session.visibleRows.count) of \(session.rows.count) rows shown")
                .font(StudioTypography.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer(minLength: StudioSpace.x3)

            psPrefixControls
        }
        .padding(.horizontal, InstancerLayout.horizontalPadding)
        .padding(.vertical, InstancerLayout.toolRowVerticalPadding)
        .frame(minHeight: InstancerLayout.toolRowMinHeight)
        .background(StudioColors.surfaceSubtle.opacity(0.5))
        .overlay(alignment: .bottom) {
            Rectangle().fill(StudioColors.surfaceStroke).frame(height: 0.5)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(StudioColors.surfaceStroke).frame(height: 0.5)
        }
    }

    private var psPrefixControls: some View {
        HStack(spacing: StudioSpace.x2) {
            Text("PS prefix")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            StudioTextField(
                placeholder: "Prefix",
                text: $session.psPrefix,
                font: StudioTypography.monoMeta,
                rowHeight: StudioFieldMetrics.monoValueRowHeight
            )
            .frame(width: 140, alignment: .leading)
            .disabled(!session.hasSource || session.isLoading)
            if session.psPrefix != session.psInferred {
                StudioPlainLinkButton(title: "Reset") {
                    session.psPrefix = session.psInferred
                }
            } else {
                Text("from \(session.psSourceLabel)")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .layoutPriority(1)
    }

    private var headline: some View {
        HStack(spacing: StudioSpace.x3) {
            if session.hasSource, !session.isLoading, !session.isGenerating {
                StudioPlainLinkButton(title: "Select All", role: .secondary) {
                    session.visibleRows.forEach { session.selectedIDs.insert($0.id) }
                }
                StudioPlainLinkButton(title: "Deselect All", role: .secondary) {
                    session.visibleRows.forEach { session.selectedIDs.remove($0.id) }
                }
            }

            Text(headlineText)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, InstancerLayout.horizontalPadding)
        .padding(.vertical, InstancerLayout.toolRowVerticalPadding)
        .frame(minHeight: InstancerLayout.toolRowMinHeight, alignment: .leading)
    }

    private var headlineText: String {
        if session.isGenerating {
            let done = session.generateCompletedCount
            let total = max(session.generateTotalCount, 1)
            if session.generateStatus.isEmpty {
                return "Generating static fonts… \(done) of \(total)"
            }
            return session.generateStatus
        }
        if session.isLoading {
            return session.loadStatus.isEmpty ? "Reading font…" : session.loadStatus
        }
        if !session.hasSource {
            return "No font open"
        }
        return "Named instances — \(session.selectedCount) selected"
    }

    private var rowList: some View {
        Group {
            if session.isLoading {
                VStack(spacing: StudioSpace.x3) {
                    ProgressView()
                        .controlSize(.regular)
                    Text(session.loadStatus.isEmpty ? "Reading font…" : session.loadStatus)
                        .font(StudioTypography.bodyMedium)
                    Text("Named instances appear here when the font finishes loading.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.loadError {
                ContentUnavailableView {
                    Label("Couldn’t read font", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    if let projectID = session.projectID, let fontID = session.fontID {
                        StudioFlatButton(title: "Reload from Project") {
                            editor.instancer.reloadSessionAfterExport(projectID: projectID, fontID: fontID)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !session.hasSource {
                GeometryReader { geo in
                    let columns = InstancerLayout.columnWidths(
                        totalWidth: geo.size.width,
                        axisCount: max(session.axisTags.count, 2)
                    )
                    VStack(spacing: 0) {
                        headerRow(columns: columns)
                        Text(StudioEmptyCopy.instancerListHint)
                            .font(StudioTypography.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(.horizontal, InstancerLayout.horizontalPadding)
                            .padding(.vertical, StudioSpace.x6)
                    }
                }
            } else if session.rows.isEmpty {
                ContentUnavailableView(
                    "No instances",
                    systemImage: "square.stack.3d.up.slash",
                    description: Text("This font has no fvar named instances.")
                )
            } else if session.visibleRows.isEmpty {
                ContentUnavailableView(
                    "No instances match",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try another filter or clear the search.")
                )
            } else {
                GeometryReader { geo in
                    let columns = InstancerLayout.columnWidths(
                        totalWidth: geo.size.width,
                        axisCount: session.axisTags.count
                    )
                    VStack(spacing: 0) {
                        headerRow(columns: columns)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(session.visibleRows) { row in
                                    InstancerRowView(row: row, session: session, columns: columns)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerRow(columns: InstancerLayout.ColumnWidths) -> some View {
        HStack(spacing: InstancerLayout.columnGap) {
            Color.clear
                .frame(width: InstancerLayout.selectColumnWidth, height: 1)
            Text("Name")
                .frame(width: columns.name, alignment: .leading)
            ForEach(session.axisTags, id: \.self) { tag in
                Text(tag)
                    .frame(width: InstancerLayout.axisColumnWidth, alignment: .trailing)
            }
            Text("Style")
                .frame(width: InstancerLayout.styleColumnWidth, alignment: .leading)
                .padding(.leading, InstancerLayout.textColumnLeadingGap)
            Text("Output")
                .frame(width: columns.output, alignment: .leading)
                .padding(.leading, InstancerLayout.textColumnLeadingGap)
            Color.clear
                .frame(width: InstancerLayout.flagColumnWidth, height: 1)
        }
        .font(StudioTypography.columnLabel)
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, InstancerLayout.horizontalPadding)
        .padding(.vertical, StudioSpace.x1) // 4
        .fixedSize(horizontal: false, vertical: true)
        .background(SaveReviewLayout.phaseHeaderBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StudioColors.surfaceStroke)
                .frame(height: 0.5)
        }
    }

    private var statusBar: some View {
        Text(statusBarText)
            .font(StudioTypography.meta)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InstancerLayout.horizontalPadding)
            .frame(height: InstancerLayout.statusBarHeight)
            .background(StudioColors.surfaceSubtle)
            .overlay(alignment: .top) { Divider() }
    }

    private var statusBarText: String {
        if let statusOverride { return statusOverride }
        if session.isGenerating {
            return session.generateStatus.isEmpty ? "Generating…" : session.generateStatus
        }
        if session.isLoading {
            return session.loadStatus.isEmpty ? "Reading font…" : session.loadStatus
        }
        return session.statusHint
    }

    // MARK: - Generate (Review-style folder panel)

    private func presentGenerate() async {
        guard let outcome = await editor.instancer.presentGenerate(session: session) else { return }
        switch outcome {
        case let .success(message, revealPath):
            showToast(message, revealPath: revealPath)
            NSWorkspace.shared.selectFile(revealPath, inFileViewerRootedAtPath: "")
        case let .failure(userMessage):
            showToast(userMessage, revealPath: nil)
        }
    }

    private func presentGenerateAll() async {
        guard let outcome = await editor.instancer.presentGenerateAll(windowKey: windowKey) else { return }
        switch outcome {
        case let .success(message, revealPath):
            showToast(message, revealPath: revealPath)
            NSWorkspace.shared.selectFile(revealPath, inFileViewerRootedAtPath: "")
        case let .failure(userMessage):
            showToast(userMessage, revealPath: nil)
        }
    }

    private func showToast(_ message: String, revealPath: String? = nil) {
        withAnimation {
            toastMessage = message
            toastRevealPath = revealPath
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            withAnimation {
                toastMessage = nil
                toastRevealPath = nil
            }
        }
    }

    private func addCustomInstance() {
        let name = session.composerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasWght = session.composerCoords["wght"] != nil
        guard !name.isEmpty, hasWght || !session.axisTags.contains("wght") else {
            session.composerWarning = "Name and wght are required."
            return
        }
        commitCustomInstance(force: session.composerForcePending)
    }

    private func commitCustomInstance(force: Bool) {
        let name = session.composerName.trimmingCharacters(in: .whitespacesAndNewlines)
        var coords = session.composerCoords
        for tag in session.axisTags where coords[tag] == nil {
            coords[tag] = InstancerAxisDefaults.value(for: tag)
        }
        let key = InstancerNaming.coordsKey(coords, axisTags: session.axisTags)
        if !force, let match = session.rows.first(where: {
            InstancerNaming.coordsKey($0.coords, axisTags: session.axisTags) == key
        }) {
            let matchName = InstancerNaming.resolvedName(for: match) ?? match.id
            session.composerWarning = "This coordinate matches “\(matchName)” already in the list — probably the instance you're after."
            session.composerForcePending = true
            return
        }
        let nextID = "custom-\(UUID().uuidString)"
        let bits = session.styleBits(for: coords)
        let row = InstancerRow(
            id: nextID,
            origin: .custom,
            fvarName: name,
            fvarUsable: true,
            statName: nil,
            coords: coords,
            isBold: bits.bold,
            isItalic: bits.italic
        )
        session.rows.append(row)
        session.selectedIDs.insert(nextID)
        session.showComposer = false
        session.resetComposer()
    }
}

// MARK: - Row

private struct InstancerRowView: View {
    let row: InstancerRow
    @ObservedObject var session: InstancerSessionState
    let columns: InstancerLayout.ColumnWidths
    @EnvironmentObject private var editor: EditorViewModel
    @State private var isHovered = false

    private var selected: Bool { session.selectedIDs.contains(row.id) }
    private var isActivelyGenerating: Bool { session.generatingRowID == row.id }
    private var collision: InstancerCollisionKind? { session.collisions[row.id] }
    private var willFail: Bool { InstancerNaming.willFail(row) }
    private var fallback: Bool { InstancerNaming.usesSTATFallback(row) }
    private var overridden: Bool { row.nameOverride != nil }

    var body: some View {
        HStack(spacing: InstancerLayout.columnGap) {
            Group {
                if isActivelyGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: InstancerLayout.selectColumnWidth, height: InstancerLayout.selectColumnWidth)
                } else {
                    StudioIncludeCheckbox(isOn: selected) {
                        toggleSelection()
                    }
                    .disabled(session.isGenerating)
                }
            }
            .frame(width: InstancerLayout.selectColumnWidth)

            nameCell
                .frame(width: columns.name, alignment: .leading)

            ForEach(session.axisTags, id: \.self) { tag in
                coordCell(tag: tag)
                    .frame(width: InstancerLayout.axisColumnWidth, alignment: .trailing)
            }

            Text(InstancerNaming.ribbi(for: row).rawValue)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: InstancerLayout.styleColumnWidth, alignment: .leading)
                .padding(.leading, InstancerLayout.textColumnLeadingGap)

            Text(InstancerNaming.outputFileName(psPrefix: session.psPrefix, row: row) ?? "—")
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: columns.output, alignment: .leading)
                .padding(.leading, InstancerLayout.textColumnLeadingGap)
                .help(InstancerNaming.outputFileName(psPrefix: session.psPrefix, row: row) ?? "")

            flagCell
                .frame(width: InstancerLayout.flagColumnWidth, alignment: .leading)
        }
        .padding(.horizontal, InstancerLayout.horizontalPadding)
        .padding(.vertical, StudioSpace.x2)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.55)
        }
        .opacity(session.isGenerating && !selected && !isActivelyGenerating ? 0.55 : 1)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            guard !session.isGenerating else { return }
            toggleSelection()
        }
    }

    private func toggleSelection() {
        if selected { session.selectedIDs.remove(row.id) }
        else { session.selectedIDs.insert(row.id) }
    }

    @ViewBuilder
    private var nameCell: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.instanceRowGap) {
            HStack(spacing: StudioSpacing.tagHorizontalInset) {
                if session.editingRowID == row.id {
                    StudioTextField(
                        placeholder: "Name",
                        text: Binding(
                            get: { row.nameOverride ?? InstancerNaming.resolvedName(for: row) ?? "" },
                            set: { newValue in
                                session.updateRow(row.id) { $0.nameOverride = newValue }
                            }
                        ),
                        font: StudioTypography.bodyMedium,
                        rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                        onSubmit: { session.editingRowID = nil },
                        onCancel: { session.editingRowID = nil }
                    )
                } else {
                    Text(InstancerNaming.resolvedName(for: row) ?? "—")
                        .font(StudioTypography.bodyMedium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if overridden {
                        Circle()
                            .fill(StudioColors.editedForeground)
                            .frame(width: 6, height: 6)
                    }
                    StudioToolbarIconButton(
                        systemName: StudioSymbols.edit,
                        help: "Edit instance name for this session"
                    ) {
                        session.editingRowID = row.id
                    }
                }
            }
            if let note = subtitle {
                Text(note.text)
                    .font(StudioTypography.meta)
                    .foregroundStyle(note.color)
            }
        }
    }

    private var subtitle: (text: String, color: Color)? {
        if overridden {
            return ("overridden for this static file", Color.secondary.opacity(0.7))
        }
        if willFail {
            return ("no usable name — fvar incomplete and no STAT value either. This will fail to generate.", StudioColors.errorForeground)
        }
        if fallback {
            return ("fvar incomplete — using STAT “\(row.statName ?? "")”", StudioColors.warningForeground)
        }
        switch collision {
        case .exact:
            return ("exact duplicate of another row — same name, same coordinates", StudioColors.errorForeground)
        case .identical:
            return ("same coordinates as another row — will be an identical design under a different name", StudioColors.errorForeground)
        case .collision:
            return ("same output as another row", StudioColors.collisionForeground)
        case nil:
            return nil
        }
    }

    @ViewBuilder
    private func coordCell(tag: String) -> some View {
        let value = row.coords[tag] ?? InstancerAxisDefaults.value(for: tag)
        if row.origin == .custom {
            StudioBoundNumberField(
                value: Binding(
                    get: { session.rows.first(where: { $0.id == row.id })?.coords[tag] ?? value },
                    set: { newValue in
                        session.updateRowCoords(row.id, tag: tag, value: newValue)
                    }
                ),
                font: StudioTypography.monoMeta,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                alignment: .trailing
            )
        } else {
            Text(InstancerNaming.formatCoord(value))
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var flagCell: some View {
        HStack(spacing: StudioSpacing.instanceRowVertical) {
            if row.origin == .custom {
                if let collision {
                    collisionFlagView(collision)
                } else {
                    StudioFlagLabel(symbol: "＋", text: "custom", tint: StudioColors.customForeground)
                }
                Text("·").foregroundStyle(.tertiary)
                StudioPlainLinkButton(title: "Remove", font: StudioTypography.meta) {
                    session.rows.removeAll { $0.id == row.id }
                    session.selectedIDs.remove(row.id)
                }
            } else if overridden {
                StudioPlainLinkButton(title: "Revert", font: StudioTypography.meta) {
                    session.updateRow(row.id) { $0.nameOverride = nil }
                }
            } else if let collision {
                collisionFlagView(collision)
            } else if willFail {
                StudioFlagLabel(symbol: "✕", text: "will fail", tint: StudioColors.errorForeground)
                Text("·").foregroundStyle(.tertiary)
                StudioPlainLinkButton(title: "Fix in Studio", font: StudioTypography.meta) {
                    editor.instancer.focusStudioForNaming(session: session)
                }
            } else if fallback {
                StudioFlagLabel(symbol: "⚠", text: "fallback", tint: StudioColors.warningForeground)
                Text("·").foregroundStyle(.tertiary)
                StudioPlainLinkButton(title: "Fix in Studio", font: StudioTypography.meta) {
                    editor.instancer.focusStudioForNaming(session: session)
                }
            }
        }
        .font(StudioTypography.meta)
    }

    private func collisionFlagView(_ kind: InstancerCollisionKind) -> some View {
        let tint = kind == .collision ? StudioColors.collisionForeground : StudioColors.errorForeground
        let label: String = {
            switch kind {
            case .exact: return "exact duplicate"
            case .identical: return "identical design"
            case .collision: return "collision"
            }
        }()
        return StudioFlagLabel(symbol: "◆", text: label, tint: tint)
    }

    private var rowBackground: some View {
        let tint: Color? = {
            if willFail || collision == .exact || collision == .identical { return StudioColors.errorForeground }
            if collision == .collision { return StudioColors.collisionForeground }
            if row.origin == .custom && !overridden { return StudioColors.customForeground }
            if fallback && !overridden { return StudioColors.warningForeground }
            return nil
        }()
        return ZStack(alignment: .leading) {
            // Full-bleed table chrome — not rounded, so hover/selection reads as a grid row.
            if isActivelyGenerating {
                Rectangle().fill(StudioColors.selectionFill)
            } else if selected {
                Rectangle().fill(StudioColors.selectionFill)
            }
            if isHovered {
                Rectangle().fill(
                    selected || isActivelyGenerating
                        ? StudioColors.selectionNeutralFill
                        : StudioColors.hoverFill
                )
            }
            if let tint {
                HStack(spacing: 0) {
                    StudioSemanticLeadingStripe(color: tint)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct InstancerFilterBadgeButton: View {
    let kind: InstancerFilterKind
    let count: Int
    var tint: Color?
    @ObservedObject var session: InstancerSessionState
    @Binding var statusOverride: String?

    var body: some View {
        let isolated = session.filterKind == kind && kind != .all
        let dimmed = session.filterKind != .all && session.filterKind != kind
        let accent = tint ?? Color.primary
        Button {
            if session.filterKind == kind && kind != .all {
                session.filterKind = .all
            } else {
                session.filterKind = kind
            }
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                if kind == .custom || kind == .collision || kind == .attention {
                    Text("◆")
                        .font(StudioTypography.filterBadgeLabel)
                        .foregroundStyle(accent)
                }
                Text("\(kind.title.uppercased()) \(count)")
                    .font(StudioTypography.filterBadgeLabel)
                    .tracking(0.3)
            }
            .foregroundStyle(dimmed ? AnyShapeStyle(.tertiary) : AnyShapeStyle(accent))
            .padding(.horizontal, StudioSpacing.pillHorizontalInset)
            .padding(.vertical, StudioSpacing.instanceRowVertical)
            .background {
                if isolated {
                    RoundedRectangle(cornerRadius: StudioRadius.small).fill(accent.opacity(0.16))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: StudioRadius.small)
                    .strokeBorder(
                        isolated ? accent.opacity(0.45) : (dimmed ? Color.clear : StudioColors.selectionNeutralFillStrong),
                        lineWidth: isolated ? StudioStroke.regular : StudioStroke.hairline
                    )
            }
            .opacity(dimmed ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: StudioRadius.small),
            isEnabled: !isolated
        )
        .onHover { hovering in
            statusOverride = hovering ? kind.hint : nil
        }
    }
}

private struct InstancerWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.identifier = NSUserInterfaceItemIdentifier(InstancerWindowLifecycle.identifier)
                window.isRestorable = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.identifier = NSUserInterfaceItemIdentifier(InstancerWindowLifecycle.identifier)
            nsView.window?.isRestorable = false
        }
    }
}
