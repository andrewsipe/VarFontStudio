import SwiftUI
import VarFontCore

/// App menu Settings for studio-wide defaults (persisted across projects).
struct StudioSettingsView: View {
    @EnvironmentObject private var layout: EditorLayoutPreferences
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        Form {
            Section {
                Picker(selection: defaultStrategyBinding) {
                    Text("Preserve OpenType Feature Name IDs").tag(NameIDStrategy.preserve)
                    Text("Repack feature labels (starting at ID 256)").tag(NameIDStrategy.reflow)
                } label: {
                    Text("OpenType feature labels")
                }
                .pickerStyle(.radioGroup)
                .help(
                    "Default for every open project and new imports. "
                        + "Review can override this for the selected file only."
                )
            } footer: {
                Text(
                    "Preserve keeps existing feature name IDs. "
                        + "Repack renumbers them to start at 256 to avoid reserved low IDs."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 180)
        .padding(.bottom, 8)
    }

    private var defaultStrategyBinding: Binding<NameIDStrategy> {
        Binding(
            get: { layout.defaultNameIDStrategy },
            set: { newValue in
                layout.defaultNameIDStrategy = newValue
                editor.applyAppDefaultNameIDStrategy(newValue)
            }
        )
    }
}
