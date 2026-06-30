import SwiftUI
import VarFontCore

/// Source-manager dropdown for one project tab (Option B layout).
struct ProjectDropdownMenu: View {
    @EnvironmentObject private var editor: EditorViewModel
    let openProject: OpenProject
    var onDismiss: () -> Void

    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var nameFieldFocused: Bool

    private var liveProject: OpenProject? {
        editor.openProjects.first(where: { $0.id == openProject.id })
    }

    private var isActiveProject: Bool {
        editor.activeProjectID == openProject.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            projectHeader

            menuSectionDivider

            Text("OPEN FONTS · \(openProject.document.fonts.count)")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(openProject.document.fonts) { font in
                fileRow(font)
            }
        }
        .padding(.bottom, 8)
        .frame(width: 360)
        .id(openProject.id)
        .onAppear {
            editedName = currentDisplayName
        }
        .onChange(of: isEditingName) { _, editing in
            if editing {
                DispatchQueue.main.async {
                    nameFieldFocused = true
                }
            }
        }
        .onChange(of: editor.openProjects) { _, _ in
            if !isEditingName {
                editedName = currentDisplayName
            }
        }
    }

    private var currentDisplayName: String {
        if let name = liveProject?.document.displayName, !name.isEmpty {
            return name
        }
        return editor.projectTabLabel(for: liveProject ?? openProject)
    }

    private var menuSectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.22))
            .frame(height: 1)
    }

    private var projectHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Group {
                if isEditingName {
                    projectHeaderContent
                } else {
                    WorkspaceDraggableContainer(
                        item: .project(projectID: openProject.id, label: currentDisplayName),
                        isDragEnabled: editor.canDragProjectForCombine,
                        helpText: "Drag to another project tab to combine projects"
                    ) {
                        projectHeaderContent
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transaction { $0.animation = nil }

            if isEditingName {
                Button("Done") { commitRename() }
                    .controlSize(.small)
                    .frame(height: StudioFieldMetrics.bodyMediumRowHeight)
            } else {
                projectHeaderActions
            }
        }
        .padding(.horizontal, StudioSpacing.panelHorizontal)
        .padding(.vertical, 8)
        .padding(.top, 6)
    }

    private var projectHeaderContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if isEditingName {
                    StudioTextField(
                        placeholder: "Project name",
                        text: $editedName,
                        font: StudioTypography.bodyMedium.weight(.semibold),
                        rowHeight: StudioFieldMetrics.bodyMediumRowHeight
                    )
                    .focused($nameFieldFocused)
                    .onSubmit { commitRename() }
                } else {
                    StudioFieldLabel(
                        text: currentDisplayName,
                        font: StudioTypography.bodyMedium,
                        rowHeight: StudioFieldMetrics.bodyMediumRowHeight,
                        fontWeight: .semibold
                    )
                }
            }
            .transaction { $0.animation = nil }

            Text("\(openProject.document.fonts.count) file\(openProject.document.fonts.count == 1 ? "" : "s") · \(openProject.document.familyLabel)")
                .font(StudioTypography.meta)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var projectHeaderActions: some View {
        HStack(spacing: 0) {
            StudioToolbarIconButton(systemName: "pencil.circle", help: "Rename project tab") {
                editedName = currentDisplayName
                isEditingName = true
            }

            StudioToolbarIconMenu {
                projectActionsMenuContent
            }
        }
    }

    @ViewBuilder
    private var projectActionsMenuContent: some View {
            Button {
                onDismiss()
                editor.presentAddFontPanel(projectID: openProject.id)
            } label: {
                Label("Add font…", systemImage: "folder.badge.plus")
            }

            Button {
                onDismiss()
                editor.presentSaveReviewWindow(forProjectID: openProject.id)
            } label: {
                Label("Open Save Review Window", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(!editor.canPreviewSaveReview(forProjectID: openProject.id))

            if openProject.document.fonts.count > 1 {
                Button {
                    onDismiss()
                    editor.saveAllFiles(inProjectID: openProject.id)
                } label: {
                    Label("Save All Files…", systemImage: "square.and.arrow.down.on.square")
                }
                .disabled(!editor.canSave || editor.isSaveActionBlocked)
            }

            if let masterID = editor.masterFontID(for: openProject.id),
               openProject.document.fonts.count > 1 {
                Button {
                    onDismiss()
                    editor.selectFont(id: masterID)
                    editor.pushMasterAxisTreeToAllFonts()
                } label: {
                    Label("Push axis tree from master…", systemImage: "arrow.triangle.branch")
                }
            }

            if editor.openProjects.count > 1 {
                Button {
                    onDismiss()
                    editor.presentCombineProjectsPicker(into: openProject.id)
                } label: {
                    Label("Combine with…", systemImage: "arrow.triangle.merge")
                }
            }

            Divider()

            Button(role: .destructive) {
                onDismiss()
                editor.requestCloseProject(id: openProject.id)
            } label: {
                Label("Remove project", systemImage: "xmark.circle")
            }
    }

    private func fileRow(_ font: FontDocument) -> some View {
        let isSelected = isActiveProject && editor.selectedFontID == font.id
        let name = editor.fontBasename(for: font)

        return HStack(alignment: .center, spacing: 8) {
            WorkspaceDraggableContainer(
                item: .font(fontID: font.id, fromProjectID: openProject.id, label: name),
                isDragEnabled: editor.canDragFont(forProjectID: openProject.id),
                helpText: "Drag to a project tab to move, or to the toolbar to start a new project",
                onTap: {
                    editor.activateProject(id: openProject.id)
                    editor.selectFont(id: font.id)
                }
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(StudioTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(editor.shortenedPath(font.sourcePath))
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("\(font.axes.count) axes · \(editor.instanceCountLabel(for: font)) instances · \(openProject.document.familyLabel)")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            fileActionsMenu(font)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isSelected ? StudioColors.selectionFill : Color.clear,
            in: RoundedRectangle(cornerRadius: StudioRadius.chip)
        )
    }

    private func fileActionsMenu(_ font: FontDocument) -> some View {
        StudioToolbarIconMenu {
            Button {
                editor.activateProject(id: openProject.id)
                editor.selectFont(id: font.id)
                editor.revealFontInFinder(fontID: font.id, projectID: openProject.id)
            } label: {
                Label("Reveal in Finder", systemImage: "arrow.up.forward.app")
            }

            if editor.openProjects.count > 1 {
                Button {
                    onDismiss()
                    editor.presentMoveFontPicker(fontID: font.id, fromProjectID: openProject.id)
                } label: {
                    Label("Move to…", systemImage: "arrow.right.circle")
                }
            }

            if openProject.document.fonts.count > 1 {
                Button {
                    onDismiss()
                    editor.requestSplitFontToNewProject(fontID: font.id, fromProjectID: openProject.id)
                } label: {
                    Label("Move to new project…", systemImage: "arrow.up.right.square")
                }
            }

            Divider()

            Button(role: .destructive) {
                onDismiss()
                editor.requestRemoveFont(projectID: openProject.id, fontID: font.id)
            } label: {
                Label("Remove", systemImage: "minus.circle")
            }
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        editor.renameProject(id: openProject.id, displayName: trimmed)
        isEditingName = false
        nameFieldFocused = false
        editedName = currentDisplayName
    }
}
