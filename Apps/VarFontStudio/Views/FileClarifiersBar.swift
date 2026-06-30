import SwiftUI
import VarFontCore

/// Per-file naming metadata — compact section above the axis tree.
struct FileClarifiersBar: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var isExpanded = false

    var body: some View {
        Group {
            if editor.hasOpenProjects, let font = editor.selectedFont {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 5) {
                        postscriptPrefixRow(fontID: font.id)
                        ForEach(FileClarifierCategory.allCases, id: \.self) { category in
                            clarifierRow(category: category, fontID: font.id)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                } label: {
                    disclosureLabel(font: font)
                }
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .padding(.vertical, 6)
                .onChange(of: editor.selectedFontID) { _, _ in
                    if let font = editor.selectedFont {
                        syncExpansion(for: font)
                    }
                }
                .onAppear {
                    syncExpansion(for: font)
                }

                Divider()
            }
        }
    }

    private func disclosureLabel(font: FontDocument) -> some View {
        StudioDisclosureLabelRow {
            HStack(spacing: StudioSpacing.controlGap) {
                Text("File naming")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)

                if !isExpanded {
                    Text(collapsedSummary(for: font))
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        } trailing: {
            HStack(spacing: StudioSpacing.controlGap) {
                Button("Infer") {
                    editor.inferFileClarifiersForSelectedFont()
                }
                .font(StudioTypography.meta)
                .help("Guess clarifiers from filename and existing names")
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(!isExpanded)

                clarifierActions(font: font)
                    .opacity(isExpanded ? 1 : 0)
                    .allowsHitTesting(isExpanded)
            }
        }
    }

    private func collapsedSummary(for font: FontDocument) -> String {
        var parts: [String] = []
        let prefix = editor.familyPSPrefix(for: font.id)
        if !prefix.isEmpty {
            parts.append("PS: \(prefix)")
        }
        if editor.isSelectedFontMaster, editor.projectHasMultipleFiles {
            parts.append("Master file")
        } else {
            let labels = editor.clarifierLabels(for: font.id).map(\.label)
            if labels.isEmpty {
                parts.append("No clarifiers")
            } else {
                parts.append(labels.joined(separator: " · "))
            }
        }
        return parts.isEmpty ? "Defaults" : parts.joined(separator: " · ")
    }

    private func clarifierActions(font: FontDocument) -> some View {
        HStack(spacing: StudioSpacing.controlGap) {
            if editor.isSelectedFontMaster, editor.projectHasMultipleFiles {
                Button("Push axis tree…") {
                    editor.pushMasterAxisTreeToAllFonts()
                }
                .font(StudioTypography.meta)
                .help("Copy master axis stops to all other files in this project")
            }

            if editor.isSelectedFontMaster, editor.projectHasMultipleFiles,
               !editor.clarifierLabels(for: font.id).isEmpty {
                Button("Clear clarifiers") {
                    editor.clearFileClarifiers(for: font.id)
                }
                .font(StudioTypography.meta)
                .help("Remove clarifiers stored on the master file (they belong on variant files)")
            }

            if !editor.isSelectedFontMaster {
                Button("Set as master") {
                    editor.setFontAsMaster(fontID: font.id)
                }
                .font(StudioTypography.meta)
            }

            Button("Infer") {
                editor.inferFileClarifiersForSelectedFont()
            }
            .font(StudioTypography.meta)
            .help("Guess clarifiers from filename and existing names")
        }
    }

    private func postscriptPrefixRow(fontID: String) -> some View {
        HStack(spacing: 8) {
            Text("PostScript prefix")
                .font(StudioTypography.meta)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            StudioTextField(
                placeholder: "MilgramVariable",
                text: psPrefixBinding(for: fontID)
            )
            .help("Prefix for fvar instance PostScript names — from name ID 25, or ID 6 before the first hyphen")
        }
    }

    private func clarifierRow(category: FileClarifierCategory, fontID: String) -> some View {
        HStack(spacing: 8) {
            Text(category.rawValue)
                .font(StudioTypography.meta)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)

            if editor.areFileClarifiersEditable {
                StudioTextField(
                    placeholder: categoryPlaceholder(category),
                    text: binding(for: category, fontID: fontID)
                )
                .help(clarifierFieldHelp)
            } else {
                StudioFieldLabel(
                    text: clarifierDisplayValue(category: category, fontID: fontID),
                    foreground: .secondary
                )
                .help("Set on variant files in this project")
            }
        }
    }

    private var clarifierFieldHelp: String {
        "File-level naming token appended before axis stop names. Clear a field to omit that clarifier."
    }

    private func clarifierDisplayValue(category: FileClarifierCategory, fontID: String) -> String {
        let label = editor.clarifierLabels(for: fontID).first { $0.category == category }?.label ?? ""
        return label.isEmpty ? "—" : label
    }

    private func psPrefixBinding(for fontID: String) -> Binding<String> {
        Binding(
            get: { editor.familyPSPrefix(for: fontID) },
            set: { editor.setFamilyPSPrefix($0, for: fontID) }
        )
    }

    private func binding(for category: FileClarifierCategory, fontID: String) -> Binding<String> {
        Binding(
            get: {
                editor.clarifierLabels(for: fontID).first { $0.category == category }?.label ?? ""
            },
            set: { newValue in
                editor.setFileClarifier(category: category, label: newValue, for: fontID)
            }
        )
    }

    private func categoryPlaceholder(_ category: FileClarifierCategory) -> String {
        switch category {
        case .slope: return "Italic"
        case .width: return "Condensed"
        case .optical: return "Display"
        case .custom: return "Rounded Stencil Rough"
        }
    }

    private func syncExpansion(for font: FontDocument) {
        if editor.isSelectedFontMaster, editor.projectHasMultipleFiles {
            isExpanded = !editor.familyPSPrefix(for: font.id).isEmpty
        } else {
            isExpanded = !editor.clarifierLabels(for: font.id).isEmpty
                || !editor.familyPSPrefix(for: font.id).isEmpty
        }
    }
}
