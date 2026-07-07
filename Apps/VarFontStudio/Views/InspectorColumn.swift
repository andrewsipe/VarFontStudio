import SwiftUI

/// Inspector column host with Project | Instance scope switcher.
struct InspectorColumn: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var layout: EditorLayoutPreferences

    var body: some View {
        VStack(spacing: 0) {
            StudioPanelHeader(title: "Inspector", horizontalPadding: StudioSpacing.panelHorizontal) {
                inspectorHeaderMeta
            }

            scopeSwitcher
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .padding(.vertical, 8)

            Divider()

            Group {
                switch editor.inspectorPanelScope {
                case .project:
                    ProjectInspectorPanel()
                case .instance:
                    InstanceInspectorContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: editor.selectedInstanceKey) { _, _ in
            editor.updateInspectorScopeForSelection()
        }
        .onChange(of: editor.selectedInstanceKeys) { _, _ in
            editor.updateInspectorScopeForSelection()
        }
        .onChange(of: editor.inspectorRevealToken) { _, _ in
            if !layout.showInspector {
                layout.showInspector = true
            }
        }
    }

    @ViewBuilder
    private var inspectorHeaderMeta: some View {
        switch editor.inspectorPanelScope {
        case .project:
            if let project = editor.project {
                HStack(spacing: 3) {
                    Text("\(project.fonts.count)")
                        .foregroundStyle(StudioColors.computedHighlight)
                    Text(project.fonts.count == 1 ? "file" : "files")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.meta)
            }
        case .instance:
            if editor.inspectorInspectableInstance != nil {
                HStack(spacing: 3) {
                    Text("1")
                        .foregroundStyle(StudioColors.computedHighlight)
                    Text("instance")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.meta)
            } else if editor.activeInstanceSelection.count > 1 {
                HStack(spacing: 3) {
                    Text("\(editor.activeInstanceSelection.count)")
                        .foregroundStyle(.secondary)
                    Text("selected")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.meta)
            }
        }
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 2) {
            scopeButton(title: "Project", scope: .project)
            scopeButton(title: "Instance", scope: .instance)
        }
    }

    private func scopeButton(title: String, scope: InspectorPanelScope) -> some View {
        let isOn = editor.inspectorPanelScope == scope
        return Button {
            editor.inspectorPanelScope = scope
        } label: {
            Text(title)
                .font(StudioTypography.meta)
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: StudioRadius.row)
                        .fill(isOn ? Color.accentColor.opacity(0.12) : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: StudioRadius.row)
                                .strokeBorder(
                                    isOn ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.22),
                                    lineWidth: 1
                                )
                        }
                }
        }
        .buttonStyle(.plain)
    }
}
