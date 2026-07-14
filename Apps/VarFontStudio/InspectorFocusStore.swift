import Combine
import Foundation

enum InspectorPanelScope: Equatable {
    case project
    case instance
}

/// Where Project-inspector File naming should land after a footer jump.
enum InspectorFileNamingFocus: Equatable {
    case section
    case postScriptPrefix
}

/// Inspector panel scope, reveal pulses, and axis-tree focus chrome.
/// Owned by `EditorViewModel`; selection mutations (`selectedAxisStopID`, etc.) stay on the editor.
@MainActor
final class InspectorFocusStore: ObservableObject {
    @Published var panelScope: InspectorPanelScope = .project
    /// Bumped when chrome should reveal the inspector column (e.g. footer clarifier tap).
    @Published private(set) var revealToken = 0
    /// Optional File naming focus target paired with `revealToken`.
    @Published private(set) var fileNamingFocus: InspectorFileNamingFocus?
    /// Axis tag to expand when inspector navigates to a stop.
    @Published var focusedAxisTag: String?
    /// Bumps when the axis tree should expand and scroll to a stop (inspector / warnings).
    @Published var axisTreeFocusRequest: AxisTreeFocusRequest?

    func revealProjectScope(fileNaming: InspectorFileNamingFocus? = nil) {
        panelScope = .project
        fileNamingFocus = fileNaming
        revealToken &+= 1
    }

    func clearFileNamingFocus() {
        fileNamingFocus = nil
    }

    func updateScopeForInstanceSelection(hasInspectableInstance: Bool) {
        panelScope = hasInspectableInstance ? .instance : .project
    }

    func focusAxisTag(_ tag: String?) {
        focusedAxisTag = tag
    }

    func requestAxisTreeFocus(axisTag: String, stopID: String) {
        axisTreeFocusRequest = AxisTreeFocusRequest(
            axisTag: axisTag,
            stopID: stopID,
            token: UUID()
        )
    }
}
