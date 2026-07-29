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
                    Text("Preserve existing feature name IDs").tag(NameIDStrategy.preserve)
                    Text("Reflow feature labels (from ID 256)").tag(NameIDStrategy.reflow)
                } label: {
                    Text("OpenType feature labels")
                }
                .pickerStyle(.radioGroup)
                .help(
                    "Default for every open project and new imports. "
                        + "Save Review can override this for the selected file only."
                )
            } footer: {
                Text(
                    "Preserve keeps existing OpenType feature name IDs. "
                        + "Reflow renumbers them starting at 256 so STAT and fvar rebuilds don’t collide."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 180)
        .padding(.bottom, StudioSpace.x2)
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
