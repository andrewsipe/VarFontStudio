import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MissingFontsSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let request = editor.workspace.missingFontsRequest {
            sheetContent(request)
        }
    }

    @ViewBuilder
    private func sheetContent(_ request: MissingFontsRequest) -> some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Locate missing fonts")
                .font(StudioTypography.emphasis)

            Text("Paths are stored relative to the project file. Choose each font if it moved on disk.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: StudioSpacing.controlGap) {
                ForEach(request.entries) { entry in
                    missingFontRow(entry)
                }
            }

            HStack {
                Button("Cancel") {
                    editor.cancelMissingFontsRequest()
                    dismiss()
                }
                Spacer()
                Button("Continue") {
                    editor.completeMissingFontsRequest()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!request.allResolved)
            }
        }
        .padding(StudioSpacing.sheetOuterPadding)
        .frame(width: 480)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func missingFontRow(_ entry: MissingFontEntry) -> some View {
        HStack(alignment: .center, spacing: StudioSpacing.sectionGap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.basename)
                    .font(StudioTypography.body)
                    .fontWeight(.medium)
                Text(entry.storedPath)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusPill(for: entry)

            Button(entry.isResolved ? "Relocate…" : "Locate…") {
                editor.locateMissingFont(fontID: entry.fontID)
            }
        }
        .padding(StudioSpacing.cardPadding)
        .background(StudioColors.surfaceMuted, in: RoundedRectangle(cornerRadius: StudioRadius.chip))
    }

    @ViewBuilder
    private func statusPill(for entry: MissingFontEntry) -> some View {
        Text(entry.isResolved ? "Found" : "Missing")
            .font(StudioTypography.monoMeta)
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, 3)
            .background(
                (entry.isResolved ? Color.green.opacity(0.2) : Color.orange.opacity(0.25)),
                in: Capsule()
            )
            .foregroundStyle(entry.isResolved ? Color.green : Color.orange)
    }
}
