import SwiftUI
import VarFontCore

// MARK: - Shared review content

struct CommitDiffReviewView: View {
    let session: CommitPreflightSession
    var scrollMaxHeight: CGFloat? = 420

    @State private var showStat = true
    @State private var showInstances = true
    @State private var showNameIDs = false

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            header
            if let summary = session.preflight.summary {
                summaryCard(summary)
            }
            if !session.preflight.warnings.isEmpty {
                warningsCard(session.preflight.warnings)
            }
            if !session.preflight.errors.isEmpty {
                errorsCard(session.preflight.errors)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
                    diffSection(
                        title: "STAT axis values",
                        subtitle: "\(session.diffReport.statChangedCount) changed · \(session.diffReport.statRows.count) total",
                        isExpanded: $showStat
                    ) {
                        statTable(session.diffReport.statRows)
                    }

                    diffSection(
                        title: "fvar instances",
                        subtitle: "\(session.diffReport.instanceChangedCount) changed · \(session.diffReport.instanceRows.count) total",
                        isExpanded: $showInstances
                    ) {
                        instanceTable(session.diffReport.instanceRows)
                    }

                    diffSection(
                        title: "Name table (≥256)",
                        subtitle: "\(session.diffReport.nameIDChangedCount) changed · \(session.diffReport.nameIDRows.count) total",
                        isExpanded: $showNameIDs
                    ) {
                        nameIDTable(session.diffReport.nameIDRows)
                    }
                }
            }
            .applyScrollMaxHeight(scrollMaxHeight)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Save review")
                .font(StudioTypography.emphasis)
            Text("Compare the font on disk with the planned write before saving a patched copy.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func summaryCard(_ summary: CommitSummary) -> some View {
        HStack(spacing: StudioSpacing.controlGap) {
            summaryChip("Instances", value: "\(summary.instancesWritten)")
            summaryChip("STAT values", value: "\(summary.statValuesWritten)")
            summaryChip("Replaced fvar", value: "\(summary.wipedInstanceCount)")
            summaryChip("New name IDs", value: "\(summary.nameIDsAllocated.count)")
        }
    }

    private func summaryChip(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(StudioTypography.meta)
                .foregroundStyle(.secondary)
            Text(value)
                .font(StudioTypography.caption.monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: StudioRadius.chip))
    }

    @ViewBuilder
    private func diffSection<Content: View>(
        title: String,
        subtitle: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Text(title)
                        .font(StudioTypography.bodyMedium)
                    Text(subtitle)
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.row))
    }

    private func statTable(_ rows: [CommitDiffStatRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            diffGridHeader(columns: ["Tag", "Value", "Before", "After", "Name ID", "Δ"])
            ForEach(rows) { row in
                diffGridRow {
                    gridCell(row.tag, width: 44, font: StudioTypography.monoMeta)
                    gridCell(StudioFormatting.axisValue(row.value), width: 52, font: StudioTypography.monoMeta, alignment: .trailing)
                    gridCell(row.beforeName ?? "—", flex: 1)
                    gridCell(row.afterName ?? "—", flex: 1)
                    gridCell(statNameIDLabel(row), width: 88, font: StudioTypography.monoMeta)
                    changeBadge(label: statChangeLabel(row))
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
    }

    private func instanceTable(_ rows: [CommitDiffInstanceRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            diffGridHeader(columns: ["Key", "Before", "After", "Δ"])
            ForEach(rows) { row in
                diffGridRow {
                    gridCell(row.key, flex: 1, font: StudioTypography.monoMeta)
                    gridCell(row.beforeName ?? "—", flex: 1)
                    gridCell(row.afterName ?? "—", flex: 1)
                    changeBadge(label: genericChangeLabel(row.change))
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
    }

    private func nameIDTable(_ rows: [CommitDiffNameIDRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            diffGridHeader(columns: ["ID", "Before", "After", "Role", "Δ"])
            ForEach(rows) { row in
                diffGridRow {
                    gridCell(nameIDRangeLabel(row), width: 72, font: StudioTypography.monoMeta)
                    gridCell(nameIDBeforeLabel(row), flex: 1)
                    gridCell(row.afterString ?? "—", flex: 1)
                    gridCell(row.afterRole ?? "—", width: 110)
                    changeBadge(label: nameIDChangeLabel(row))
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
    }

    private func diffGridHeader(columns: [String]) -> some View {
        diffGridRow {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .font(StudioTypography.sectionLabel)
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: index == columns.count - 1 ? 72 : .infinity,
                        alignment: index == 0 ? .leading : (index == columns.count - 1 ? .trailing : .leading)
                    )
            }
        }
        .padding(.bottom, 4)
    }

    private func diffGridRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                content()
            }
            .font(StudioTypography.caption)
            .padding(.vertical, 3)
            Divider()
        }
    }

    @ViewBuilder
    private func gridCell(
        _ text: String,
        width: CGFloat? = nil,
        flex: CGFloat? = nil,
        font: Font = StudioTypography.caption,
        alignment: Alignment = .leading
    ) -> some View {
        let label = Text(text)
            .font(font)
            .lineLimit(1)

        if flex != nil {
            label
                .frame(maxWidth: .infinity, alignment: alignment)
                .layoutPriority(1)
        } else {
            label
                .frame(width: width, alignment: alignment)
        }
    }

    private func statNameIDLabel(_ row: CommitDiffStatRow) -> String {
        switch (row.beforeNameID, row.afterNameID) {
        case let (before?, after?) where before == after:
            return "\(before)"
        case let (before?, after?):
            return "\(before)→\(after)"
        case let (before?, nil):
            return "\(before)"
        case let (nil, after?):
            return "→\(after)"
        default:
            return "—"
        }
    }

    private func statChangeLabel(_ row: CommitDiffStatRow) -> (String, Color) {
        if row.change == .changed, row.beforeName == row.afterName {
            return ("reflow", StudioColors.warningForeground)
        }
        return genericChangeLabel(row.change)
    }

    private func nameIDRangeLabel(_ row: CommitDiffNameIDRow) -> String {
        switch (row.beforeID, row.afterID) {
        case let (before?, after?) where before == after:
            return "\(before)"
        case let (before?, after?):
            return "\(before)→\(after)"
        case let (before?, nil):
            return "\(before)"
        case let (nil, after?):
            return "\(after)"
        default:
            return "—"
        }
    }

    private func nameIDBeforeLabel(_ row: CommitDiffNameIDRow) -> String {
        if let string = row.beforeString, !string.isEmpty {
            if let description = row.beforeDescription, !description.isEmpty {
                return "\(string) · \(description)"
            }
            return string
        }
        return row.beforeDescription ?? "—"
    }

    private func nameIDChangeLabel(_ row: CommitDiffNameIDRow) -> (String, Color) {
        if row.change == .changed,
           row.beforeString == row.afterString,
           row.beforeID != row.afterID {
            return ("reflow", StudioColors.warningForeground)
        }
        return genericChangeLabel(row.change)
    }

    private func genericChangeLabel(_ change: CommitDiffChangeKind) -> (String, Color) {
        switch change {
        case .added: ("added", .green)
        case .removed: ("removed", .red)
        case .changed: ("changed", StudioColors.warningForeground)
        case .unchanged: ("same", .secondary)
        }
    }

    @ViewBuilder
    private func changeBadge(label: (String, Color)) -> some View {
        Text(label.0)
            .font(StudioTypography.meta)
            .foregroundStyle(label.1)
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

private extension View {
    @ViewBuilder
    func applyScrollMaxHeight(_ height: CGFloat?) -> some View {
        if let height {
            frame(maxHeight: height)
        } else {
            self
        }
    }
}

// MARK: - Modal sheet (Save Copy flow)

struct CommitDiffSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: CommitPreflightSession

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            CommitDiffReviewView(session: session)
            sheetFooter
        }
        .padding(20)
        .frame(width: 720, height: 620)
    }

    private var sheetFooter: some View {
        HStack {
            Button("Export JSON…") {
                editor.exportCommitJSON(session: session)
            }
            Spacer()
            Button("Cancel") {
                editor.dismissCommitDiffSheet()
                dismiss()
            }
            Button("Save Copy…") {
                editor.presentSavePanel(for: session)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!session.preflight.ok)
        }
    }
}

// MARK: - Save Review window

struct SaveReviewWindow: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let session = editor.commitDiffSession {
                ScrollView {
                    CommitDiffReviewView(session: session, scrollMaxHeight: nil)
                        .padding(20)
                }
                Divider()
                windowFooter(session: session)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            } else if editor.isBusy {
                VStack(spacing: StudioSpacing.controlGap) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Building save review…")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: StudioSpacing.controlGap) {
                    Text("No preview loaded yet.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.secondary)
                    Button("Refresh") {
                        editor.refreshCommitDiffPreview()
                    }
                    .disabled(!editor.canPreviewSaveReview)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 840, minHeight: 640)
        .navigationTitle(editor.saveReviewWindowTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    editor.refreshCommitDiffPreview()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!editor.canPreviewSaveReview || editor.isBusy)
                .help("Re-read the font on disk and rebuild the diff")
            }
        }
    }

    private func windowFooter(session: CommitPreflightSession) -> some View {
        HStack {
            Button("Export JSON…") {
                editor.exportCommitJSON(session: session)
            }
            Spacer()
            Button("Save Copy…") {
                editor.presentSavePanel(for: session)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!session.preflight.ok)
            .help("Write a patched font copy to disk")
        }
    }
}
