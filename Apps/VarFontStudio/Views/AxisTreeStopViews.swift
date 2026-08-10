import SwiftUI
import VarFontCore

// MARK: - Stop table header

struct AxisStopTableHeader: View {
    let showElidable: Bool
    var showDefaultMark: Bool = false
    var showRemoveSlot: Bool = true
    var showCode: Bool = false
    /// Reserve the conflict-badge column so header labels stay aligned with the rows below
    /// when the axis has a stop in an unresolved naming conflict.
    var showConflictColumn: Bool = false
    /// `true` ascending, `false` descending, `nil` mixed / single stop.
    var valueSortAscending: Bool? = nil
    var onToggleValueSort: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            if showDefaultMark {
                Color.clear
                    .frame(width: AxisBlockLayout.defaultMarkWidth, alignment: .center)
                    .padding(.trailing, AxisBlockLayout.defaultMarkTrailingGap)
            }

            Text("Format")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(StudioColors.sectionHeading)
                .lineLimit(1)
                .frame(width: AxisBlockLayout.fmtColumnWidth, alignment: .center)

            valueHeader
                .frame(width: AxisBlockLayout.valueColumnWidth, alignment: .trailing)

            Text("Name")
                .font(StudioTypography.columnLabel)
                .foregroundStyle(StudioColors.sectionHeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AxisBlockLayout.nameGap)

            if showElidable {
                Text("Elided")
                    .font(StudioTypography.columnLabel)
                    .foregroundStyle(StudioColors.sectionHeading)
                    .lineLimit(1)
                    .frame(width: AxisBlockLayout.elidableWidth, alignment: .center)
                    .padding(.leading, AxisBlockLayout.elidableGap)
                    .help("Omit this stop from the composed style name when it is the default choice")
            }

            if showCode {
                Text("Code")
                    .font(StudioTypography.columnLabel)
                    .foregroundStyle(StudioColors.sectionHeading)
                    .frame(width: AxisBlockLayout.codeColumnWidth, alignment: .center)
                    .padding(.leading, AxisBlockLayout.codeGap)
                    .help("Optional 1–2 character classification code (letters or digits). Independent of Elided — it always composes into the instance code.")
            }

            // Mirrors AxisTreeStopRow's conflict / remove slots exactly — same widths, same
            // leading gaps — so every column stays aligned with the rows beneath this header
            // instead of drifting by however wide those slots are.
            if showConflictColumn {
                Color.clear
                    .frame(width: AxisBlockLayout.conflictSlotWidth)
                    .padding(.leading, AxisBlockLayout.conflictSlotLeadingGap)
            }

            if showRemoveSlot {
                Color.clear
                    .frame(width: AxisBlockLayout.removeSlotWidth)
                    .padding(.leading, AxisBlockLayout.removeSlotLeadingGap)
            }
        }
        .padding(.horizontal, AxisBlockLayout.rowHorizontalPadding)
        .padding(.bottom, StudioSpace.x0_5)
    }

    @ViewBuilder
    private var valueHeader: some View {
        let label = HStack(spacing: StudioSpace.x0_5) {
            Text("Value")
                .font(StudioTypography.columnLabel)
            Image(systemName: valueSortSymbol)
                .font(StudioTypography.iconGlyph)
        }
        .foregroundStyle(valueSortAscending == nil ? Color.secondary : StudioColors.brand)
        .contentShape(Rectangle())
        .help(valueSortHelp)

        if let onToggleValueSort {
            Button(action: onToggleValueSort) {
                label
            }
            .buttonStyle(StudioLinkButtonStyle(linkStyle: .accent))
        } else {
            label
        }
    }

    private var valueSortSymbol: String {
        // Prefer .some/.none — `case true` on Bool? is not exhaustive under Xcode 16.4 WMO.
        switch valueSortAscending {
        case .some(true): return "chevron.up"
        case .some(false): return "chevron.down"
        case .none: return "chevron.up.chevron.down"
        }
    }

    private var valueSortHelp: String {
        switch valueSortAscending {
        case .some(true):
            return "Sorted low → high. Click to sort high → low (affects Instance list order)."
        case .some(false):
            return "Sorted high → low. Click to sort low → high (affects Instance list order)."
        case .none:
            return "Click to sort stops by value (affects Instance list order)."
        }
    }
}

// MARK: - Stop row

struct AxisTreeStopRow: View {
    let stop: AxisValue
    var linkedTargetName: String?
    var isRegistrationStop: Bool = false
    var linkTargetCandidates: [StatFormat3Pairing.LinkTarget] = []
    let isSelected: Bool
    let editingField: StopEditField?
    let showElidable: Bool
    var showDefaultMark: Bool = false
    var showCode: Bool = false
    var isFvarDefault: Bool = false
    var allowsRemove: Bool = true
    var valueEditable: Bool = true
    let isElidable: Bool
    /// The axis owning this row has at least one conflicting stop — reserve the trailing slot
    /// so every row in the table stays column-aligned whether or not it carries the badge.
    var showConflictColumn: Bool = false
    /// This stop participates in an unresolved axis naming conflict (duplicate value / name).
    var isConflicting: Bool = false
    var onResolveConflict: (() -> Void)?
    let onSelect: () -> Void
    let onBeginEdit: (StopEditField) -> Void
    let onEndEdit: () -> Void
    let onChangeFormat: () -> Void
    let onRegisterTabNavigation: (((Bool) -> Void)?) -> Void
    let onTabForwardFromLastField: () -> Void
    let onTabBackwardFromFirstField: () -> Void
    let onRemove: () -> Void
    let onCommitPin: (Double) -> Void
    let onCommitMin: (Double) -> Void
    let onCommitMax: (Double) -> Void
    let onCommitCode: (String) -> Void
    let onCommitName: (String) -> Void
    let onToggleElidable: () -> Void
    var onSelectLinkTarget: ((Double) -> Void)?

    @State private var isHovered = false
    @State private var editingMin = ""
    @State private var editingPin = ""
    @State private var editingMax = ""
    @State private var editingCode = ""
    @State private var editingName = ""
    @State private var confirmRemove = false
    @State private var selectTask: Task<Void, Never>?
    @FocusState private var focusedField: StopEditField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            primaryRow

            if stop.statFormat == 2 {
                format2RangeSubline
            }
        }
        .padding(.horizontal, AxisBlockLayout.rowHorizontalPadding)
        .padding(.vertical, StudioSpacing.instanceRowVertical)
        .background {
            // Flush with the row's own bounds (post-padding) — matches the width of the
            // Add Stop / Fill stops… buttons beneath, which share this same outer inset.
            StudioRowBackground(isSelected: isSelected, isHovered: isHovered)
        }
        .overlay(alignment: .leading) {
            if isConflicting {
                RoundedRectangle.studio(StudioRadius.hairline)
                    .fill(StudioColors.warningForeground.opacity(0.85))
                    .frame(width: 3)
                    .padding(.leading, StudioSpace.x0_5)
            } else if isRegistrationStop {
                RoundedRectangle.studio(StudioRadius.hairline)
                    .fill(StudioColors.registrationForeground.opacity(0.85))
                    .frame(width: 3)
                    .padding(.leading, StudioSpace.x0_5)
            }
        }
        .onHover { isHovered = $0 }
        .onAppear { syncDrafts() }
        .onChange(of: stop.value) { _, _ in syncDrafts() }
        .onChange(of: stop.rangeMin) { _, _ in syncDrafts() }
        .onChange(of: stop.rangeMax) { _, _ in syncDrafts() }
        .onChange(of: stop.name) { _, _ in syncDrafts() }
        .onChange(of: stop.code) { _, _ in syncDrafts() }
        .onChange(of: editingField) { _, field in
            syncDrafts()
            if let field {
                onRegisterTabNavigation { forward in
                    navigateTab(forward: forward)
                }
                Task { @MainActor in
                    focusedField = field
                }
            } else {
                onRegisterTabNavigation(nil)
                focusedField = nil
            }
        }
        .onKeyPress(.escape) {
            guard editingField != nil else { return .ignored }
            commitCurrentEdit()
            onEndEdit()
            return .handled
        }
        .alert("Remove Stop?", isPresented: $confirmRemove) {
            Button("Remove", role: .destructive, action: onRemove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove “\(stop.name)” at \(StudioFormatting.axisValue(stop.value))?")
        }
    }

    private var primaryRow: some View {
        HStack(alignment: .center, spacing: 0) {
            defaultMarkCell

            StudioStatFormatBadge(format: stop.statFormat, action: onChangeFormat)
                .frame(width: AxisBlockLayout.fmtColumnWidth, alignment: .center)

            valueCell
                .frame(width: AxisBlockLayout.valueColumnWidth, alignment: .trailing)

            nameColumn
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, AxisBlockLayout.nameGap)

            if showElidable {
                StudioElidableRadio(isOn: isElidable, action: onToggleElidable)
                    .frame(width: AxisBlockLayout.elidableWidth)
                    .padding(.leading, AxisBlockLayout.elidableGap)
            }

            if showCode {
                codeColumn
                    .frame(width: AxisBlockLayout.codeColumnWidth, alignment: .center)
                    .padding(.leading, AxisBlockLayout.codeGap)
            }

            if showConflictColumn {
                conflictCell
                    .frame(width: AxisBlockLayout.conflictSlotWidth, alignment: .center)
                    .padding(.leading, AxisBlockLayout.conflictSlotLeadingGap)
            }

            // Real reserved column, not an overlay — sized to the button alone,
            // so it's contained by the row's own background automatically instead
            // of needing a separately hand-tuned offset/background pair to agree.
            removeSlot
        }
        .frame(minHeight: StudioFieldMetrics.listRowMinHeight)
    }

    @ViewBuilder
    private var defaultMarkCell: some View {
        if showDefaultMark {
            Group {
                if isFvarDefault {
                    Image(systemName: "d.square.fill")
                        .font(StudioTypography.rowName.weight(.semibold))
                        .foregroundStyle(StudioColors.registrationForeground)
                        .help("fvar default coordinate")
                        .accessibilityLabel("fvar default")
                } else {
                    Color.clear
                }
            }
            .frame(width: AxisBlockLayout.defaultMarkWidth, alignment: .center)
            .padding(.trailing, AxisBlockLayout.defaultMarkTrailingGap)
        }
    }

    @ViewBuilder
    private var conflictCell: some View {
        if isConflicting {
            StudioWarningBadge(
                help: "This stop is part of a naming conflict — resolve it here",
                action: onResolveConflict
            )
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var removeSlot: some View {
        ZStack {
            if allowsRemove, isHovered {
                StudioDismissButton(scale: .chip, style: .fill, help: "Remove stop") {
                    confirmRemove = true
                }
            }
        }
        .frame(width: AxisBlockLayout.removeSlotWidth)
        .padding(.leading, AxisBlockLayout.removeSlotLeadingGap)
    }

    @ViewBuilder
    private var valueCell: some View {
        Group {
            if editingField == .pin, valueEditable {
                HStack(spacing: StudioSpace.x1) {
                    StudioInlineTextField(
                        placeholder: "Value",
                        text: $editingPin,
                        font: StudioTypography.monoValue,
                        rowHeight: StudioFieldMetrics.listRowMinHeight,
                        alignment: .trailing,
                        onSubmit: commitAndEndEdit,
                        onCancel: cancelInlineEdit
                    )
                    .focused($focusedField, equals: .pin)
                }
                .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .trailing)
            } else if valueEditable {
                StudioAxisValueLabel(
                    text: StudioFormatting.axisValue(stop.value),
                    minHeight: StudioFieldMetrics.listRowMinHeight
                )
                .contentShape(Rectangle())
                .gesture(clickGesture(for: .pin))
            } else {
                StudioAxisValueLabel(
                    text: StudioFormatting.axisValue(stop.value),
                    minHeight: StudioFieldMetrics.listRowMinHeight
                )
                .contentShape(Rectangle())
                .gesture(selectOnlyGesture)
            }
        }
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private var format2RangeSubline: some View {
        HStack(spacing: StudioSpacing.tightGap) {
            sublineLabel("min")
            sublineField(.min, value: stop.rangeMin, placeholder: "Min")
            sublineSeparator
            sublineLabel("nom")
            StudioAxisValueLabel(
                text: StudioFormatting.axisValue(stop.value),
                font: StudioTypography.monoMeta,
                showMark: false
            )
            .fixedSize()
            sublineSeparator
            sublineLabel("max")
            sublineField(.max, value: stop.rangeMax, placeholder: "Max")
        }
        .padding(.leading, AxisBlockLayout.rangeSublineLeading(showDefaultMark: showDefaultMark))
        .padding(.bottom, StudioSpacing.instanceRowVertical)
    }

    private func sublineLabel(_ text: String) -> some View {
        Text(text)
            .font(StudioTypography.caption)
            .foregroundStyle(.tertiary)
    }

    private var sublineSeparator: some View {
        Text("·")
            .font(StudioTypography.caption)
            .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func sublineField(_ field: StopEditField, value: Double?, placeholder: String) -> some View {
        if editingField == field, valueEditable {
            HStack(spacing: StudioSpace.x1) {
                StudioInlineTextField(
                    placeholder: placeholder,
                    text: binding(for: field),
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.captionRowHeight,
                    alignment: .trailing,
                    onSubmit: commitAndEndEdit,
                    onCancel: cancelInlineEdit
                )
                .focused($focusedField, equals: field)
            }
            .frame(width: AxisBlockLayout.inlineValueEditWidth)
        } else if let value {
            if valueEditable {
                StudioAxisValueLabel(
                    text: StudioFormatting.axisValue(value),
                    font: StudioTypography.monoMeta,
                    showMark: false
                )
                .fixedSize()
                .contentShape(Rectangle())
                .gesture(clickGesture(for: field))
            } else {
                StudioAxisValueLabel(
                    text: StudioFormatting.axisValue(value),
                    font: StudioTypography.monoMeta,
                    showMark: false
                )
                .fixedSize()
                .contentShape(Rectangle())
                .gesture(selectOnlyGesture)
            }
        } else {
            Text("—")
                .font(StudioTypography.monoMeta)
                .foregroundStyle(.tertiary)
        }
    }

    private func binding(for field: StopEditField) -> Binding<String> {
        switch field {
        case .min: $editingMin
        case .pin: $editingPin
        case .max: $editingMax
        case .code: $editingCode
        case .name: $editingName
        }
    }

    @ViewBuilder
    private var codeColumn: some View {
        Group {
            if editingField == .code {
                StudioInlineTextField(
                    placeholder: "·",
                    text: $editingCode,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.listRowMinHeight,
                    alignment: .center,
                    onSubmit: commitAndEndEdit,
                    onCancel: cancelInlineEdit
                )
                .focused($focusedField, equals: .code)
            } else if let code = stop.code, !code.isEmpty {
                Text(code)
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, StudioSpace.x1)
                    .padding(.vertical, StudioSpacing.instanceRowGap)
                    .background(StudioColors.codeBackground, in: RoundedRectangle.studio(StudioRadius.chip))
                    .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(clickGesture(for: .code))
            } else {
                Text("—")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(clickGesture(for: .code))
            }
        }
        .transaction { $0.animation = nil }
    }

    @ViewBuilder
    private var nameColumn: some View {
        Group {
            if editingField == .name {
                StudioInlineTextField(
                    placeholder: "Stop name",
                    text: $editingName,
                    font: StudioTypography.bodyMedium,
                    rowHeight: StudioFieldMetrics.listRowMinHeight,
                    onSubmit: commitAndEndEdit,
                    onCancel: cancelInlineEdit
                )
                .focused($focusedField, equals: .name)
            } else {
                HStack(spacing: StudioSpacing.tightGap) {
                    Text(stop.name)
                        .font(StudioTypography.bodyMedium)
                        .lineLimit(1)
                    if stop.statFormat == 3 {
                        // Keep the chain outside Menu — Menu label chrome can rescale
                        // SF Symbols even when `.font` is set on the label contents.
                        let linkEditable = !linkTargetCandidates.isEmpty && onSelectLinkTarget != nil
                        if linkEditable || linkedTargetName != nil {
                            StudioLinkGlyph(isEditable: linkEditable)
                        }
                        if linkEditable, let onSelectLinkTarget {
                            Menu {
                                ForEach(linkTargetCandidates) { target in
                                    Button {
                                        onSelectLinkTarget(target.value)
                                    } label: {
                                        if let linkedTargetName, target.label == linkedTargetName
                                            || (stop.linkedValue.map { AxisCoordinate.valuesEqual($0, target.value) } == true) {
                                            Label(target.label, systemImage: "checkmark")
                                        } else {
                                            Text(target.label)
                                        }
                                    }
                                }
                            } label: {
                                Text(linkedTargetName ?? "Link…")
                                    .font(StudioTypography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .menuStyle(.borderlessButton)
                            .controlSize(.small)
                            .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control))
                        } else if let linkedTargetName {
                            Text(linkedTargetName)
                                .font(StudioTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: StudioFieldMetrics.listRowMinHeight, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(clickGesture(for: .name))
            }
        }
        .transaction { $0.animation = nil }
    }

    private func clickGesture(for field: StopEditField) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                selectTask?.cancel()
                onBeginEdit(field)
            }
            .simultaneously(with:
                TapGesture(count: 1)
                    .onEnded {
                        selectTask?.cancel()
                        selectTask = Task {
                            try? await Task.sleep(nanoseconds: 220_000_000)
                            guard !Task.isCancelled else { return }
                            await MainActor.run { onSelect() }
                        }
                    }
            )
    }

    private var selectOnlyGesture: some Gesture {
        TapGesture(count: 1)
            .onEnded {
                selectTask?.cancel()
                onSelect()
            }
    }

    private func syncDrafts() {
        editingMin = stop.rangeMin.map(StudioFormatting.axisValue) ?? ""
        editingPin = StudioFormatting.axisValue(stop.value)
        editingMax = stop.rangeMax.map(StudioFormatting.axisValue) ?? ""
        editingCode = stop.code ?? ""
        editingName = stop.name
    }

    private func editableFields() -> [StopEditField] {
        var fields: [StopEditField] = []
        if valueEditable, stop.statFormat == 2 {
            fields.append(contentsOf: [.pin, .min, .max])
        } else if valueEditable {
            fields.append(.pin)
        }
        if showCode {
            fields.append(.code)
        }
        fields.append(.name)
        return fields
    }

    private func commitCurrentEdit() {
        guard let editingField else { return }
        switch editingField {
        case .min: commitMin()
        case .pin: commitPin()
        case .max: commitMax()
        case .code: commitCode()
        case .name: commitName()
        }
    }

    private func commitMin() {
        let trimmed = editingMin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            syncDrafts()
            return
        }
        if let current = stop.rangeMin, AxisCoordinate.valuesEqual(value, current) { return }
        Task { @MainActor in onCommitMin(value) }
    }

    private func commitPin() {
        let trimmed = editingPin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            syncDrafts()
            return
        }
        guard !AxisCoordinate.valuesEqual(value, stop.value) else { return }
        Task { @MainActor in onCommitPin(value) }
    }

    private func commitMax() {
        let trimmed = editingMax.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            syncDrafts()
            return
        }
        if let current = stop.rangeMax, AxisCoordinate.valuesEqual(value, current) { return }
        Task { @MainActor in onCommitMax(value) }
    }

    private func commitName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            syncDrafts()
            return
        }
        guard trimmed != stop.name else { return }
        Task { @MainActor in onCommitName(trimmed) }
    }

    private func commitCode() {
        let sanitized = InstanceCodeBuilder.sanitize(editingCode) ?? ""
        let current = stop.code ?? ""
        guard sanitized != current else {
            syncDrafts()
            return
        }
        editingCode = sanitized
        Task { @MainActor in onCommitCode(sanitized) }
    }

    private func navigateTab(forward: Bool) {
        guard let editingField else { return }
        let fields = editableFields()
        guard let index = fields.firstIndex(of: editingField) else { return }

        if forward {
            commitCurrentEdit()
            if index + 1 < fields.count {
                onBeginEdit(fields[index + 1])
            } else {
                onTabForwardFromLastField()
            }
        } else if index > 0 {
            commitCurrentEdit()
            onBeginEdit(fields[index - 1])
        } else {
            onTabBackwardFromFirstField()
        }
    }

    /// Return commits the current field and leaves edit mode — does not advance like Tab.
    private func commitAndEndEdit() {
        commitCurrentEdit()
        onEndEdit()
    }

    private func cancelInlineEdit() {
        syncDrafts()
        onEndEdit()
    }
}

