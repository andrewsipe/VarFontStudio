import SwiftUI

/// Inspector column host with Project | Instance scope switcher.
struct InspectorColumn: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var layout: EditorLayoutPreferences

    var body: some View {
        VStack(spacing: 0) {
            StudioPanelHeader(title: "Inspector") {
                inspectorHeaderMeta
            }

            scopeSwitcher
                .padding(.horizontal, StudioSpacing.contentInset)
                .frame(height: StudioChromeBand.scope)

            Divider()

            Group {
                switch editor.inspectorFocus.panelScope {
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
        .onChange(of: editor.inspectorFocus.revealToken) { _, _ in
            if !layout.showInspector {
                layout.showInspector = true
            }
        }
    }

    @ViewBuilder
    private var inspectorHeaderMeta: some View {
        switch editor.inspectorFocus.panelScope {
        case .project:
            if let project = editor.project {
                HStack(spacing: StudioSpacing.instanceRowVertical) {
                    Text("\(project.fonts.count)")
                        .foregroundStyle(StudioColors.metricForeground)
                    Text(project.fonts.count == 1 ? "file" : "files")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.caption)
            }
        case .instance:
            if editor.inspectorInspectableInstance != nil {
                HStack(spacing: StudioSpacing.instanceRowVertical) {
                    Text("1")
                        .foregroundStyle(StudioColors.metricForeground)
                    Text("instance")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.caption)
            } else if editor.activeInstanceSelection.count > 1 {
                HStack(spacing: StudioSpacing.instanceRowVertical) {
                    Text("\(editor.activeInstanceSelection.count)")
                        .foregroundStyle(.secondary)
                    Text("selected")
                        .foregroundStyle(.secondary)
                }
                .font(StudioTypography.caption)
            }
        }
    }

    private var scopeSwitcher: some View {
        HStack(spacing: StudioSpace.x0_5) {
            StudioSegmentButton(
                title: "Project",
                isSelected: editor.inspectorFocus.panelScope == .project,
                expands: true
            ) {
                editor.inspectorFocus.panelScope = .project
            }
            StudioSegmentButton(
                title: "Instance",
                isSelected: editor.inspectorFocus.panelScope == .instance,
                expands: true
            ) {
                editor.inspectorFocus.panelScope = .instance
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
    }
}
