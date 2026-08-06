import SwiftUI
import VarFontCore

/// Middle-column Windows name table editor (platform 3 · encoding 1 · lang 0x409, IDs 0–25).
struct NameTablePanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var analysis: FontAnalysis?
    @State private var loadError: String?
    @State private var filterText = ""
    @State private var showAddPopover = false
    @State private var expandedNameID: Int?
    @State private var hoveredValueFieldID: Int?
    @State private var pendingRemovalNameID: Int?

    /// When hosted under middle-column chrome, the column owns the title header.
    var showsPanelHeader: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsPanelHeader {
                StudioPanelHeader(title: "Names") {
                    if let analysis {
                        namesHeaderMeta(analysis)
                    }
                }
            }

            toolbar
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .frame(height: StudioChromeBand.context)
                .background(StudioColors.surfaceMuted)
                .overlay(alignment: .bottom) { Divider() }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preference(key: NameTableHeaderMetaKey.self, value: headerMetaPreference)
        .task(id: editor.selectedFontID) {
            await reloadAnalysis()
        }
        .onChange(of: editor.selectedFont?.sourcePath) { _, _ in
            Task { await reloadAnalysis() }
        }
        .confirmationDialog(
            removalDialogTitle,
            isPresented: Binding(
                get: { pendingRemovalNameID != nil },
                set: { if !$0 { pendingRemovalNameID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Anyway", role: .destructive) {
                if let nameID = pendingRemovalNameID {
                    commitRemoval(nameID)
                }
                pendingRemovalNameID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRemovalNameID = nil
            }
        } message: {
            Text(removalDialogMessage)
        }
    }

    private var removalDialogTitle: String {
        guard let nameID = pendingRemovalNameID else { return "Remove name ID?" }
        let label = OpenTypeNameTable.standardNameLabel(for: nameID) ?? "nameID \(nameID)"
        return "Remove \(label)?"
    }

    private var removalDialogMessage: String {
        guard let nameID = pendingRemovalNameID else { return "" }
        return WindowsNameTableEditing.removeHelp(nameID: nameID)
    }

    private func requestRemoval(of nameID: Int) {
        if WindowsNameTableEditing.isRemovalDiscouraged(nameID: nameID) {
            pendingRemovalNameID = nameID
        } else {
            commitRemoval(nameID)
        }
    }

    private func commitRemoval(_ nameID: Int) {
        if expandedNameID == nameID { collapseEditor() }
        editor.removeWindowsNameID(nameID, analysis: analysis)
        hoveredValueFieldID = nil
    }

    private var headerMetaPreference: NameTableHeaderMeta? {
        guard let analysis else { return nil }
        let rows = populatedRows(from: analysis)
        return NameTableHeaderMeta(
            populated: rows.count,
            missing: missingIDs.count
        )
    }

    @ViewBuilder
    private var content: some View {
        if editor.selectedFont == nil {
            ContentUnavailableView(
                "No Font Open",
                systemImage: "textformat",
                description: Text("Select a font file to edit Windows name IDs 0–25.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError {
            ContentUnavailableView(
                "Couldn’t Read Names",
                systemImage: "exclamationmark.triangle.fill",
                description: Text(loadError)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if analysis == nil {
            ProgressView("Reading name table…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                requiredIssuesBand
                nameRowsList
            }
        }
    }

    private var nameRowsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredRows) { row in
                    nameRow(row)
                }
            }
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, StudioSpacing.tightGap)

        }
    }

    // MARK: - Empty / placeholder validation

    private var nameIssues: [WindowsNameValidation.Issue] {
        guard let analysis, let font = editor.selectedFont else { return [] }
        return WindowsNameValidation.issues(
            windowsNameTable: analysis.windowsNameTable,
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals,
            familyPSPrefix: font.options.familyPSPrefix
        )
    }

    /// IDs 1/2/4/6 — surfaced as a band because a missing or cleared one has no row to badge.
    private var requiredIssues: [WindowsNameValidation.Issue] { nameIssues.filter(\.isRequired) }

    private func issue(for nameID: Int) -> WindowsNameValidation.Issue? {
        nameIssues.first { $0.nameID == nameID }
    }

    @ViewBuilder
    private var requiredIssuesBand: some View {
        if !requiredIssues.isEmpty {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                StudioConflictAlert(
                    message: requiredIssueSummary,
                    actionTitle: requiredIssues.count > 1 ? "Fix All" : "Fix",
                    action: fixAllRequiredIssues
                )
                ForEach(requiredIssues) { issue in
                    requiredIssueRow(issue)
                }
            }
            .padding(.horizontal, StudioSpacing.panelHorizontal)
            .padding(.vertical, StudioSpacing.panelVertical)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    private var requiredIssueSummary: String {
        let ids = requiredIssues.map { "\($0.nameID)" }.joined(separator: ", ")
        if requiredIssues.count == 1 {
            return "Required name ID \(ids) needs a value before export."
        }
        return "\(requiredIssues.count) required name IDs need values before export: \(ids)."
    }

    private func requiredIssueRow(_ issue: WindowsNameValidation.Issue) -> some View {
        HStack(alignment: .top, spacing: StudioSpacing.rowGap) {
            Text("\(issue.nameID)")
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(issue.label)
                    .font(StudioTypography.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(issue.message)
                    .font(StudioTypography.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            StudioFlatButton(title: fixTitle(for: issue), size: .compact) {
                applyFix(for: issue)
            }
            .help(fixHelp(for: issue))
        }
        .padding(.leading, StudioSpace.x1)
    }

    /// One-click resolution offered for an issue. Restoring the file record beats a policy
    /// fill when the record was only cleared by an edit — it is the least surprising undo.
    private enum NameFieldFix {
        case restore(String)
        case fill(NamePolicies.Suggestion)
        case add
        case edit
    }

    private func fix(for issue: WindowsNameValidation.Issue) -> NameFieldFix {
        if issue.problem == .cleared,
           let fileValue = WindowsNameTableEditing.analysisString(
               nameID: issue.nameID,
               windowsNameTable: analysis?.windowsNameTable ?? []
           ),
           WindowsNameValidation.isUsable(fileValue) {
            return .restore(fileValue)
        }
        if let suggestion = policySuggestion(for: issue.nameID),
           WindowsNameValidation.isUsable(suggestion.value) {
            return .fill(suggestion)
        }
        // Adding an ID that is already on screen would blank it, so only offer Add when gone.
        switch issue.problem {
        case .missing, .cleared: return .add
        case .empty, .placeholder, .controlCharacters: return .edit
        }
    }

    private func fixTitle(for issue: WindowsNameValidation.Issue) -> String {
        switch fix(for: issue) {
        case .restore: return "Restore"
        case .fill: return "Fill"
        case .add: return "Add"
        case .edit: return "Edit"
        }
    }

    private func fixHelp(for issue: WindowsNameValidation.Issue) -> String {
        switch fix(for: issue) {
        case .restore(let value): return "Restore from file\n→ \(value)"
        case .fill(let suggestion): return "Fill from font · \(suggestion.source)\n→ \(suggestion.value)"
        case .add: return "Add nameID \(issue.nameID) and type a value"
        case .edit: return "Open nameID \(issue.nameID) and type a value"
        }
    }

    private func applyFix(for issue: WindowsNameValidation.Issue) {
        switch fix(for: issue) {
        case .restore:
            editor.addWindowsNameID(issue.nameID)
        case .fill(let suggestion):
            editor.applyWindowsNamePolicy(nameID: issue.nameID, value: suggestion.value)
        case .add:
            editor.addWindowsNameID(issue.nameID)
            expandedNameID = issue.nameID
        case .edit:
            expandedNameID = issue.nameID
        }
    }

    private func fixAllRequiredIssues() {
        for issue in requiredIssues where !isEditOnly(fix(for: issue)) {
            applyFix(for: issue)
        }
        // Anything left needs typing; focus the first so the user lands in the right field.
        if let manual = requiredIssues.first(where: { isEditOnly(fix(for: $0)) }) {
            expandedNameID = manual.nameID
        }
    }

    private func isEditOnly(_ fix: NameFieldFix) -> Bool {
        if case .edit = fix { return true }
        return false
    }

    private var toolbar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            StudioSearchField(text: $filterText, placeholder: "Filter IDs…")
            StudioFlatButton(
                title: "Add ID…",
                size: .compact,
                isEnabled: !missingIDs.isEmpty
            ) {
                showAddPopover = true
            }
            .popover(isPresented: $showAddPopover, arrowEdge: .bottom) {
                addIDPopover
            }
        }
    }

    // MARK: - Add ID popover (grouped)

    /// IDs a working font should almost always populate: the core identity block
    /// plus the typographic-family pair that variable fonts rely on for STAT/OS name resolution.
    private static let coreNameIDs: [Int] = [1, 2, 3, 4, 5, 6, 16, 17]
    /// Attribution block: legal + who-made-this.
    private static let creditNameIDs: [Int] = [0, 7, 8, 9]

    private var missingCoreIDs: [Int] { Self.coreNameIDs.filter { missingIDs.contains($0) } }
    private var missingCreditIDs: [Int] { Self.creditNameIDs.filter { missingIDs.contains($0) } }
    private var missingOtherIDs: [Int] {
        missingIDs.filter { !Self.coreNameIDs.contains($0) && !Self.creditNameIDs.contains($0) }
    }

    private var addIDPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Windows name ID")
                .font(StudioTypography.meta.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, StudioSpace.x3)
                .padding(.top, StudioSpace.x2_5)
                .padding(.bottom, StudioSpacing.panelVertical)

            addIDGroupSection(
                title: "Core Identity",
                quickAddTitle: "Add all core fields",
                ids: missingCoreIDs
            )
            addIDGroupSection(
                title: "Credits",
                quickAddTitle: "Add all credit fields",
                ids: missingCreditIDs
            )

            if !missingOtherIDs.isEmpty {
                addIDSectionHeader("Other")
                ForEach(missingOtherIDs, id: \.self) { nameID in
                    addIDRow(nameID)
                }
            }
        }
        .frame(width: NameTableLayout.addPopoverWidth)
        .padding(.bottom, StudioSpace.x2)
    }

    @ViewBuilder
    private func addIDGroupSection(title: String, quickAddTitle: String, ids: [Int]) -> some View {
        if !ids.isEmpty {
            addIDSectionHeader(title)
            if ids.count > 1 {
                Button {
                    for nameID in ids { editor.addWindowsNameID(nameID) }
                    showAddPopover = false
                    expandedNameID = ids.first
                } label: {
                    HStack(spacing: StudioSpacing.tightGap) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(StudioColors.brand)
                        Text(quickAddTitle)
                            .font(StudioTypography.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        Text("\(ids.count)")
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, StudioSpace.x3)
                    .padding(.vertical, StudioSpacing.panelVertical)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.row))
            }
            ForEach(ids, id: \.self) { nameID in
                addIDRow(nameID)
            }
            Divider()
                .padding(.horizontal, StudioSpace.x3)
                .padding(.vertical, StudioSpacing.tightGap)
        }
    }

    private func addIDSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(StudioTypography.meta.weight(.semibold))
            .foregroundStyle(.tertiary)
            .kerning(0.4)
            .padding(.horizontal, StudioSpace.x3)
            .padding(.top, StudioSpacing.tightGap)
            .padding(.bottom, StudioSpace.x1)
    }

    private func addIDRow(_ nameID: Int) -> some View {
        Button {
            editor.addWindowsNameID(nameID)
            showAddPopover = false
            expandedNameID = nameID
        } label: {
            HStack {
                Text("\(nameID)")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .frame(width: NameTableLayout.nameIDColumnWidth, alignment: .trailing)
                Text(OpenTypeNameTable.standardNameLabel(for: nameID) ?? "nameID \(nameID)")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, StudioSpace.x3)
            .padding(.vertical, StudioSpacing.panelVertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.row))
    }

    private func namesHeaderMeta(_ analysis: FontAnalysis) -> some View {
        let rows = populatedRows(from: analysis)
        let missing = missingIDs.count
        return HStack(spacing: StudioSpacing.instanceRowVertical) {
            Text("\(rows.count)")
                .foregroundStyle(.primary)
            Text("populated")
                .foregroundStyle(.secondary)
            if missing > 0 {
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("\(missing)")
                    .foregroundStyle(.secondary)
                Text("missing")
                    .foregroundStyle(.secondary)
            }
            Text("·")
                .foregroundStyle(.quaternary)
            Text("Win 3/1/409")
                .foregroundStyle(.tertiary)
        }
        .font(StudioTypography.meta)
    }

    private static let nameLabelRowHeight: CGFloat = 18

    private func nameRow(_ row: WindowsNameTableEditing.Row) -> some View {
        let suggestion = policySuggestion(for: row.nameID)
        let showFill = suggestion.map { $0.value != row.value } ?? false
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            HStack(spacing: StudioSpacing.rowGap) {
                // ID is metadata, not content — de-emphasize it relative to the label.
                // Left-aligned with no reserved column: a fixed trailing-aligned width made
                // single-digit IDs (0, 1, 8, 9) sit noticeably further from the edge than
                // double-digit ones (11, 12, 16), which read as inconsistent indentation.
                Text("\(row.nameID)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(row.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let issue = issue(for: row.nameID) {
                    StudioWarningBadge(help: issue.message) {
                        applyFix(for: issue)
                    }
                }
                if row.isLinkedToPSPrefix {
                    Text("= PostScript prefix")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, StudioSpacing.tightGap)
                        .padding(.vertical, StudioSpacing.instanceRowGap)
                        .background(StudioColors.registrationBackground, in: Capsule())
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if editor.canRevertWindowsName(nameID: row.nameID, analysis: analysis) {
                    Button {
                        if expandedNameID == row.nameID { collapseEditor() }
                        editor.revertWindowsName(nameID: row.nameID)
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(StudioTypography.columnLabel)
                            .frame(width: Self.nameLabelRowHeight, height: Self.nameLabelRowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .studioHoverIcon(tint: StudioColors.brand)
                    .help(revertHelp(for: row.nameID))
                }
                if showFill, let suggestion {
                    Button {
                        editor.applyWindowsNamePolicy(nameID: row.nameID, value: suggestion.value)
                    } label: {
                        Image(systemName: "wand.and.sparkles.inverse")
                            .font(StudioTypography.columnLabel)
                            .frame(width: Self.nameLabelRowHeight, height: Self.nameLabelRowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .studioHoverIcon(tint: StudioColors.brand)
                    .help("Fill from font · \(suggestion.source)\n→ \(suggestion.value)")
                }
            }
            .frame(height: Self.nameLabelRowHeight, alignment: .center)

            valueEditor(for: row)
        }
        .padding(.vertical, StudioSpace.x2_5)
    }

    @ViewBuilder
    private func valueEditor(for row: WindowsNameTableEditing.Row) -> some View {
        let binding = Binding(
            get: { editor.windowsNameValue(nameID: row.nameID, analysis: analysis) },
            set: { editor.setWindowsNameValue(nameID: row.nameID, value: $0) }
        )
        let isExpanded = expandedNameID == row.nameID

        if isExpanded {
            // Bounded height + its own ScrollView: without this, content past
            // maxWrappedLines (a long license block, say) had nowhere to go but
            // arrow-key navigation — there was no scrollable region for the
            // trackpad/mouse wheel to grab once the text exceeded the visible area.
            // Short text still sizes naturally; only long content triggers scrolling.
            ScrollView {
                wrappingValueEditor(
                    binding: binding,
                    placeholder: row.isLinkedToPSPrefix ? "Family PostScript prefix" : "Name string"
                )
            }
            .frame(maxHeight: NameTableLayout.expandedFieldMaxHeight)
        } else {
            ZStack(alignment: .trailing) {
                Button {
                    expandedNameID = row.nameID
                } label: {
                    Text(binding.wrappedValue.isEmpty ? " " : binding.wrappedValue)
                        // Bumped from the label's mono size to give the actual string content —
                        // the thing people are here to read and edit — more visual weight than
                        // its own row chrome. Distinct from the 10pt ID column and 12pt label above.
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(binding.wrappedValue.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, NameTableLayout.editorHorizontalPadding)
                        // Reserve room on the trailing edge so long values truncate before the
                        // hover-revealed clear button, rather than running underneath it.
                        .padding(.trailing, binding.wrappedValue.isEmpty ? 0 : NameTableLayout.clearButtonReservedWidth)
                        .frame(height: NameTableLayout.valueRowHeight, alignment: .center)
                        .background {
                            RoundedRectangle(cornerRadius: StudioRadius.control)
                                .fill(StudioColors.fieldFill)
                        }
                        .overlay {
                            // A hairline border is what reads as "editable field" vs. "static text"
                            // at a glance — the fill alone was too close to the surrounding chrome.
                            // NOTE: swap Color.primary.opacity(...) for your real border/separator
                            // token if StudioColors defines one — kept generic since that file
                            // wasn't in scope here.
                            RoundedRectangle(cornerRadius: StudioRadius.control)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
                .accessibilityLabel(row.label)
                .accessibilityValue(binding.wrappedValue)
                .overlay(alignment: .leading) {
                    if binding.wrappedValue.isEmpty {
                        Text(row.isLinkedToPSPrefix ? "Family PostScript prefix" : "Name string")
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, NameTableLayout.editorHorizontalPadding)
                            .allowsHitTesting(false)
                    }
                }

                // Hover-reveal remove — entire ID, not just clearing text.
                // Protected IDs 1/2/4/6 never show this control.
                if hoveredValueFieldID == row.nameID,
                   WindowsNameTableEditing.canRemove(nameID: row.nameID),
                   !binding.wrappedValue.isEmpty || row.isOverride {
                    Button {
                        requestRemoval(of: row.nameID)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .studioHoverIcon(tint: .primary)
                    .padding(.trailing, StudioSpacing.tightGap)
                    .help(WindowsNameTableEditing.removeHelp(nameID: row.nameID))
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.1), value: hoveredValueFieldID)
            .onHover { isHovering in
                hoveredValueFieldID = isHovering ? row.nameID : (hoveredValueFieldID == row.nameID ? nil : hoveredValueFieldID)
            }
        }
    }

    /// Soft-wrapping editor: one row when content fits, grows by wrapped lines when it doesn’t.
    /// Return commits & collapses (no hard newlines); Escape cancels.
    private func wrappingValueEditor(
        binding: Binding<String>,
        placeholder: String
    ) -> some View {
        StudioWrappingTextField(
            placeholder: placeholder,
            text: binding,
            // Match the collapsed state's 13pt mono so nothing shifts size on expand/collapse.
            font: .system(size: 13, weight: .regular, design: .monospaced),
            lineSpacing: NameTableLayout.wrappedLineSpacing,
            // Effectively unbounded — the field now grows to fit ALL of its content,
            // and the ScrollView wrapping it (see valueEditor) is what clips/scrolls the
            // visible window. Capping lineLimit here too meant content past that cap was
            // stuck inside the field's own clipped area with no scroll-wheel access to it.
            lineLimit: 1...NameTableLayout.maxWrappedLines,
            horizontalPadding: NameTableLayout.editorHorizontalPadding,
            verticalPadding: NameTableLayout.editorVerticalPadding,
            minHeight: NameTableLayout.valueRowHeight,
            onSubmit: { collapseEditor() },
            onCancel: { collapseEditor() }
        )
    }

    private func collapseEditor() {
        expandedNameID = nil
        StudioFieldFocus.resignIfEditing()
    }

    private var missingIDs: [Int] {
        guard let analysis, let font = editor.selectedFont else { return [] }
        return WindowsNameTableEditing.missingNameIDs(
            windowsNameTable: analysis.windowsNameTable,
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals,
            familyPSPrefix: font.options.familyPSPrefix
        )
    }

    private func populatedRows(from analysis: FontAnalysis) -> [WindowsNameTableEditing.Row] {
        guard let font = editor.selectedFont else { return [] }
        return WindowsNameTableEditing.populatedRows(
            windowsNameTable: analysis.windowsNameTable,
            overrides: font.windowsNameOverrides,
            removals: font.windowsNameRemovals,
            familyPSPrefix: font.options.familyPSPrefix
        )
    }

    private var filteredRows: [WindowsNameTableEditing.Row] {
        guard let analysis else { return [] }
        let rows = populatedRows(from: analysis)
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return rows }
        return rows.filter {
            "\($0.nameID)".contains(query)
                || $0.label.lowercased().contains(query)
                || $0.value.lowercased().contains(query)
        }
    }

    private func revertHelp(for nameID: Int) -> String {
        let fileValue = WindowsNameTableEditing.analysisString(
            nameID: nameID,
            windowsNameTable: analysis?.windowsNameTable ?? []
        )
        guard let fileValue else {
            return "Discard edit · nameID \(nameID) is not in the file"
        }
        return "Revert to file\n→ \(fileValue)"
    }

    private func policySuggestion(for nameID: Int) -> NamePolicies.Suggestion? {
        guard let analysis, let font = editor.selectedFont else { return nil }
        let context = NamePolicies.FillContext.from(analysis: analysis, font: font)
        return NamePolicies.suggestion(nameID: nameID, context: context)
    }

    @MainActor
    private func reloadAnalysis() async {
        guard let font = editor.selectedFont else {
            analysis = nil
            loadError = nil
            return
        }
        loadError = nil
        do {
            analysis = try editor.analyzeSourceFont(fontID: font.id, sourcePath: font.sourcePath)
        } catch {
            analysis = nil
            loadError = error.localizedDescription
        }
    }
}

struct NameTableHeaderMeta: Equatable {
    var populated: Int
    var missing: Int
}

/// Name table panel / add-popover column metrics (on-lattice).
enum NameTableLayout {
    /// Used only by the Add ID popover's ID column — the main row list no longer
    /// reserves a fixed-width ID column (see nameRow), since trailing-aligning
    /// 1- and 2-digit IDs in a fixed box made single-digit rows look indented.
    static let nameIDColumnWidth: CGFloat = 28
    static let addPopoverWidth: CGFloat = 260
    /// Effectively unbounded — the ScrollView around the expanded editor (see
    /// valueEditor) owns clipping/scrolling now, not this line cap. Kept as a very
    /// large finite bound rather than Int.max for safety with the underlying text layout.
    static let maxWrappedLines: Int = 500
    /// Visible height ceiling for a focused/expanded field. Content taller than
    /// this scrolls via the wrapping ScrollView; content shorter sizes naturally.
    /// ~10 lines at 13pt mono + line spacing + vertical padding.
    static let expandedFieldMaxHeight: CGFloat = 220
    /// Extra leading between wrapped lines in the focused editor.
    static let wrappedLineSpacing: CGFloat = 4
    static let editorHorizontalPadding: CGFloat = StudioFieldMetrics.horizontalPadding // 6
    /// Inner inset so wrapped text isn’t flush against the field chrome.
    static let editorVerticalPadding: CGFloat = StudioSpace.x1_5 // 6
    /// Collapsed-field row height. Floors at 32pt so the 13pt mono value text
    /// (bumped up from the label's 12pt) has enough vertical room to sit comfortably —
    /// whatever StudioFieldMetrics.monoValueRowHeight is currently set to, don't go below this.
    static let valueRowHeight: CGFloat = max(StudioFieldMetrics.monoValueRowHeight, 32)
    /// Trailing inset reserved in the collapsed field so truncated text stops short of
    /// the hover-revealed remove button instead of running underneath it.
    static let clearButtonReservedWidth: CGFloat = 26
}

enum NameTableHeaderMetaKey: PreferenceKey {
    static var defaultValue: NameTableHeaderMeta? { nil }

    static func reduce(value: inout NameTableHeaderMeta?, nextValue: () -> NameTableHeaderMeta?) {
        value = nextValue() ?? value
    }
}
