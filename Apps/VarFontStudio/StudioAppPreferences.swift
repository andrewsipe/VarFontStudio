import Foundation
import VarFontCore

/// App-wide defaults persisted in UserDefaults (not per-project).
enum StudioAppPreferences {
    private static let defaultNameIDStrategyKey = "studio.defaultNameIDStrategy"

    static var defaultNameIDStrategy: NameIDStrategy {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultNameIDStrategyKey),
                  let strategy = NameIDStrategy(rawValue: raw) else {
                return .preserve
            }
            return strategy
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultNameIDStrategyKey)
        }
    }
}
