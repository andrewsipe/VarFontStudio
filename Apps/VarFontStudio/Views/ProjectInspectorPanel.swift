import SwiftUI
import VarFontCore

/// Project-scoped inspector: fixed header + file naming, scrollable file list.
/// Sections are flat (no card backgrounds) to match StudioInspectorBlock's
/// convention in the Instance scope — a Divider marks the fixed/scroll seam.
struct ProjectInspectorPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(WorkspaceDragCoordinator.self) private var workspaceDrag
    @State private var isFileNamingExpanded = true

    var body: some View {
        if let projectID = editor.activeProjectID,
           let openProject = editor.openProjects.first(where: { $0.id == projectID }) {
            VStack(alignment: .leading, spacing: 0) {
                ProjectScopeHeader(openProject: openProject)
                    .overlay(alignment: .bottom) { Divider() }

                fileNamingSection(for: openProject)
                    .padding(.horizontal, StudioSpacing.contentInset)
                    .padding(.top, StudioSpacing.panelContentTop)
                    .padding(.bottom, StudioSpacing.sheetSectionSpacing)

                Divider()

                filesSection(for: openProject)
                    .padding(.horizontal, StudioSpacing.contentInset)
                    .padding(.top, StudioSpacing.sheetSectionSpacing)
                    .padding(.bottom, StudioSpacing.panelVertical)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onChange(of: editor.inspectorFocus.revealToken) { _, _ in
                guard editor.inspectorFocus.fileNamingFocus != nil else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    isFileNamingExpanded = true
                }
            }
        } else {
            ContentUnavailableView(
                "No Project Open",
                systemImage: "folder",
                description: Text(StudioEmptyCopy.noProjectInspector)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func fileNamingSection(for openProject: OpenProject) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            if let fontID = editor.selectedFontID,
               let font = openProject.document.fonts.first(where: { $0.id == fontID }) {
                fileNamingHeader(font: font)

                if isFileNamingExpanded {
                    FileClarifierFields(font: font)
                }
            } else {
                FileNamingSectionPlaceholder()
            }
        }
    }

    private func fileNamingHeader(font: FontDocument) -> some View {
        HStack(alignment: .center, spacing: StudioSpacing.controlGap) {
            Button {
                withAnimation(.easeOut(duration: 0.12)) {
                    isFileNamingExpanded.toggle()
                }
            } label: {
                HStack(spacing: StudioSpacing.tightGap) {
                    StudioDisclosureChevron(isExpanded: isFileNamingExpanded)
                    StudioSectionLabel(title: "File naming")
                }
            }
            .buttonStyle(.plain)
            .studioHoverLink(.primary)

            Spacer(minLength: 0)

            if isFileNamingExpanded {
                fileNamingActions(font: font)
            }
        }
    }

    @ViewBuilder
    private func filesSection(for openProject: OpenProject) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            filesSectionHeader(for: openProject)

            if openProject.document.fonts.count > 1 {
                Text("★ Master file — other files in this project inherit its axis-stop layout.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                    ForEach(openProject.document.fonts) { font in
                        ProjectInspectorFileRow(
                            font: font,
                            openProject: openProject,
                            isSelected: editor.activeProjectID == openProject.id
                                && editor.selectedFontID == font.id
                        )
                    }

                    Color.clear
                        .frame(height: 8)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: FileChipFrameKey.self,
                                    value: ["\(openProject.id):__end__": geometry.frame(in: .global)]
                                )
                            }
                        }
                }
                .padding(.bottom, StudioSpacing.controlGap)
                .onPreferenceChange(FileChipFrameKey.self) { frames in
                    guard !workspaceDrag.isActive else { return }
                    editor.workspaceDrag.setFontChipFrames(frames, source: .inspectorFiles)
                }
            }
            .scrollDisabled(workspaceDrag.isActive)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func filesSectionHeader(for openProject: OpenProject) -> some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioSectionLabel(title: "Fonts")

            Text("\(openProject.document.fonts.count)")
                .font(StudioTypography.caption)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if openProject.document.fonts.count > 1 {
                StudioPlainLinkButton(
                    title: "Export All…",
                    role: .accent,
                    font: StudioTypography.caption
                ) {
                    editor.saveAllFiles(inProjectID: openProject.id)
                }
                .disabled(!editor.canSave || editor.isSaveActionBlocked)
                .help("Export every file to a folder (Patched subfolder if you pick a source folder)")

                StudioPlainLinkButton(
                    title: "To Original…",
                    role: .accent,
                    font: StudioTypography.caption
                ) {
                    editor.requestSaveAllToOriginal(inProjectID: openProject.id)
                }
                .disabled(!editor.canSave || editor.isSaveActionBlocked)
                .help("Overwrite every source font file after confirmation")
            }

            StudioPlainLinkButton(
                title: "Add font",
                systemImage: "plus",
                role: .accent,
                font: StudioTypography.caption
            ) {
                editor.presentAddFontPanel(projectID: openProject.id)
            }
        }
    }

    @ViewBuilder
    private func fileNamingActions(font: FontDocument) -> some View {
        let isMaster = editor.fileRole(for: font.id)?.kind == .master
        let inferEnabled = editor.hasEditableClarifierSlots(for: font.id)
        let showsPush = isMaster && editor.projectHasMultipleFiles
        let showsClear = isMaster
            && editor.projectHasMultipleFiles
            && !editor.clarifierLabels(for: font.id).isEmpty

        HStack(spacing: StudioSpacing.controlGap) {
            StudioPlainLinkButton(
                title: "Infer Prefix",
                role: .accent,
                font: StudioTypography.caption,
                help: inferEnabled
                    ? "Suggest clarifiers from the filename when axis naming does not already cover them. Uses stop names from the font — never expands abbreviations."
                    : "Axis and registration naming already cover this file, or clarifiers belong on variant files."
            ) {
                editor.selectFont(id: font.id)
                editor.inferFileClarifiersForSelectedFont()
            }
            .disabled(!inferEnabled)

            if showsPush {
                StudioPlainLinkButton(
                    title: "Push Axis Tree",
                    role: .accent,
                    font: StudioTypography.caption,
                    help: "Copy master axis stops and combinations to all other files in this project"
                ) {
                    editor.selectFont(id: font.id)
                    editor.requestPushMasterAxisTree()
                }
            }

            if showsClear {
                StudioPlainLinkButton(
                    title: "Clear",
                    role: .secondary,
                    font: StudioTypography.caption
                ) {
                    editor.selectFont(id: font.id)
                    editor.clearFileClarifiers(for: font.id)
                }
            }
        }
    }
}
