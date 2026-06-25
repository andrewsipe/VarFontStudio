import SwiftUI

/// Three-column editor workspace with native macOS split dividers.
struct StudioPanelSplitView: View {
    @EnvironmentObject private var layout: EditorLayoutPreferences

    var body: some View {
        HSplitView {
            if layout.showAxisTree {
                AxisTreePanel()
                    .frame(
                        minWidth: StudioPanelMetrics.axisTreeMin,
                        idealWidth: layout.axisTreeWidth,
                        maxWidth: axisTreeMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }

            if layout.showInstances {
                InstanceListPanel()
                    .frame(
                        minWidth: StudioPanelMetrics.instancesMin,
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }

            if layout.showInspector {
                InspectorPanel()
                    .frame(
                        minWidth: StudioPanelMetrics.inspectorMin,
                        idealWidth: layout.inspectorWidth,
                        maxWidth: inspectorMaxWidth,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .id(layout.panelVisibilityToken)
    }

    private var axisTreeMaxWidth: CGFloat? {
        layout.showAxisTree && !layout.showInstances && !layout.showInspector ? nil : StudioPanelMetrics.axisTreeMax
    }

    private var inspectorMaxWidth: CGFloat? {
        layout.showInspector && !layout.showInstances ? nil : StudioPanelMetrics.inspectorMax
    }
}

enum StudioPanelMetrics {
    static let axisTreeMin: CGFloat = 220
    static let axisTreeDefault: CGFloat = 260
    static let axisTreeMax: CGFloat = 420

    static let instancesMin: CGFloat = 320

    static let inspectorMin: CGFloat = 260
    static let inspectorDefault: CGFloat = 300
    static let inspectorMax: CGFloat = 480
}
