import SwiftUI
import VarFontCore

/// Tier-2 file switcher below the project toolbar.
struct ProjectFileSubBar: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(WorkspaceDragCoordinator.self) private var workspaceDrag

    var body: some View {
        Group {
            if editor.hasOpenProjects,
               let project = editor.project,
               let projectID = editor.activeProjectID,
               !project.fonts.isEmpty {
                HStack(spacing: StudioSpacing.controlGap) {
                    StudioSectionLabel(title: "File")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(project.fonts) { font in
                                fileChip(font, projectID: projectID, projectFontCount: project.fonts.count)
                            }

                            Color.clear
                                .frame(width: 12, height: 1)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: FileChipFrameKey.self,
                                            value: ["\(projectID):__end__": geometry.frame(in: .global)]
                                        )
                                    }
                                }
                        }
                        .onPreferenceChange(FileChipFrameKey.self) { frames in
                            guard !workspaceDrag.isActive else { return }
                            editor.workspaceDrag.setFontChipFrames(frames, source: .fileSubBar)
                        }
                    }
                    .scrollDisabled(workspaceDrag.isActive)
                }
                .padding(.horizontal, StudioSpacing.editorChromeInset)
                .padding(.vertical, 5)
                .workspaceDropZoneHighlight(
                    isActive: workspaceDrag.shouldHighlightFileSubBarRow(
                        activeProjectID: editor.activeProjectID
                    ),
                    tint: StudioColors.dropAddExisting
                )
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ProjectFileSubBarFrameKey.self,
                            value: geometry.frame(in: .global)
                        )
                    }
                }
                .onPreferenceChange(ProjectFileSubBarFrameKey.self) { frame in
                    editor.workspaceDrag.setFileSubBarFrame(frame)
                }
            }
        }
    }

    private func fileChip(_ font: FontDocument, projectID: String, projectFontCount: Int) -> some View {
        let isSelected = editor.selectedFontID == font.id
        let name = editor.fontBasename(for: font)
        let isMaster = editor.isMasterFont(fontID: font.id, projectID: projectID)

        return HStack(spacing: 4) {
            WorkspaceDraggableContainer(
                item: .font(fontID: font.id, fromProjectID: projectID, label: name),
                isDragEnabled: editor.canDragFont(forProjectID: projectID),
                helpText: "Drag onto another file to reorder, to a project tab to move, or to the toolbar to start a new project",
                onTap: {
                    editor.selectFont(id: font.id)
                    editor.focusInspectorProjectScope()
                }
            ) {
                StudioTabChip(isSelected: isSelected) {
                    HStack(spacing: 4) {
                        if isMaster, projectFontCount > 1 {
                            StudioMasterStar()
                                .help("Master — axis tree source for this project")
                        }
                        if editor.isFontDirty(fontID: font.id) {
                            StudioDirtyDot()
                                .help("Unsaved edits")
                        }
                        Text(name)
                            .font(StudioTypography.rowName)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .lineLimit(1)
                    }
                } trailing: {
                    chipTrailing(font: font, projectID: projectID, projectFontCount: projectFontCount)
                }
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: FileChipFrameKey.self,
                    value: ["\(projectID):\(font.id)": geometry.frame(in: .global)]
                )
            }
        }
        .contextMenu {
            ProjectFileContextMenu(
                font: font,
                projectID: projectID,
                projectFontCount: projectFontCount
            )
        }
    }

    @ViewBuilder
    private func chipTrailing(
        font: FontDocument,
        projectID: String,
        projectFontCount: Int
    ) -> some View {
        HStack(spacing: 4) {
            if let savedName = editor.savedOutputLabel(for: font) {
                Image(systemName: "square.and.arrow.up.badge.checkmark")
                    .font(StudioTypography.iconGlyph)
                    .foregroundStyle(.secondary)
                    .help("Exported to \(savedName)")
                Text(savedName)
                    .font(StudioTypography.meta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            StudioOverflowMenu(scale: .chip) {
                ProjectFileContextMenu(
                    font: font,
                    projectID: projectID,
                    projectFontCount: projectFontCount
                )
            }

            if projectFontCount > 1 {
                StudioDismissButton(scale: .chip, style: .fill, help: "Remove from project", foreground: .tertiary) {
                    editor.requestRemoveFont(projectID: projectID, fontID: font.id)
                }
            }
        }
    }
}
