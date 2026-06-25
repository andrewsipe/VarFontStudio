import SwiftUI

/// Shared titles and shortcuts for instance inclusion actions (menu bar + context menu).
enum InstanceInclusionCommands {
    static let includeAllShownTitle = "Include All Shown"
    static let excludeAllShownTitle = "Exclude All Shown"
    static let includeSelectionTitle = "Include Selection"
    static let excludeSelectionTitle = "Exclude Selection"

    static let includeAllShownShortcut = KeyboardShortcut("i", modifiers: [.command, .option])
    static let excludeAllShownShortcut = KeyboardShortcut("e", modifiers: [.command, .option])
    static let includeSelectionShortcut = KeyboardShortcut("i", modifiers: [.command, .shift])
    static let excludeSelectionShortcut = KeyboardShortcut("e", modifiers: [.command, .shift])
}

struct InstanceSelectionContextMenu: View {
    let includeAction: () -> Void
    let excludeAction: () -> Void

    var body: some View {
        Button(InstanceInclusionCommands.includeSelectionTitle, action: includeAction)
            .keyboardShortcut(InstanceInclusionCommands.includeSelectionShortcut)

        Button(InstanceInclusionCommands.excludeSelectionTitle, action: excludeAction)
            .keyboardShortcut(InstanceInclusionCommands.excludeSelectionShortcut)
    }
}
