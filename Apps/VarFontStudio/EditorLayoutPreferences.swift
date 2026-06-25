import Foundation
import SwiftUI

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

    @Published var axisTreeWidth: CGFloat {
        didSet { UserDefaults.standard.set(axisTreeWidth, forKey: Keys.axisTreeWidth) }
    }

    @Published var inspectorWidth: CGFloat {
        didSet { UserDefaults.standard.set(inspectorWidth, forKey: Keys.inspectorWidth) }
    }

    var panelVisibilityToken: String {
        "\(showAxisTree)-\(showInstances)-\(showInspector)"
    }

    init() {
        showAxisTree = Self.storedBool(forKey: Keys.axisTree, default: true)
        showInstances = Self.storedBool(forKey: Keys.instances, default: true)
        showInspector = Self.storedBool(forKey: Keys.inspector, default: true)
        axisTreeWidth = Self.storedCGFloat(forKey: Keys.axisTreeWidth, default: StudioPanelMetrics.axisTreeDefault)
        inspectorWidth = Self.storedCGFloat(forKey: Keys.inspectorWidth, default: StudioPanelMetrics.inspectorDefault)
    }

    private enum Keys {
        static let axisTree = "studio.showAxisTree"
        static let instances = "studio.showInstances"
        static let inspector = "studio.showInspector"
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
