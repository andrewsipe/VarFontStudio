import AppKit
import SwiftUI
import VarFontCore

// MARK: - Modal sheet (Export flow)

struct CommitDiffSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: CommitPreflightSession

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            CommitDiffReviewView(session: session, fillsAvailableHeight: true) {
                SaveReviewActionBar(
                    session: session,
                    projectID: session.projectID,
                    includeCancel: true
                )
            }
            .frame(maxHeight: .infinity)
        }
        .padding(StudioSpacing.contentInset)
        .frame(width: 900, height: 680)
    }
}

// MARK: - Shared Review actions

private struct SaveReviewActionBar: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: CommitPreflightSession
    let projectID: String
    var includeCancel: Bool = false

    private var canExportToRememberedPath: Bool {
        editor.canSaveToRememberedPath(forProjectID: projectID, fontID: session.fontID)
    }

    private var showsExportAll: Bool {
        editor.fontsForSaveReview(projectID: projectID).count > 1
    }

    private var isLoading: Bool {
        editor.isSaveReviewLoading(forProjectID: projectID, fontID: session.fontID)
    }

    private var canRefresh: Bool {
        editor.canPreviewSaveReview(forProjectID: projectID, fontID: session.fontID)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: StudioSpacing.controlGap) {
            HStack(spacing: StudioSpacing.controlGap) {
                Button {
                    editor.refreshCommitDiffPreview(forProjectID: projectID, fontID: session.fontID)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .studioHoverIcon()
                .disabled(!canRefresh || isLoading)
                .help("Re-read the font on disk and rebuild the diff")

                StudioFlatButton(title: "Save Project", isEnabled: editor.canSaveProject) {
                    editor.saveProject()
                }
            }

            HStack(spacing: StudioSpacing.controlGap) {
                if includeCancel {
                    StudioFlatButton(title: "Cancel") {
                        editor.dismissCommitDiffSheet()
                        dismiss()
                    }
                }

                if showsExportAll {
                    StudioFlatButton(
                        title: "Export All…",
                        role: .primary,
                        isEnabled: session.preflight.ok && !editor.isSaveActionBlocked,
                        isDefaultAction: true,
                        help: "Export all files in this project to a folder. Picking the source folder creates a Patched subfolder."
                    ) {
                        editor.saveAllFiles(inProjectID: projectID)
                    }

                    StudioFlatButton(
                        title: "Export This File…",
                        isEnabled: session.preflight.ok && !editor.isSaveActionBlocked,
                        help: "Choose a path for the selected file only"
                    ) {
                        editor.presentSavePanel(for: session)
                    }
                } else if canExportToRememberedPath {
                    StudioFlatButton(
                        title: "Export As…",
                        isEnabled: session.preflight.ok && !editor.isSaveActionBlocked,
                        help: "Choose a new path for this font"
                    ) {
                        editor.presentSavePanel(for: session)
                    }

                    StudioFlatButton(
                        title: "Export",
                        role: .primary,
                        isEnabled: session.preflight.ok && !editor.isSaveActionBlocked,
                        isDefaultAction: true,
                        help: "Write to the last export path"
                    ) {
                        editor.save(session: session)
                    }
                } else {
                    StudioFlatButton(
                        title: "Export…",
                        role: .primary,
                        isEnabled: session.preflight.ok && !editor.isSaveActionBlocked,
                        isDefaultAction: true,
                        help: "Choose a path for the exported font"
                    ) {
                        editor.presentSavePanel(for: session)
                    }
                }
            }
        }
    }
}

// MARK: - Review window

private struct SaveReviewFileTabBar: View {
    let projectID: String
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        let fonts = editor.fontsForSaveReview(projectID: projectID)
        if fonts.count > 1 {
            HStack(spacing: StudioSpacing.controlGap) {
                StudioSectionLabel(title: "File")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StudioSpacing.tightGap) {
                        ForEach(fonts) { font in
                            fileChip(font)
                        }
                    }
                }
            }
            .padding(.horizontal, SaveReviewLayout.horizontalPadding)
            .padding(.vertical, StudioSpace.x2)
            .background(.bar)
        }
    }

    private func fileChip(_ font: FontDocument) -> some View {
        let isSelected = editor.saveReviewSelectedFontID(forProjectID: projectID) == font.id
        let isLoading = editor.isSaveReviewLoading(forProjectID: projectID, fontID: font.id)

        return Button {
            editor.selectSaveReviewFont(projectID: projectID, fontID: font.id)
        } label: {
            StudioTabChip(isSelected: isSelected) {
                Text(editor.fontBasename(for: font))
                    .font(StudioTypography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            } trailing: {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .capsule)
        .disabled(!editor.canPreviewSaveReview(forProjectID: projectID, fontID: font.id))
    }
}

struct SaveReviewWindow: View {
    let projectID: String
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    private var selectedFontID: String? {
        editor.saveReviewSelectedFontID(forProjectID: projectID)
    }

    private var session: CommitPreflightSession? {
        editor.saveReviewSession(forProjectID: projectID)
    }

    private var isLoadingCurrentFile: Bool {
        guard let selectedFontID else { return false }
        return editor.isSaveReviewLoading(forProjectID: projectID, fontID: selectedFontID)
    }

    var body: some View {
        VStack(spacing: 0) {
            SaveReviewFileTabBar(projectID: projectID)
            if editor.fontsForSaveReview(projectID: projectID).count > 1 {
                Divider()
            }

            if let error = editor.saveReview.persistentSaveError {
                HStack(alignment: .top, spacing: StudioSpacing.controlGap) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(StudioTypography.caption)
                        .foregroundStyle(StudioColors.errorForeground)
                        .padding(.top, StudioSpacing.warningGlyphTopNudge)
                    VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                        Text("Cannot export")
                            .font(StudioTypography.sectionLabel)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(StudioTypography.caption)
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                    StudioDismissButton(scale: .toolbar, help: "Dismiss") {
                        editor.dismissPersistentSaveError()
                    }
                }
                .padding(StudioSpacing.contentInset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: StudioRadius.chip)
                        .strokeBorder(StudioColors.errorStroke, lineWidth: StudioStroke.regular)
                )
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.top, StudioSpace.x2)
            }

            if let session {
                VStack(spacing: 0) {
                    if session.preflight.ok {
                        CommitDiffReviewView(session: session, fillsAvailableHeight: true) {
                            SaveReviewActionBar(session: session, projectID: projectID)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
                            SaveReviewActionBar(session: session, projectID: projectID)
                            ScrollView {
                                VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
                                    preflightFailureHeader(session: session)
                                    if !session.preflight.errors.isEmpty {
                                        preflightErrorsCard(session.preflight.errors)
                                    }
                                    if !session.preflight.warnings.isEmpty {
                                        preflightWarningsCard(session.preflight.warnings)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, SaveReviewLayout.horizontalPadding)
                        .padding(.vertical, StudioSpacing.contentInset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            } else if isLoadingCurrentFile {
                VStack(spacing: StudioSpacing.controlGap) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Building review…")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StudioSpacing.controlGap) {
                    Text("No preview loaded yet.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                    StudioPlainLinkButton(
                        title: "Refresh",
                        role: .accent,
                        help: "Re-read the font on disk and rebuild the diff"
                    ) {
                        refreshCurrentFile()
                    }
                    .disabled(!canRefreshCurrentFile)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 920, minHeight: 680)
        .navigationTitle(editor.saveReviewWindowTitle(forProjectID: projectID))
        .background(SaveReviewWindowConfigurator())
        .overlay {
            if editor.isBusy {
                ZStack {
                    Color.black.opacity(0.35)
                    VStack(alignment: .leading, spacing: StudioSpace.x3) {
                        Text(editor.busyStatus ?? "Working…")
                            .font(StudioTypography.bodyMedium)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let progress = editor.busyProgress {
                            ProgressView(value: progress, total: 1)
                                .progressViewStyle(.linear)
                            Text("\(Int((progress * 100).rounded()))%")
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                    }
                    .padding(StudioSpacing.contentInset)
                    .frame(width: 360)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: StudioRadius.row))
                }
                .ignoresSafeArea()
                .allowsHitTesting(true)
            }
        }
        .onAppear(perform: dismissRestoredEmptyWindowIfNeeded)
        .onChange(of: editor.openProjects) { _, projects in
            if !projects.contains(where: { $0.id == projectID }) {
                dismissWindow(id: "save-review", value: projectID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            editor.clearSaveReviewState()
        }
    }

    private var canRefreshCurrentFile: Bool {
        guard let selectedFontID else { return false }
        return editor.canPreviewSaveReview(forProjectID: projectID, fontID: selectedFontID)
    }

    private func refreshCurrentFile() {
        editor.refreshCommitDiffPreview(forProjectID: projectID, fontID: selectedFontID)
    }

    private func dismissRestoredEmptyWindowIfNeeded() {
        guard session == nil, !isLoadingCurrentFile else { return }
        guard !editor.saveReviewWasExplicitlyOpened(forProjectID: projectID) else { return }
        dismissWindow(id: "save-review", value: projectID)
        SaveReviewWindowLifecycle.closeRestoredWindows()
    }

    private func preflightFailureHeader(session: CommitPreflightSession) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text("Export preview failed. Check the Review window for details.")
                .font(StudioTypography.emphasis)
            Text("Fix the issues below, then use Refresh to rebuild the diff.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
            if let code = session.preflight.errors.first?.code {
                Text("Code: \(code)")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func preflightErrorsCard(_ errors: [CommitError]) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            Text("Cannot export")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                HStack(alignment: .firstTextBaseline, spacing: StudioSpace.x1) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(StudioTypography.caption)
                        .foregroundStyle(StudioColors.errorForeground)
                    Text(error.message)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .strokeBorder(StudioColors.errorStroke, lineWidth: StudioStroke.regular)
        )
    }

    private func preflightWarningsCard(_ warnings: [PlanWarning]) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            Text("Warnings")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                StudioWarningMessage(message: warning.message)
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .strokeBorder(StudioColors.warningStroke, lineWidth: StudioStroke.regular)
        )
    }
}

/// Opt out of macOS window restoration for the Review auxiliary window (macOS 14).
private struct SaveReviewWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(window: view.window)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(window: nsView.window)
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.isRestorable = false
        window.identifier = NSUserInterfaceItemIdentifier(SaveReviewWindowLifecycle.identifier)
    }
}
