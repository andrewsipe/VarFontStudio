import AppKit
import SwiftUI
import VarFontCore

// MARK: - Shared review content

struct CommitDiffReviewView: View {
    @EnvironmentObject private var editor: EditorViewModel
    let session: CommitPreflightSession
    var scrollMaxHeight: CGFloat? = 420

    @State private var showStat = true
    @State private var showInstances = true
    @State private var showNameIDs = true

    private static let reflowColor = Color(red: 0.65, green: 0.55, blue: 0.98)
    private static let phaseColor = Color(red: 0.38, green: 0.65, blue: 0.98)

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            header
            fileClarifiersBanner
            if let summary = session.preflight.summary {
                summaryMetrics(summary, diffReport: session.diffReport)
            }
            if !session.preflight.warnings.isEmpty {
                warningsCard(session.preflight.warnings)
            }
            if !session.preflight.errors.isEmpty {
                errorsCard(session.preflight.errors)
            }

            diffLegend

            ScrollView {
                VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
                    diffSection(
                        title: "STAT table",
                        detail: statSectionDetail(session.diffReport.statRows),
                        pills: statSectionPills(session.diffReport.statRows),
                        isExpanded: $showStat
                    ) {
                        statSideBySideTable(session.diffReport.statRows)
                    }

                    diffSection(
                        title: "fvar table",
                        detail: instanceSectionDetail(session.diffReport.instanceRows),
                        pills: instanceSectionPills(session.diffReport.instanceRows),
                        isExpanded: $showInstances
                    ) {
                        instanceSideBySideTable(session.diffReport.instanceRows)
                    }

                    diffSection(
                        title: "name table (≥256)",
                        detail: nameSectionDetail(session.diffReport.nameIDRows),
                        pills: nameSectionPills(session.diffReport.nameIDRows),
                        isExpanded: $showNameIDs
                    ) {
                        nameIDSideBySideTable(session.diffReport.nameIDRows)
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
            Text("TTX state of each table before and after the planned write.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var fileClarifiersBanner: some View {
        let clarifiers = editor.clarifierLabels(for: session.fontID)
        let psPrefix = editor.familyPSPrefix(for: session.fontID)
        if !clarifiers.isEmpty || !psPrefix.isEmpty {
            HStack(spacing: 6) {
                if !psPrefix.isEmpty {
                    Text("PS prefix")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                    Text(psPrefix)
                        .font(StudioTypography.meta.monospaced())
                }
                if !clarifiers.isEmpty {
                    Text("Clarifiers")
                        .font(StudioTypography.meta)
                        .foregroundStyle(.secondary)
                    ForEach(clarifiers) { clarifier in
                        StudioClarifierPill(label: clarifier.label, compact: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func summaryMetrics(_ summary: CommitSummary, diffReport: CommitDiffReport) -> some View {
        let nameRemoved = diffReport.nameIDRows.filter { $0.change == .removed }.count
        let nameAdded = diffReport.nameIDRows.filter { $0.change == .added }.count

        HStack(spacing: 6) {
            summaryMetric(value: "\(summary.instancesWritten)", label: "Instances")
            summaryMetric(value: "\(summary.statValuesWritten)", label: "STAT values")
            summaryMetric(value: "\(summary.nameIDsAllocated.count)", label: "New name IDs")
            summaryMetric(value: "\(nameRemoved)", label: "Removed")
            summaryMetric(value: "\(nameAdded)", label: "Added")
        }
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .default))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 72)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private struct DiffSectionPill: Identifiable {
        let id = UUID()
        let text: String
        let foreground: Color
        let background: Color
        let border: Color
    }

    private func sectionPill(_ text: String, style: DiffPillStyle) -> DiffSectionPill {
        DiffSectionPill(
            text: text,
            foreground: style.foreground,
            background: style.background,
            border: style.border
        )
    }

    private enum DiffPillStyle {
        case removed, added, changed, reflowed, unchanged, protected

        var foreground: Color {
            switch self {
            case .removed: Color(red: 0.97, green: 0.44, blue: 0.44)
            case .added: Color(red: 0.29, green: 0.87, blue: 0.50)
            case .changed: StudioColors.warningForeground
            case .reflowed: CommitDiffReviewView.reflowColor
            case .unchanged: .secondary
            case .protected: CommitDiffReviewView.phaseColor
            }
        }

        var background: Color { foreground.opacity(0.12) }
        var border: Color { foreground.opacity(0.22) }
    }

    @ViewBuilder
    private func diffSection<Content: View>(
        title: String,
        detail: String,
        pills: [DiffSectionPill],
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(StudioTypography.bodyMedium)
                        Text(detail)
                            .font(StudioTypography.meta)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                        ForEach(pills) { pill in
                            Text(pill.text)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(pill.foreground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(pill.background, in: Capsule())
                                .overlay(Capsule().strokeBorder(pill.border, lineWidth: 0.5))
                        }
                    }
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

    private func statSectionDetail(_ rows: [CommitDiffStatRow]) -> String {
        let tags = Array(Set(rows.map(\.tag))).sorted().joined(separator: ", ")
        return "\(tags) · \(rows.count) values"
    }

    private func instanceSectionDetail(_ rows: [CommitDiffInstanceRow]) -> String {
        let tags = rows.compactMap { $0.key.split(separator: ":").first.map(String.init) }
        let unique = Array(Set(tags)).sorted().joined(separator: ", ")
        let tagLabel = unique.isEmpty ? "instances" : "\(unique) · \(rows.count) instances"
        return tagLabel
    }

    private func nameSectionDetail(_ rows: [CommitDiffNameIDRow]) -> String {
        "full rebuild · \(rows.count) slots"
    }

    private func statSectionPills(_ rows: [CommitDiffStatRow]) -> [DiffSectionPill] {
        var pills: [DiffSectionPill] = []
        let reflowed = rows.filter(statRowIsReflow).count
        let renamed = rows.filter { $0.change == .changed && !statRowIsReflow($0) }.count
        let same = rows.filter { $0.change == .unchanged }.count
        if reflowed > 0 { pills.append(sectionPill("\(reflowed) reflowed", style: .reflowed)) }
        if renamed > 0 { pills.append(sectionPill("\(renamed) renamed", style: .changed)) }
        if same > 0 { pills.append(sectionPill("\(same) same", style: .unchanged)) }
        return pills
    }

    private func instanceSectionPills(_ rows: [CommitDiffInstanceRow]) -> [DiffSectionPill] {
        var pills: [DiffSectionPill] = []
        let changed = rows.filter { $0.change == .changed }.count
        let same = rows.filter { $0.change == .unchanged }.count
        let added = rows.filter { $0.change == .added }.count
        let removed = rows.filter { $0.change == .removed }.count
        if removed > 0 { pills.append(sectionPill("\(removed) removed", style: .removed)) }
        if added > 0 { pills.append(sectionPill("\(added) added", style: .added)) }
        if changed > 0 { pills.append(sectionPill("\(changed) renamed", style: .changed)) }
        if same > 0 { pills.append(sectionPill("\(same) same", style: .unchanged)) }
        return pills
    }

    private func nameSectionPills(_ rows: [CommitDiffNameIDRow]) -> [DiffSectionPill] {
        var pills: [DiffSectionPill] = []
        let removed = rows.filter { $0.change == .removed }.count
        let added = rows.filter { $0.change == .added }.count
        let changed = rows.filter { $0.change == .changed }.count
        let protected = rows.filter { $0.afterRole == "protected_ot_label" }.count
        if removed > 0 { pills.append(sectionPill("\(removed) removed", style: .removed)) }
        if added > 0 { pills.append(sectionPill("\(added) added", style: .added)) }
        if changed > 0 { pills.append(sectionPill("\(changed) changed", style: .changed)) }
        if protected > 0 { pills.append(sectionPill("\(protected) protected", style: .protected)) }
        return pills
    }

    private func statRowIsReflow(_ row: CommitDiffStatRow) -> Bool {
        row.change == .changed
            && row.beforeName == row.afterName
            && row.beforeNameID != row.afterNameID
    }

    private var diffLegend: some View {
        HStack(spacing: 14) {
            legendSwatch(color: .red, label: "Removed")
            legendSwatch(color: .green, label: "Added")
            legendSwatch(color: Self.reflowColor, label: "ID reflowed")
            legendSwatch(color: StudioColors.warningForeground, label: "Renamed")
            legendSwatch(color: Self.phaseColor, label: "Protected OT")
            legendSwatch(color: .secondary, label: "Same")
        }
        .font(StudioTypography.meta)
        .foregroundStyle(.secondary)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func statSideBySideTable(_ rows: [CommitDiffStatRow]) -> some View {
        ttxSideBySide(afterSubtitle: nil) {
            ForEach(rows) { row in
                statTTXCell(row: row, side: .before)
            }
        } after: {
            ForEach(rows) { row in
                statTTXCell(row: row, side: .after)
            }
        }
    }

    private func instanceSideBySideTable(_ rows: [CommitDiffInstanceRow]) -> some View {
        ttxSideBySide(afterSubtitle: nil) {
            ForEach(rows) { row in
                instanceTTXCell(row: row, side: .before)
            }
        } after: {
            ForEach(rows) { row in
                instanceTTXCell(row: row, side: .after)
            }
        }
    }

    private func nameIDSideBySideTable(_ rows: [CommitDiffNameIDRow]) -> some View {
        let items = nameIDTableItems(rows)
        return VStack(alignment: .leading, spacing: 6) {
            ttxSideBySide(afterSubtitle: "rebuilt from 256") {
                ForEach(items) { item in
                    switch item {
                    case .phase(let title):
                        ttxPhaseHeader(title)
                    case .slot(let row):
                        nameIDTTXCell(row: row, side: .before)
                    }
                }
            } after: {
                ForEach(items) { item in
                    switch item {
                    case .phase(let title):
                        ttxPhaseHeader(title)
                    case .slot(let row):
                        nameIDTTXCell(row: row, side: .after)
                    }
                }
            }
            Text("Each row is one name ID slot. Phase headers follow the rebuilt write order.")
                .font(StudioTypography.meta)
                .foregroundStyle(.tertiary)
            if rows.contains(where: { $0.afterRole == "protected_ot_label" }) {
                Text("OpenType feature labels are kept at their current IDs for now. A future pass will unlink and reflow them ahead of STAT/fvar naming.")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private enum NameIDTableItem: Identifiable {
        case phase(String)
        case slot(CommitDiffNameIDRow)

        var id: String {
            switch self {
            case .phase(let title):
                return "phase-\(title)"
            case .slot(let row):
                return "slot-\(row.id)"
            }
        }
    }

    private func nameIDTableItems(_ rows: [CommitDiffNameIDRow]) -> [NameIDTableItem] {
        var items: [NameIDTableItem] = []
        var lastPhase: String?
        for row in rows {
            let phase = nameIDPhase(for: row)
            if phase != lastPhase {
                items.append(.phase(phase))
                lastPhase = phase
            }
            items.append(.slot(row))
        }
        return items
    }

    private func nameIDPhase(for row: CommitDiffNameIDRow) -> String {
        if let role = row.afterRole {
            switch role {
            case "axis_display_name":
                return "Axis display names"
            case "stat_axis_value":
                return "STAT axis values"
            case "instance_subfamily", "instance_postscript", "elided_fallback":
                return "fvar instance names + PostScript"
            case "protected_ot_label":
                return "OpenType feature labels"
            default:
                return "Other records"
            }
        }
        return nameIDPhaseFromBefore(row.beforeDescription)
    }

    private func nameIDPhaseFromBefore(_ description: String?) -> String {
        guard let description else { return "Other records" }
        let lower = description.lowercased()
        if lower.contains("fvar axis") { return "Axis display names" }
        if lower.contains("stat") { return "STAT axis values" }
        if lower.contains("fvar instance") || lower.contains("postscript") { return "fvar instance names + PostScript" }
        if lower.contains("name table only") { return "OpenType feature labels" }
        return "Other records"
    }

    private func ttxPhaseHeader(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            Spacer(minLength: 0)
        }
        .background(Color.primary.opacity(0.04))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private enum TTXSide {
        case before
        case after
    }

    private func ttxSideBySide<Before: View, After: View>(
        afterSubtitle: String?,
        @ViewBuilder before: () -> Before,
        @ViewBuilder after: () -> After
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ttxColumn(title: "Before", subtitle: nil, content: before)
            ttxColumn(title: "After", subtitle: afterSubtitle, content: after)
        }
    }

    private func ttxColumn<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title)
                    .font(StudioTypography.sectionLabel)
                    .foregroundStyle(title == "Before" ? .tertiary : .primary)
                if let subtitle {
                    Text(subtitle)
                        .font(StudioTypography.meta)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))

            VStack(spacing: 0) {
                content()
            }
        }
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: StudioRadius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: StudioRadius.chip)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ttxRow(
        annotation: CommitDiffChangeKind,
        key: String,
        value: String?,
        role: String?,
        side: TTXSide,
        reflow: Bool = false,
        protected: Bool = false
    ) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(ttxAnnotationColor(annotation, side: side, reflow: reflow, protected: protected))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let value, !value.isEmpty {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(ttxValueColor(annotation, side: side, reflow: reflow, protected: protected))
                            .lineLimit(1)
                        if let role, !role.isEmpty {
                            Text(displayRoleLabel(role))
                                .font(StudioTypography.meta)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("—")
                        .font(StudioTypography.monoMeta)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func statTTXCell(row: CommitDiffStatRow, side: TTXSide) -> some View {
        let key = "AxisValue \(row.tag)=\(StudioFormatting.axisValue(row.value))"
        let name = side == .before ? row.beforeName : row.afterName
        let nameID = side == .before ? row.beforeNameID : row.afterNameID
        let value: String? = {
            guard let name, !name.isEmpty else { return nil }
            var text: String
            if let nameID {
                text = "nameID=\(nameID) \"\(name)\""
            } else {
                text = "\"\(name)\""
            }
            if side == .after, row.afterStatFormat == 3, let linked = row.afterLinkedValue {
                text += "  format 3 → \(StudioFormatting.axisValue(linked))"
            }
            return text
        }()
        let reflow = statRowIsReflow(row)
        return ttxRow(
            annotation: row.change,
            key: key,
            value: value,
            role: nil,
            side: side,
            reflow: reflow
        )
    }

    private func instanceTTXCell(row: CommitDiffInstanceRow, side: TTXSide) -> some View {
        let name = side == .before ? row.beforeName : row.afterName
        let value = name.map { "\"\($0)\"" }
        return ttxRow(
            annotation: row.change,
            key: "Instance \(row.key)",
            value: value,
            role: nil,
            side: side
        )
    }

    private func nameIDTTXCell(row: CommitDiffNameIDRow, side: TTXSide) -> some View {
        let string = side == .before ? row.beforeString : row.afterString
        let role = side == .before ? row.beforeDescription : row.afterRole
        let value = string.map { "\(row.id) \"\($0)\"" }
        let isProtected = row.afterRole == "protected_ot_label"
        return ttxRow(
            annotation: row.change,
            key: "nameID \(row.id)",
            value: value,
            role: role,
            side: side,
            protected: isProtected
        )
    }

    private func displayRoleLabel(_ role: String) -> String {
        switch role {
        case "protected_ot_label":
            return "OT feature label (protected)"
        case "axis_display_name":
            return "axis_display_name"
        case "stat_axis_value":
            return "stat_axis_value"
        case "instance_subfamily":
            return "instance_subfamily"
        case "instance_postscript":
            return "instance_postscript"
        case "elided_fallback":
            return "elided_fallback"
        default:
            return role
        }
    }

    private func ttxAnnotationColor(
        _ change: CommitDiffChangeKind,
        side: TTXSide,
        reflow: Bool = false,
        protected: Bool = false
    ) -> Color {
        if protected { return Self.phaseColor }
        if reflow { return Self.reflowColor }
        switch change {
        case .added:
            return side == .after ? .green : .clear
        case .removed:
            return side == .before ? .red : .clear
        case .changed:
            return StudioColors.warningForeground
        case .unchanged:
            return .clear
        }
    }

    private func ttxValueColor(
        _ change: CommitDiffChangeKind,
        side: TTXSide,
        reflow: Bool = false,
        protected: Bool = false
    ) -> Color {
        if protected { return Self.phaseColor }
        if reflow { return Self.reflowColor }
        switch change {
        case .added:
            return side == .after ? .green : .primary
        case .removed:
            return side == .before ? .red : .primary
        case .changed:
            return StudioColors.warningForeground
        case .unchanged:
            return .primary
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
        .frame(width: 900, height: 680)
    }

    private var sheetFooter: some View {
        SaveReviewActionFooter(session: session, projectID: session.projectID, includeCancel: true)
    }
}

// MARK: - Shared save actions

private struct SaveReviewActionFooter: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let session: CommitPreflightSession
    let projectID: String
    var includeCancel: Bool = false

    private var canSaveToRememberedPath: Bool {
        editor.canSaveToRememberedPath(forProjectID: projectID, fontID: session.fontID)
    }

    private var showsSaveAll: Bool {
        editor.fontsForSaveReview(projectID: projectID).count > 1
    }

    var body: some View {
        HStack {
            Button("Export JSON…") {
                editor.exportCommitJSON(session: session)
            }

            if showsSaveAll {
                Button("Save All…") {
                    editor.saveAllFiles(inProjectID: projectID)
                }
                .disabled(!session.preflight.ok || editor.isSaveActionBlocked)
                .help("Write all dirty files in this project")
            }

            Spacer()

            if includeCancel {
                Button("Cancel") {
                    editor.dismissCommitDiffSheet()
                    dismiss()
                }
            }

            if canSaveToRememberedPath {
                Button("Save Copy…") {
                    editor.presentSavePanel(for: session)
                }
                .disabled(!session.preflight.ok || editor.isSaveActionBlocked)

                Button("Save") {
                    editor.save(session: session)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!session.preflight.ok || editor.isSaveActionBlocked)
                .help("Write to the last saved copy path")
            } else {
                Button("Save Copy…") {
                    editor.presentSavePanel(for: session)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!session.preflight.ok || editor.isSaveActionBlocked)
                .help("Choose a path for a patched font copy")
            }
        }
    }
}

// MARK: - Save Review window

private struct SaveReviewFileTabBar: View {
    let projectID: String
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        let fonts = editor.fontsForSaveReview(projectID: projectID)
        if fonts.count > 1 {
            HStack(spacing: StudioSpacing.controlGap) {
                Text("FILE")
                    .font(StudioTypography.sectionLabel)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(fonts) { font in
                            fileChip(font)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func fileChip(_ font: FontDocument) -> some View {
        let isSelected = editor.saveReviewSelectedFontID(forProjectID: projectID) == font.id
        let isLoading = editor.isSaveReviewLoading(forProjectID: projectID, fontID: font.id)

        return Button {
            editor.selectSaveReviewFont(projectID: projectID, fontID: font.id)
        } label: {
            StudioTabChip(isSelected: isSelected) {
                Text(editor.fontBasename(for: font))
                    .font(StudioTypography.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
            } trailing: {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!editor.canPreviewSaveReview(forProjectID: projectID, fontID: font.id))
    }
}

struct SaveReviewWindow: View {
    let projectID: String
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    private var selectedFontID: String? {
        editor.saveReviewSelectedFontID(forProjectID: projectID)
    }

    private var session: CommitPreflightSession? {
        editor.saveReviewSession(forProjectID: projectID)
    }

    private var isLoadingCurrentFile: Bool {
        guard let selectedFontID else { return false }
        return editor.isSaveReviewLoading(forProjectID: projectID, fontID: selectedFontID)
    }

    var body: some View {
        VStack(spacing: 0) {
            SaveReviewFileTabBar(projectID: projectID)
            if editor.fontsForSaveReview(projectID: projectID).count > 1 {
                Divider()
            }

            if let session {
                ScrollView {
                    CommitDiffReviewView(session: session, scrollMaxHeight: nil)
                        .padding(20)
                }
                Divider()
                windowFooter(session: session)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
            } else if isLoadingCurrentFile {
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
                        refreshCurrentFile()
                    }
                    .disabled(!canRefreshCurrentFile)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 920, minHeight: 680)
        .navigationTitle(editor.saveReviewWindowTitle(forProjectID: projectID))
        .background(SaveReviewWindowConfigurator())
        .onAppear(perform: dismissRestoredEmptyWindowIfNeeded)
        .onChange(of: editor.openProjects) { _, projects in
            if !projects.contains(where: { $0.id == projectID }) {
                dismissWindow(id: "save-review", value: projectID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            editor.clearSaveReviewState()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    refreshCurrentFile()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!canRefreshCurrentFile || isLoadingCurrentFile)
                .help("Re-read the font on disk and rebuild the diff")
            }
        }
    }

    private var canRefreshCurrentFile: Bool {
        guard let selectedFontID else { return false }
        return editor.canPreviewSaveReview(forProjectID: projectID, fontID: selectedFontID)
    }

    private func refreshCurrentFile() {
        editor.refreshCommitDiffPreview(forProjectID: projectID, fontID: selectedFontID)
    }

    private func dismissRestoredEmptyWindowIfNeeded() {
        guard session == nil, !isLoadingCurrentFile else { return }
        guard !editor.saveReviewWasExplicitlyOpened(forProjectID: projectID) else { return }
        dismissWindow(id: "save-review", value: projectID)
        SaveReviewWindowLifecycle.closeRestoredWindows()
    }

    private func windowFooter(session: CommitPreflightSession) -> some View {
        SaveReviewActionFooter(session: session, projectID: projectID)
    }
}

/// Opt out of macOS window restoration for the Save Review auxiliary window (macOS 14).
private struct SaveReviewWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(window: view.window)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(window: nsView.window)
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.isRestorable = false
        window.identifier = NSUserInterfaceItemIdentifier(SaveReviewWindowLifecycle.identifier)
    }
}
