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

            Section {
                Toggle("Offer optional name fields", isOn: optionalNamesBinding)
                    .help(
                        "Version, unique ID, typographic family, and typographic subfamily "
                            + "get a fill action when they are missing. Required names are always offered."
                    )
            } footer: {
                Text(
                    "Turn this off to leave non-required name fields until you add them yourself. "
                        + "Family, subfamily, full name, and PostScript name still need a value before export."
                )
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 280)
        .padding(.bottom, StudioSpace.x2)
    }

    private var optionalNamesBinding: Binding<Bool> {
        Binding(
            get: { layout.offerOptionalCoreNames },
            set: { layout.offerOptionalCoreNames = $0 }
        )
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
