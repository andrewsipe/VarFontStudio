import SwiftUI
import VarFontCore

/// Three-column workspace with native split dividers.
struct StudioPanelSplitView: View {
    @EnvironmentObject private var layout: EditorLayoutPreferences
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(WorkspaceDragCoordinator.self) private var workspaceDrag
    @State private var namesHeaderMeta: NameTableHeaderMeta?
    @State private var namesAnalysis: FontAnalysis?

    var body: some View {
        HSplitView {
            if showsMainWorkspace {
                mainWorkspaceColumns
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    // One green wash across Axis Tree + Instances (incl. the divider) so the
                    // group can't desync when Axis Tree remounts on drop / import.
                    .workspaceDropZoneHighlight(
                        isActive: workspaceDrag.shouldHighlightNewProjectWorkspace,
                        tint: StudioColors.dropNewProject
                    )
            }

            if layout.showInspector {
                InspectorColumn()
                    .frame(
                        minWidth: StudioPanelMetrics.inspectorMin,
                        idealWidth: layout.inspectorWidth,
                        maxWidth: inspectorMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .modifier(
                        TrackResizableWidth(
                            range: StudioPanelMetrics.inspectorMin...StudioPanelMetrics.inspectorMax,
                            storedWidth: $layout.inspectorWidth
                        )
                    )
                    .registerPanelFrame(InspectorPanelFrameKey.self) { frame in
                        editor.workspaceDrag.setInspectorPanelFrame(frame)
                    }
                    .workspaceDropZoneHighlight(
                        isActive: workspaceDrag.shouldHighlightInspectorPanel(
                            activeProjectID: editor.activeProjectID
                        ),
                        tint: StudioColors.dropAddExisting
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(layout.panelVisibilityToken)
    }

    private var showsMainWorkspace: Bool {
        layout.showAxisTree || layout.showInstances
    }

    /// Axis Tree + Instances share an inner split so new-project drop chrome is one overlay.
    @ViewBuilder
    private var mainWorkspaceColumns: some View {
        HSplitView {
            if layout.showAxisTree {
                axisTreeColumn
            }

            if layout.showInstances {
                middleColumn
                    .frame(
                        minWidth: StudioPanelMetrics.instancesMin,
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }
        }
    }

    // MARK: - Middle column (Instances | Names)

    private var middleColumn: some View {
        VStack(spacing: 0) {
            StudioPanelHeader(
                title: middlePanelTitle
            ) {
                middleHeaderMeta
            }

            middleScopeSwitcher
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .frame(height: StudioChromeBand.scope)

            Divider()

            Group {
                switch editor.inspectorFocus.middlePanelScope {
                case .instances:
                    InstanceListPanel(showsPanelHeader: false)
                case .names:
                    NameTablePanel(showsPanelHeader: false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onPreferenceChange(NameTableHeaderMetaKey.self) { meta in
                namesHeaderMeta = meta
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The Names tab badge has to be right even while the Instances tab is showing,
        // so the column reads the name table itself rather than waiting on the panel.
        .task(id: editor.selectedFontID) { reloadNamesAnalysis() }
        .onChange(of: editor.selectedFont?.sourcePath) { _, _ in reloadNamesAnalysis() }
    }

    private func reloadNamesAnalysis() {
        guard let font = editor.selectedFont else {
            namesAnalysis = nil
            return
        }
        namesAnalysis = try? editor.analyzeSourceFont(fontID: font.id, sourcePath: font.sourcePath)
    }

    private var nameIssues: [WindowsNameValidation.Issue] {
        guard let font = editor.selectedFont, let namesAnalysis else { return [] }
        return WindowsNameValidation.issues(
            windowsNameTable: namesAnalysis.windowsNameTable,
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals,
            familyPSPrefix: font.options.familyPSPrefix
        )
    }

    private var namesTabHelp: String {
        let issues = nameIssues
        guard !issues.isEmpty else { return "Windows name table (IDs 0–25)" }
        let required = issues.filter(\.isRequired).count
        let noun = issues.count == 1 ? "name issue" : "name issues"
        guard required > 0 else { return "\(issues.count) \(noun) to review" }
        return "\(issues.count) \(noun) to review · \(required) required"
    }

    private var middlePanelTitle: String {
        switch editor.inspectorFocus.middlePanelScope {
        case .instances: "Instances"
        case .names: "Names"
        }
    }

    @ViewBuilder
    private var middleHeaderMeta: some View {
        switch editor.inspectorFocus.middlePanelScope {
        case .instances:
            InstanceListPanel.headerCounts(editor: editor)
        case .names:
            if let meta = namesHeaderMeta {
                HStack(spacing: StudioSpacing.instanceRowVertical) {
                    Text("\(meta.populated)")
                        .foregroundStyle(.primary)
                    Text("populated")
                        .foregroundStyle(.secondary)
                    if meta.missing > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text("\(meta.missing)")
                            .foregroundStyle(.secondary)
                        Text("missing")
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text("Win 3/1/409")
                        .foregroundStyle(.tertiary)
                }
                .font(StudioTypography.caption)
            }
        }
    }

    private var middleScopeSwitcher: some View {
        HStack(spacing: StudioSpace.x0_5) {
            StudioSegmentButton(
                title: "Instances",
                isSelected: editor.inspectorFocus.middlePanelScope == .instances,
                expands: true
            ) {
                editor.inspectorFocus.middlePanelScope = .instances
            }
            StudioSegmentButton(
                title: "Names",
                isSelected: editor.inspectorFocus.middlePanelScope == .names,
                expands: true,
                help: namesTabHelp,
                showsWarning: !nameIssues.isEmpty
            ) {
                editor.inspectorFocus.showNamesPanel()
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: StudioRadius.control))
    }

    // MARK: - Axis tree column

    @ViewBuilder
    private var axisTreeColumn: some View {
        if layout.axisTreeCollapsed {
            AxisTreeRail {
                layout.axisTreeCollapsed = false
            }
            .frame(width: StudioPanelMetrics.axisTreeRailWidth)
            .frame(maxHeight: .infinity)
            .background(.bar)
            .zIndex(1)
        } else {
            AxisTreePanel()
                .frame(
                    minWidth: StudioPanelMetrics.axisTreeMin,
                    idealWidth: layout.axisTreeWidth,
                    maxWidth: axisTreeMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .modifier(
                    TrackResizableWidth(
                        range: StudioPanelMetrics.axisTreeMin...StudioPanelMetrics.axisTreeMax,
                        storedWidth: $layout.axisTreeWidth
                    )
                )
        }
    }

    private var axisTreeMaxWidth: CGFloat? {
        let onlyColumn = layout.showAxisTree && !layout.showInstances && !layout.showInspector
        return onlyColumn ? nil : StudioPanelMetrics.axisTreeMax
    }

    private var inspectorMaxWidth: CGFloat? {
        layout.showInspector && !layout.showInstances ? nil : StudioPanelMetrics.inspectorMax
    }
}

private extension View {
    func registerPanelFrame<K: PreferenceKey>(
        _ key: K.Type,
        onChange: @escaping (CGRect) -> Void
    ) -> some View where K.Value == CGRect {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: key,
                    value: geometry.frame(in: .global)
                )
            }
        }
        .onPreferenceChange(key) { frame in
            onChange(frame)
        }
    }
}

private struct TrackResizableWidth: ViewModifier {
    let range: ClosedRange<CGFloat>
    @Binding var storedWidth: CGFloat

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { persist(geometry.size.width) }
                    .onChange(of: geometry.size.width) { _, width in
                        persist(width)
                    }
            }
        }
    }

    private func persist(_ width: CGFloat) {
        let clamped = min(max(width, range.lowerBound), range.upperBound)
        guard abs(storedWidth - clamped) > 0.5 else { return }
        storedWidth = clamped
    }
}

// MARK: - Collapsed rail

private struct AxisTreeRail: View {
    let onExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            StudioPanelHeaderChrome {
                Button(action: onExpand) {
                    Image(systemName: "sidebar.left")
                        .font(StudioTypography.bodyMedium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverIcon()
                .help("Show axis tree")
            }

            StudioSectionLabel(title: "Axis tree")
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(
                    width: StudioPanelMetrics.axisTreeRailWidth,
                    height: StudioPanelMetrics.axisTreeRailLabelHeight,
                    alignment: .center
                )
                .padding(.top, StudioSpace.x2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

enum StudioPanelMetrics {
    static let axisTreeMin: CGFloat = 280
    static let axisTreeDefault: CGFloat = 320
    static let axisTreeMax: CGFloat = 420
    static let axisTreeRailWidth: CGFloat = 44
    /// Unrotated width of `StudioSectionLabel("Axis tree")` — reserved as layout height after −90° rotation.
    /// Snapped up from measured ~54 onto the 4pt lattice.
    static let axisTreeRailLabelHeight: CGFloat = StudioSpace.unit * 14 // 56

    static let instancesMin: CGFloat = 320

    static let inspectorMin: CGFloat = 260
    static let inspectorDefault: CGFloat = 300
    static let inspectorMax: CGFloat = 480
}
