import SwiftUI

/// Keyboard shortcuts reference for alpha testers.
struct StudioShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    private struct ShortcutRow: Identifiable {
        let id = UUID()
        let action: String
        let keys: String
    }

    private let sections: [(title: String, rows: [ShortcutRow])] = [
        ("File", [
            ShortcutRow(action: "Open project", keys: "⌘⌥O"),
            ShortcutRow(action: "Open font", keys: "⌘O"),
            ShortcutRow(action: "Add font to project", keys: "⌘⇧O"),
            ShortcutRow(action: "Save project", keys: "⌘⌥S"),
            ShortcutRow(action: "Save project as", keys: "⌘⌥⇧S"),
            ShortcutRow(action: "Save", keys: "⌘S"),
            ShortcutRow(action: "Save copy (choose path)", keys: "⌘⇧S"),
            ShortcutRow(action: "Open save review window", keys: "⌘⇧R"),
        ]),
        ("Edit", [
            ShortcutRow(action: "Undo", keys: "⌘Z"),
            ShortcutRow(action: "Redo", keys: "⌘⇧Z"),
            ShortcutRow(action: "Find instances", keys: "⌘F"),
        ]),
        ("View", [
            ShortcutRow(action: "Toggle axis tree", keys: "⌃⌘1"),
            ShortcutRow(action: "Toggle instances", keys: "⌃⌘2"),
            ShortcutRow(action: "Toggle inspector", keys: "⌃⌘3"),
            ShortcutRow(action: "Toggle save review window", keys: "⌃⌘4"),
        ]),
        ("Instances", [
            ShortcutRow(action: "Include all shown", keys: "⌥⌘I"),
            ShortcutRow(action: "Exclude all shown", keys: "⌥⌘E"),
            ShortcutRow(action: "Include selection", keys: "⌘⇧I"),
            ShortcutRow(action: "Exclude selection", keys: "⌘⇧E"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("VarFont Studio Shortcuts")
                    .font(StudioTypography.emphasis)
                Text("Alpha build — patched copies are written beside the source file unless you choose another path.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(StudioTypography.sectionLabel)
                                .foregroundStyle(.secondary)
                            ForEach(section.rows) { row in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.action)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(row.keys)
                                        .font(StudioTypography.monoMeta)
                                        .foregroundStyle(.secondary)
                                }
                                .font(StudioTypography.body)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 480)
        .preferredColorScheme(.dark)
    }
}
