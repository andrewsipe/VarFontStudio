import SwiftUI
import VarFontCore

struct InstanceListPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            FontFileTabs()

            if let font = editor.selectedFont {
                sourceSummary(font)
            }

            filterBar

            Table(editor.filteredInstances, selection: Binding(
                get: { editor.selectedInstanceKey.map { Set([$0]) } ?? [] },
                set: { editor.selectedInstanceKey = $0.first }
            )) {
                TableColumn("") { instance in
                    Toggle(
                        "",
                        isOn: inclusionBinding(for: instance.key)
                    )
                    .labelsHidden()
                }
                .width(28)

                TableColumn("Style name") { instance in
                    HStack(spacing: 6) {
                        Text(instance.composedName)
                        if instance.duplicate {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help("Duplicate composed name")
                        }
                    }
                }

                TableColumn("Key") { instance in
                    Text(instance.key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .navigationTitle("Instances")
    }

    private func sourceSummary(_ font: FontDocument) -> some View {
        HStack {
            Text(URL(fileURLWithPath: font.sourcePath).lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if font.dirty {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            TextField("Search", text: $editor.searchText)
                .textFieldStyle(.roundedBorder)

            Toggle("Excluded only", isOn: $editor.showExcludedOnly)
                .toggleStyle(.checkbox)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func inclusionBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                editor.instancePlan?.instances.first(where: { $0.key == key })?.included ?? true
            },
            set: { editor.setInstanceIncluded(key, included: $0) }
        )
    }
}
