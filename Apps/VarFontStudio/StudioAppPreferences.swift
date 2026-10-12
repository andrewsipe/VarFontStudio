import Foundation
import VarFontCore

/// App-wide defaults persisted in UserDefaults (not per-project).
enum StudioAppPreferences {
    private static let defaultNameIDStrategyKey = "studio.defaultNameIDStrategy"
    private static let offerOptionalCoreNamesKey = "studio.offerOptionalCoreNames"

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

    /// When true, missing optional core name IDs (3, 5, 16, 17) are offered as fills.
    /// Required names are always offered.
    static var offerOptionalCoreNames: Bool {
        get {
            guard UserDefaults.standard.object(forKey: offerOptionalCoreNamesKey) != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: offerOptionalCoreNamesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: offerOptionalCoreNamesKey)
        }
    }
}
