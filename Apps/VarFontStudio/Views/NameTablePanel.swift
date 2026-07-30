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
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRows) { row in
                        nameRow(row)
                    }
                }
                .padding(.horizontal, StudioSpacing.panelHorizontal)
                .padding(.vertical, StudioSpacing.tightGap)

                Text("Windows English only (3 · 1 · 0x409). ID 25 ≡ File naming PS prefix.")
                    .font(StudioTypography.meta)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, StudioSpacing.panelHorizontal)
                    .padding(.vertical, StudioSpace.x2_5)
            }
        }
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

    private var addIDPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add Windows name ID")
                .font(StudioTypography.meta.weight(.semibold))
                .padding(.horizontal, StudioSpace.x3)
                .padding(.top, StudioSpace.x2_5)
                .padding(.bottom, StudioSpacing.panelVertical)
            ForEach(missingIDs, id: \.self) { nameID in
                Button {
                    editor.addWindowsNameID(nameID)
                    showAddPopover = false
                    expandedNameID = nameID
                } label: {
                    HStack {
                        Text("\(nameID)")
                            .font(StudioTypography.monoMeta)
                            .foregroundStyle(StudioColors.computedHighlight)
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
        }
        .frame(width: NameTableLayout.addPopoverWidth)
        .padding(.bottom, StudioSpace.x2)
    }

    private func namesHeaderMeta(_ analysis: FontAnalysis) -> some View {
        let rows = populatedRows(from: analysis)
        let missing = missingIDs.count
        return HStack(spacing: StudioSpacing.instanceRowVertical) {
            Text("\(rows.count)")
                .foregroundStyle(StudioColors.computedHighlight)
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

    private static let nameLabelRowHeight: CGFloat = 16

    private func nameRow(_ row: WindowsNameTableEditing.Row) -> some View {
        let suggestion = policySuggestion(for: row.nameID)
        let showFill = suggestion.map { $0.value != row.value } ?? false
        return VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            HStack(spacing: StudioSpacing.rowGap) {
                Text("\(row.nameID)")
                    .font(StudioTypography.rowNameMono)
                    .foregroundStyle(StudioColors.computedHighlight)
                Text(row.label)
                    .font(StudioTypography.rowName)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if row.isLinkedToPSPrefix {
                    Text("≡ PS prefix")
                        .font(StudioTypography.rowName)
                        .foregroundStyle(StudioColors.registrationForeground)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if showFill, let suggestion {
                    Button {
                        editor.applyWindowsNamePolicy(nameID: row.nameID, value: suggestion.value)
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(StudioTypography.columnLabel)
                            .frame(width: Self.nameLabelRowHeight, height: Self.nameLabelRowHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .studioHoverIcon(tint: Color.accentColor)
                    .help("Fill from font · \(suggestion.source)\n→ \(suggestion.value)")
                }
            }
            .frame(height: Self.nameLabelRowHeight, alignment: .center)

            valueEditor(for: row)
        }
        .padding(.vertical, StudioSpace.x2)
    }

    @ViewBuilder
    private func valueEditor(for row: WindowsNameTableEditing.Row) -> some View {
        let binding = Binding(
            get: { editor.windowsNameValue(nameID: row.nameID, analysis: analysis) },
            set: { editor.setWindowsNameValue(nameID: row.nameID, value: $0) }
        )
        let isExpanded = expandedNameID == row.nameID

        if isExpanded {
            wrappingValueEditor(
                binding: binding,
                placeholder: row.isLinkedToPSPrefix ? "Family PS prefix" : "Name string"
            )
        } else {
            Button {
                expandedNameID = row.nameID
            } label: {
                Text(binding.wrappedValue.isEmpty ? " " : binding.wrappedValue)
                    .font(StudioTypography.monoValue)
                    .foregroundStyle(binding.wrappedValue.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, StudioFieldMetrics.horizontalPadding)
                    .frame(height: StudioFieldMetrics.monoValueRowHeight, alignment: .center)
                    .background {
                        RoundedRectangle(cornerRadius: StudioRadius.control)
                            .fill(StudioColors.fieldFill)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
            .accessibilityLabel(row.label)
            .accessibilityValue(binding.wrappedValue)
            .overlay(alignment: .leading) {
                if binding.wrappedValue.isEmpty {
                    Text(row.isLinkedToPSPrefix ? "Family PS prefix" : "Name string")
                        .font(StudioTypography.monoValue)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, StudioFieldMetrics.horizontalPadding)
                        .allowsHitTesting(false)
                }
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
            font: StudioTypography.monoValue,
            lineSpacing: NameTableLayout.wrappedLineSpacing,
            lineLimit: 1...NameTableLayout.maxWrappedLines,
            horizontalPadding: NameTableLayout.editorHorizontalPadding,
            verticalPadding: NameTableLayout.editorVerticalPadding,
            minHeight: StudioFieldMetrics.monoValueRowHeight,
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
            familyPSPrefix: font.options.familyPSPrefix
        )
    }

    private func populatedRows(from analysis: FontAnalysis) -> [WindowsNameTableEditing.Row] {
        guard let font = editor.selectedFont else { return [] }
        return WindowsNameTableEditing.populatedRows(
            windowsNameTable: analysis.windowsNameTable,
            overrides: font.windowsNameOverrides,
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
    static let nameIDColumnWidth: CGFloat = 28
    static let addPopoverWidth: CGFloat = 260
    /// Soft-wrap ceiling for focused name-string editors.
    static let maxWrappedLines: Int = 12
    /// Extra leading between wrapped lines in the focused editor.
    static let wrappedLineSpacing: CGFloat = 4
    static let editorHorizontalPadding: CGFloat = StudioFieldMetrics.horizontalPadding // 6
    /// Inner inset so wrapped text isn’t flush against the field chrome.
    static let editorVerticalPadding: CGFloat = StudioSpace.x1_5 // 6
}

enum NameTableHeaderMetaKey: PreferenceKey {
    static var defaultValue: NameTableHeaderMeta? { nil }

    static func reduce(value: inout NameTableHeaderMeta?, nextValue: () -> NameTableHeaderMeta?) {
        value = nextValue() ?? value
    }
}
