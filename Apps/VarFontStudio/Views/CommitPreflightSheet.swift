import SwiftUI
import VarFontCore

struct CommitPreflightSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: CommitPreflightSession

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Save preview")
                .font(StudioTypography.emphasis)

            Text("Review what vfcommit will write before saving a patched copy.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)

            if let summary = session.preflight.summary {
                summaryCard(summary)
            }

            if !session.preflight.warnings.isEmpty {
                warningsCard(session.preflight.warnings)
            }

            if !session.preflight.errors.isEmpty {
                errorsCard(session.preflight.errors)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    editor.commitPreflightSession = nil
                    dismiss()
                }
                Button("Save Copy…") {
                    editor.presentSavePanel(for: session)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!session.preflight.ok)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    @ViewBuilder
    private func summaryCard(_ summary: CommitSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryRow("Instances to write", value: "\(summary.instancesWritten)")
            summaryRow("STAT axis values", value: "\(summary.statValuesWritten)")
            summaryRow("Existing fvar instances replaced", value: "\(summary.wipedInstanceCount)")
            summaryRow("New name IDs", value: "\(summary.nameIDsAllocated.count)")
            if !summary.protectedNameIDs.isEmpty {
                summaryRow("Protected name IDs", value: "\(summary.protectedNameIDs.count)")
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: StudioRadius.chip))
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(StudioTypography.caption.monospacedDigit())
        }
    }

    @ViewBuilder
    private func warningsCard(_ warnings: [PlanWarning]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Warnings")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                Text(warning.message)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .strokeBorder(StudioColors.warningStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func errorsCard(_ errors: [CommitError]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cannot save")
                .font(StudioTypography.sectionLabel)
                .foregroundStyle(.secondary)
            ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                Text(error.message)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
        )
    }
}
