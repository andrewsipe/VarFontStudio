import SwiftUI

/// Which Studio surface is the key window — drives Review / Instancer menu enablement.
enum StudioFocusedSurface: Equatable {
    case studio
    case review
    case instancer
}

struct StudioFocus: Equatable {
    var surface: StudioFocusedSurface
    var reviewProjectID: String? = nil
    var instancerWindowKey: String? = nil
}

private struct StudioFocusKey: FocusedValueKey {
    typealias Value = StudioFocus
}

extension FocusedValues {
    var studioFocus: StudioFocus? {
        get { self[StudioFocusKey.self] }
        set { self[StudioFocusKey.self] = newValue }
    }
}
