import Foundation
import SwiftUI
import VarFontCore

@MainActor
final class EditorLayoutPreferences: ObservableObject {
    @Published var showAxisTree: Bool {
        didSet {
            UserDefaults.standard.set(showAxisTree, forKey: Keys.axisTree)
            ensureAtLeastOnePanelVisible()
        }
    }

    @Published var showInstances: Bool {
        didSet {
            UserDefaults.standard.set(showInstances, forKey: Keys.instances)
            ensureAtLeastOnePanelVisible()
        }
    }

    @Published var showInspector: Bool {
        didSet {
            UserDefaults.standard.set(showInspector, forKey: Keys.inspector)
            ensureAtLeastOnePanelVisible()
        }
    }

    /// Axis tree collapsed to a leading rail (canvas-first layout).
    @Published var axisTreeCollapsed: Bool {
        didSet { UserDefaults.standard.set(axisTreeCollapsed, forKey: Keys.axisTreeCollapsed) }
    }

    /// Inspector collapsed to a trailing rail (canvas-first layout).
    @Published var inspectorCollapsed: Bool {
        didSet { UserDefaults.standard.set(inspectorCollapsed, forKey: Keys.inspectorCollapsed) }
    }

    /// Combination styles drawer at the bottom of the Axis Tree panel.
    /// Session-only — always starts closed so suggestions don’t force the drawer open.
    @Published var combinationStylesDrawerExpanded: Bool = false

    @Published var axisTreeWidth: CGFloat {
        didSet { UserDefaults.standard.set(axisTreeWidth, forKey: Keys.axisTreeWidth) }
    }

    @Published var inspectorWidth: CGFloat {
        didSet { UserDefaults.standard.set(inspectorWidth, forKey: Keys.inspectorWidth) }
    }

    /// Default OpenType feature label nameID strategy for newly opened fonts/projects.
    @Published var defaultNameIDStrategy: NameIDStrategy {
        didSet { StudioAppPreferences.defaultNameIDStrategy = defaultNameIDStrategy }
    }

    var panelVisibilityToken: String {
        "\(showAxisTree)-\(axisTreeCollapsed)-\(showInstances)-\(showInspector)-\(inspectorCollapsed)"
    }

    init() {
        showAxisTree = Self.storedBool(forKey: Keys.axisTree, default: true)
        showInstances = Self.storedBool(forKey: Keys.instances, default: true)
        showInspector = Self.storedBool(forKey: Keys.inspector, default: true)
        axisTreeCollapsed = Self.storedBool(forKey: Keys.axisTreeCollapsed, default: false)
        inspectorCollapsed = Self.storedBool(forKey: Keys.inspectorCollapsed, default: false)
        // Drop any legacy persisted expand flag from when suggestions auto-opened the drawer.
        UserDefaults.standard.removeObject(forKey: Keys.combinationStylesDrawerExpanded)
        combinationStylesDrawerExpanded = false
        axisTreeWidth = Self.storedCGFloat(forKey: Keys.axisTreeWidth, default: StudioPanelMetrics.axisTreeDefault)
        inspectorWidth = Self.storedCGFloat(forKey: Keys.inspectorWidth, default: StudioPanelMetrics.inspectorDefault)
        defaultNameIDStrategy = StudioAppPreferences.defaultNameIDStrategy
    }

    func axisTreeOccupiedWidth() -> CGFloat {
        guard showAxisTree else { return 0 }
        return axisTreeCollapsed ? StudioPanelMetrics.axisTreeRailWidth : axisTreeWidth
    }

    func inspectorOccupiedWidth() -> CGFloat {
        guard showInspector else { return 0 }
        return inspectorCollapsed ? StudioPanelMetrics.inspectorRailWidth : inspectorWidth
    }

    /// Expand inspector if revealed programmatically (focus / reveal token).
    func revealInspector() {
        showInspector = true
        inspectorCollapsed = false
    }

    private enum Keys {
        static let axisTree = "studio.showAxisTree"
        static let instances = "studio.showInstances"
        static let inspector = "studio.showInspector"
        static let axisTreeCollapsed = "studio.axisTreeCollapsed"
        static let inspectorCollapsed = "studio.inspectorCollapsed"
        static let combinationStylesDrawerExpanded = "studio.combinationStylesDrawerExpanded"
        static let axisTreeWidth = "studio.axisTreeWidth"
        static let inspectorWidth = "studio.inspectorWidth"
    }

    private static func storedCGFloat(forKey key: String, default defaultValue: CGFloat) -> CGFloat {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return CGFloat(UserDefaults.standard.double(forKey: key))
    }

    private static func storedBool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func ensureAtLeastOnePanelVisible() {
        guard !showAxisTree, !showInstances, !showInspector else { return }
        showInstances = true
    }
}
