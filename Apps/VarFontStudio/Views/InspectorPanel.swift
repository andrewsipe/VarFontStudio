import SwiftUI
import VarFontCore

struct InspectorPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        Group {
            if let instance = editor.selectedInstance {
                instanceInspector(instance)
            } else {
                ContentUnavailableView(
                    "No Instance Selected",
                    systemImage: "sidebar.right",
                    description: Text("Select a row in the instance list to inspect naming and coordinates.")
                )
            }
        }
        .navigationTitle("Inspector")
    }

    private func instanceInspector(_ instance: PlannedInstance) -> some View {
        Form {
            Section("Composed name") {
                Text(instance.composedName)
                    .font(.title3)
                    .textSelection(.enabled)
            }

            Section("Naming chain") {
                if instance.namingChain.isEmpty {
                    Text("No naming chain entries")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(instance.namingChain.enumerated()), id: \.offset) { _, link in
                        HStack {
                            Text(link.tag.uppercased())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            Text(link.name)
                            Spacer()
                            if link.elided {
                                Text("elided")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            Section("Coordinates") {
                ForEach(sortedCoordKeys(instance.coords), id: \.self) { tag in
                    let pinned = !editor.axisParticipatesInInstanceGrid(tag: tag)
                    LabeledContent(tag) {
                        Text(coordText(instance.coords[tag] ?? 0))
                            .monospacedDigit()
                    }
                    .foregroundStyle(pinned ? .tertiary : .primary)
                    .help(pinned ? "Pinned — excluded from the instance grid" : "")
                }
            }

            Section("Instance key") {
                Text(instance.key)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }

            if let warnings = editor.instancePlan?.warnings, !warnings.isEmpty {
                Section("Plan warnings") {
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sortedCoordKeys(_ coords: [String: Double]) -> [String] {
        coords.keys.sorted()
    }

    private func coordText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
