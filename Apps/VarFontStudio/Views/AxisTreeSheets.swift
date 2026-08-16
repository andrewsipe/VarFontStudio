import SwiftUI
import VarFontCore

// MARK: - Add stop sheet

struct AddAxisStopSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let axis: AxisDefinition
    let onComplete: () -> Void

    private enum Placement: Equatable {
        case one
        case several
    }

    private struct DraftStop: Identifiable, Equatable {
        let id: UUID
        var valueText: String
        var nameText: String
        var codeText: String

        init(
            id: UUID = UUID(),
            valueText: String,
            nameText: String,
            codeText: String = ""
        ) {
            self.id = id
            self.valueText = valueText
            self.nameText = nameText
            self.codeText = codeText
        }

        static func from(value: Double, name: String? = nil, code: String = "") -> DraftStop {
            let formatted = AxisStopSuggestions.formatValue(value)
            return DraftStop(valueText: formatted, nameText: name ?? formatted, codeText: code)
        }
    }

    @State private var placement: Placement = .one
    @State private var drafts: [DraftStop] = []
    @State private var statFormat = 1
    @State private var pinText = ""
    @State private var minText = ""
    @State private var maxText = ""
    @State private var nameText = ""
    @State private var codeText = ""
    @State private var linkTargetID: String?
    @State private var tabKeyMonitor: TabKeyMonitor?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case pin, min, max, name, code
    }

    private var gapProposal: AxisStopGapFill.Proposal? {
        AxisStopGapFill.proposal(for: axis)
    }

    private var trimmedCode: String? {
        guard editor.isCodeNamingEnabled else { return nil }
        let t = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                Text("Add Stop(s)")
                    .font(StudioTypography.emphasis)
                Text(axisSubtitle)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }

            placementPicker

            if placement == .one {
                singleStopFields
            } else {
                severalStopFields
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel") {
                    onComplete()
                    dismiss()
                }
                StudioFlatButton(
                    title: primaryActionTitle,
                    role: .primary,
                    isEnabled: canAdd,
                    isDefaultAction: true
                ) {
                    addStopsIfValid()
                }
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(minWidth: placement == .several ? 460 : 360)
        .onAppear(perform: configureInitialPlacement)
        .onChange(of: placement) { _, newPlacement in
            if newPlacement == .several {
                seedSeveralIfNeeded()
            } else {
                applyFirstDraftToSingleFields()
            }
        }
        .onDisappear {
            tabKeyMonitor?.stop()
            tabKeyMonitor = nil
        }
    }

    private var placementPicker: some View {
        HStack(spacing: StudioSpacing.instanceRowGap) {
            StudioSegmentButton(
                title: "One stop",
                isSelected: placement == .one,
                expands: true
            ) {
                placement = .one
            }
            StudioSegmentButton(
                title: "Several",
                isSelected: placement == .several,
                expands: true,
                badge: gapProposal.map { "\($0.values.count)" }
            ) {
                placement = .several
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle.studio(StudioRadius.control))
        .help("One stop can set STAT format 2 or 3. Several always inserts Format 1 stops and leaves the current ladder in place.")
    }

    @ViewBuilder
    private var singleStopFields: some View {
        StudioMenuPicker(
            title: "STAT format",
            selection: $statFormat,
            options: [
                (1, "Format 1 — static"),
                (2, "Format 2 — range"),
                (3, "Format 3 — linked"),
            ]
        )
        .onChange(of: statFormat) { _, _ in seedDefaults() }

        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            formatFields
            StudioTextField(
                placeholder: "Name",
                text: $nameText,
                rowHeight: StudioFieldMetrics.bodyRowHeight,
                onSubmit: editor.isCodeNamingEnabled
                    ? { advanceFocusedField(from: .name) }
                    : addStopsIfValid,
                submitBehavior: editor.isCodeNamingEnabled ? .advance : .commit
            )
            .focused($focusedField, equals: .name)
            if editor.isCodeNamingEnabled {
                StudioTextField(
                    placeholder: "Code",
                    text: $codeText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary,
                    onSubmit: addStopsIfValid
                )
                .focused($focusedField, equals: .code)
                .help("Optional 1–2 character classification code (letters or digits)")
            }
        }
    }

    private var severalStopFields: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            if let gapProposal {
                HStack(alignment: .firstTextBaseline, spacing: StudioSpacing.rowGap) {
                    Text(gapProposal.source + ": " + gapProposal.previewLabel)
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if !draftsMatchProposal {
                        StudioPlainLinkButton(title: "Use suggested gaps") {
                            drafts = drafts(from: gapProposal)
                        }
                    }
                }
            } else {
                Text("Existing stops stay. Edit values and names before adding.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                HStack(spacing: StudioSpace.x2) {
                    Text("Value")
                        .frame(width: 72, alignment: .leading)
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if editor.isCodeNamingEnabled {
                        Text("Code")
                            .frame(width: 52, alignment: .leading)
                    }
                    Color.clear.frame(width: StudioChromeScale.chip.hitSize)
                }
                .font(StudioTypography.columnLabel)
                .foregroundStyle(StudioColors.sectionHeading)

                ForEach($drafts) { $draft in
                    severalRow($draft)
                }
            }

            StudioPlainLinkButton(title: "Add another", systemImage: "plus") {
                appendDraft()
            }
        }
    }

    private func severalRow(_ draft: Binding<DraftStop>) -> some View {
        let draftID = draft.wrappedValue.id
        return HStack(spacing: StudioSpace.x2) {
            StudioTextField(
                placeholder: "Value",
                text: Binding(
                    get: { draft.wrappedValue.valueText },
                    set: { newValue in
                        let previous = draft.wrappedValue.valueText
                        draft.wrappedValue.valueText = newValue
                        syncNameIfNumeric(draftID: draftID, previousValueText: previous)
                    }
                ),
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.bodyRowHeight
            )
            .frame(width: 72)

            StudioTextField(
                placeholder: "Name",
                text: draft.nameText,
                rowHeight: StudioFieldMetrics.bodyRowHeight
            )
            .frame(maxWidth: .infinity)

            if editor.isCodeNamingEnabled {
                StudioTextField(
                    placeholder: "Code",
                    text: draft.codeText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .frame(width: 52)
            }

            StudioDismissButton(
                scale: .chip,
                style: .fill,
                help: drafts.count == 1 ? "Keep at least one stop" : "Remove this stop"
            ) {
                drafts.removeAll { $0.id == draftID }
            }
            .disabled(drafts.count == 1)
            .opacity(drafts.count == 1 ? 0.35 : 1)
        }
    }

    @ViewBuilder
    private var formatFields: some View {
        switch statFormat {
        case 2:
            StudioTextField(
                placeholder: "Min",
                text: $minText,
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                onSubmit: { advanceFocusedField(from: .min) },
                submitBehavior: .advance
            )
            .focused($focusedField, equals: .min)
            StudioTextField(
                placeholder: "Nominal (Pin)",
                text: $pinText,
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                onSubmit: { advanceFocusedField(from: .pin) },
                submitBehavior: .advance
            )
            .focused($focusedField, equals: .pin)
            StudioTextField(
                placeholder: "Max",
                text: $maxText,
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                onSubmit: { advanceFocusedField(from: .max) },
                submitBehavior: .advance
            )
            .focused($focusedField, equals: .max)
        case 3:
            StudioTextField(
                placeholder: "Static (Pin)",
                text: $pinText,
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                onSubmit: { advanceFocusedField(from: .pin) },
                submitBehavior: .advance
            )
            .focused($focusedField, equals: .pin)
            .onChange(of: pinText) { _, _ in seedLinkTargetIfNeeded() }
            StudioMenuPicker(
                title: "Link to",
                selection: Binding(
                    get: { linkTargetID ?? linkCandidates.first?.id ?? "" },
                    set: { linkTargetID = $0.isEmpty ? nil : $0 }
                ),
                options: linkCandidates.map { ($0.id, $0.label) }
            )
        default:
            StudioTextField(
                placeholder: "Static (Pin)",
                text: $pinText,
                font: StudioTypography.monoValue,
                rowHeight: StudioFieldMetrics.monoValueRowHeight,
                onSubmit: { advanceFocusedField(from: .pin) },
                submitBehavior: .advance
            )
            .focused($focusedField, equals: .pin)
        }
    }

    private func configureInitialPlacement() {
        seedDefaults()
        placement = .one
        nameText = ""
        focusedField = .pin
        startTabMonitor()
    }

    private func startTabMonitor() {
        tabKeyMonitor?.stop()
        let monitor = TabKeyMonitor { shift in
            guard let focusedField else { return }
            let order = fieldOrder
            guard let index = order.firstIndex(of: focusedField) else { return }
            if shift {
                if index > 0 { self.focusedField = order[index - 1] }
            } else if index + 1 < order.count {
                self.focusedField = order[index + 1]
            }
        }
        monitor.start()
        tabKeyMonitor = monitor
    }

    private func seedSeveralIfNeeded() {
        tabKeyMonitor?.stop()
        tabKeyMonitor = nil
        if drafts.isEmpty {
            if let gapProposal {
                drafts = drafts(from: gapProposal)
            } else if let pin = parsedPin {
                drafts = [DraftStop.from(value: pin, name: trimmedName.isEmpty ? nil : trimmedName)]
            } else {
                drafts = [DraftStop.from(value: editor.suggestedNewStopValue(for: axis))]
            }
        }
    }

    private func applyFirstDraftToSingleFields() {
        if let first = drafts.first, let value = parsedValue(first.valueText) {
            pinText = AxisStopSuggestions.formatValue(value)
            nameText = first.nameText
            codeText = first.codeText
        }
        startTabMonitor()
        focusedField = .pin
    }

    private func drafts(from proposal: AxisStopGapFill.Proposal) -> [DraftStop] {
        proposal.values.map { DraftStop.from(value: $0) }
    }

    private var draftsMatchProposal: Bool {
        guard let gapProposal else { return false }
        let draftValues = drafts.compactMap { parsedValue($0.valueText) }
        guard draftValues.count == gapProposal.values.count else { return false }
        return zip(draftValues, gapProposal.values).allSatisfy { AxisCoordinate.valuesEqual($0, $1) }
    }

    private func appendDraft() {
        let excluding = drafts.compactMap { parsedValue($0.valueText) }
        let value = AxisStopSuggestions.suggestedValue(for: axis, excludingValues: excluding)
        drafts.append(.from(value: value))
    }

    private func syncNameIfNumeric(draftID: UUID, previousValueText: String) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        let currentName = drafts[index].nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousWasNumericName = parsedValue(previousValueText)
            .map { currentName == AxisStopSuggestions.formatValue($0) || currentName.isEmpty }
            ?? currentName.isEmpty
        guard previousWasNumericName, let value = parsedValue(drafts[index].valueText) else { return }
        drafts[index].nameText = AxisStopSuggestions.formatValue(value)
    }

    private func parsedValue(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func advanceFocusedField(from field: Field) {
        let order = fieldOrder
        guard let index = order.firstIndex(of: field) else { return }
        if index + 1 < order.count {
            focusedField = order[index + 1]
        } else {
            focusedField = editor.isCodeNamingEnabled ? .code : .name
        }
    }

    private var fieldOrder: [Field] {
        var order: [Field]
        switch statFormat {
        case 2: order = [.min, .pin, .max, .name]
        default: order = [.pin, .name]
        }
        if editor.isCodeNamingEnabled {
            order.append(.code)
        }
        return order
    }

    private var linkCandidates: [StatFormat3Pairing.LinkTarget] {
        StatFormat3Pairing.linkTargets(
            for: axis,
            stopValue: parsedPin ?? editor.suggestedNewStopValue(for: axis)
        )
    }

    private func seedDefaults() {
        let suggested = editor.suggestedNewStopValue(for: axis)
        pinText = StudioFormatting.axisValue(suggested)
        minText = StudioFormatting.axisValue(max((axis.min ?? suggested), suggested - 20))
        maxText = StudioFormatting.axisValue(min((axis.max ?? suggested + 20), suggested + 20))
        seedLinkTargetIfNeeded(force: true)
    }

    private func seedLinkTargetIfNeeded(force: Bool = false) {
        let candidates = linkCandidates
        if force || linkTargetID == nil || candidates.contains(where: { $0.id == linkTargetID }) == false {
            linkTargetID = candidates.first?.id
        }
    }

    private var axisSubtitle: String {
        let title = axis.displayName ?? axis.tag
        let range: String = {
            if let min = axis.min, let max = axis.max {
                return "\(title) · allowed \(StudioFormatting.axisValue(min)) – \(StudioFormatting.axisValue(max))"
            }
            return title
        }()
        if placement == .several {
            return range + " · existing stops stay"
        }
        return range
    }

    private var parsedPin: Double? { parsedValue(pinText) }
    private var parsedMin: Double? { parsedValue(minText) }
    private var parsedMax: Double? { parsedValue(maxText) }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var primaryActionTitle: String {
        if placement == .several, drafts.count != 1 {
            return "Add \(drafts.count) Stops"
        }
        return "Add Stop"
    }

    private var validationMessage: String? {
        if placement == .several {
            return severalValidationMessage
        }
        if trimmedName.isEmpty { return "Name is required." }
        switch statFormat {
        case 2:
            guard let pin = parsedPin, let min = parsedMin, let max = parsedMax else {
                return "Enter valid min, nominal, and max values."
            }
            return editor.validateAxisStopValue(pin, for: axis)
                ?? (min <= pin && pin <= max ? nil : "Min ≤ Pin ≤ Max required.")
        case 3:
            guard parsedPin != nil else { return "Enter a valid static value." }
            guard selectedLinkTarget != nil else { return "Choose a link target." }
            return parsedPin.flatMap { editor.validateAxisStopValue($0, for: axis) }
        default:
            guard let pin = parsedPin else { return "Enter a valid static value." }
            return editor.validateAxisStopValue(pin, for: axis)
        }
    }

    private var severalValidationMessage: String? {
        guard !drafts.isEmpty else { return "Add at least one stop." }
        var seen: [Double] = []
        for draft in drafts {
            let name = draft.nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { return "Every stop needs a name." }
            guard let value = parsedValue(draft.valueText) else {
                return "Every stop needs a valid value."
            }
            if let message = editor.validateAxisStopValue(value, for: axis) {
                return message
            }
            if seen.contains(where: { AxisCoordinate.valuesEqual($0, value) }) {
                return "Two new stops share the same value."
            }
            seen.append(value)
        }
        return nil
    }

    private var selectedLinkTarget: StatFormat3Pairing.LinkTarget? {
        let id = linkTargetID ?? linkCandidates.first?.id
        return linkCandidates.first { $0.id == id }
    }

    private var canAdd: Bool { validationMessage == nil }

    private func addStopsIfValid() {
        guard canAdd else { return }
        if placement == .several {
            let stops: [(value: Double, name: String, code: String?)] = drafts.compactMap { draft in
                guard let value = parsedValue(draft.valueText) else { return nil }
                let name = draft.nameText.trimmingCharacters(in: .whitespacesAndNewlines)
                let code = editor.isCodeNamingEnabled
                    ? draft.codeText.trimmingCharacters(in: .whitespacesAndNewlines)
                    : ""
                return (
                    value,
                    name,
                    code.isEmpty ? nil : code
                )
            }
            let tag = axis.tag
            onComplete()
            dismiss()
            Task { @MainActor in
                editor.insertMissingAxisStops(axisTag: tag, stops: stops)
            }
            return
        }

        let name = trimmedName
        let tag = axis.tag
        let code = trimmedCode
        let linkValue = selectedLinkTarget?.value
        onComplete()
        dismiss()
        Task { @MainActor in
            switch statFormat {
            case 2:
                guard let pin = parsedPin, let min = parsedMin, let max = parsedMax else { return }
                editor.insertAxisStop(
                    axisTag: tag,
                    value: pin,
                    name: name,
                    statFormat: 2,
                    rangeMin: min,
                    rangeMax: max,
                    code: code
                )
            case 3:
                guard let pin = parsedPin else { return }
                editor.insertAxisStop(
                    axisTag: tag,
                    value: pin,
                    name: name,
                    statFormat: 3,
                    linkedValue: linkValue,
                    code: code
                )
            default:
                guard let pin = parsedPin else { return }
                editor.insertAxisStop(axisTag: tag, value: pin, name: name, code: code)
            }
        }
    }
}

// MARK: - Fill stops sheet

/// Standalone quick-fill tool, reachable anytime from the axis tree (not gated behind a plan
/// warning). Unlike Add Stop(s), this replaces whatever stops already exist — reopen anytime
/// to tweak a fill with a different count or interval, no undo required.
struct FillAxisStopsSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let axis: AxisDefinition
    let onComplete: () -> Void

    @State private var fillMode: AxisStopFillMode = .evenCount
    @State private var stopCount: Double = 6
    @State private var intervalStep: Double = 1
    @State private var confirmingReplace = false

    private var options: AxisStopFillOptions? {
        AxisStopFillPlanner.options(for: axis)
    }

    private var values: [Double]? {
        switch fillMode {
        case .evenCount:
            return AxisStopFillPlanner.values(for: axis, count: Int(stopCount.rounded()))
        case .fixedInterval:
            return AxisStopFillPlanner.values(for: axis, interval: intervalStep)
        }
    }

    /// Stops whose name doesn't match their bare numeric value have been customized —
    /// replacing without confirmation would silently discard that naming work.
    private var hasCustomNamedStops: Bool {
        axis.values.contains { $0.name != AxisStopSuggestions.formatValue($0.value) }
    }

    private var canApply: Bool {
        (values?.count ?? 0) >= AxisStopFillPlanner.minStopCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sheetSectionSpacing) {
            VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
                Text("Fill Stops")
                    .font(StudioTypography.emphasis)
                Text("\(axis.displayName ?? axis.tag) · replaces every stop currently on this axis")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if let options {
                AxisStopFillControls(
                    axis: axis,
                    options: options,
                    fillMode: $fillMode,
                    stopCount: $stopCount,
                    intervalStep: $intervalStep
                )
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel") {
                    onComplete()
                    dismiss()
                }
                StudioFlatButton(title: "Fill", role: .primary, isEnabled: canApply, isDefaultAction: true) {
                    if hasCustomNamedStops {
                        confirmingReplace = true
                    } else {
                        apply()
                    }
                }
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(minWidth: 460)
        .onAppear {
            guard let options else { return }
            stopCount = Double(options.defaultCount)
            intervalStep = options.defaultInterval
        }
        .alert("Replace Named Stops?", isPresented: $confirmingReplace) {
            Button("Replace", role: .destructive, action: apply)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This axis has stops with custom names. Filling will remove them and replace every stop on this axis.")
        }
    }

    private func apply() {
        guard let values else { return }
        editor.replaceAxisStops(axisTag: axis.tag, values: values)
        onComplete()
        dismiss()
    }
}

// MARK: - Change format sheet

struct ChangeAxisStopFormatSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let axis: AxisDefinition
    let stop: AxisValue
    let onComplete: () -> Void

    @State private var statFormat: Int
    @State private var linkTargetID: String?

    init(axis: AxisDefinition, stop: AxisValue, onComplete: @escaping () -> Void) {
        self.axis = axis
        self.stop = stop
        self.onComplete = onComplete
        _statFormat = State(initialValue: stop.statFormat)
        let candidates = StatFormat3Pairing.linkTargets(
            for: axis,
            stopValue: stop.value,
            excludingStopID: stop.id
        )
        if stop.statFormat == 3, let linkedValue = stop.linkedValue,
           let match = candidates.first(where: { AxisCoordinate.valuesEqual($0.value, linkedValue) }) {
            _linkTargetID = State(initialValue: match.id)
        } else {
            _linkTargetID = State(initialValue: candidates.first?.id)
        }
    }

    private var linkCandidates: [StatFormat3Pairing.LinkTarget] {
        StatFormat3Pairing.linkTargets(
            for: axis,
            stopValue: stop.value,
            excludingStopID: stop.id
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Format · \(stop.name)")
                .font(StudioTypography.emphasis)

            StudioMenuPicker(
                title: "STAT format",
                selection: $statFormat,
                options: [
                    (1, "Format 1 — static"),
                    (2, "Format 2 — range"),
                    (3, "Format 3 — linked"),
                ]
            )

            if statFormat == 3 {
                StudioMenuPicker(
                    title: "Link to",
                    selection: Binding(
                        get: { linkTargetID ?? linkCandidates.first?.id ?? "" },
                        set: { linkTargetID = $0.isEmpty ? nil : $0 }
                    ),
                    options: linkCandidates.map { ($0.id, $0.label) }
                )
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel") {
                    onComplete()
                    dismiss()
                }
                StudioFlatButton(
                    title: "Apply",
                    role: .primary,
                    isEnabled: !(statFormat == 3 && selectedLinkTarget == nil),
                    isDefaultAction: true
                ) {
                    apply()
                }
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(width: 320)
    }

    private var selectedLinkTarget: StatFormat3Pairing.LinkTarget? {
        let id = linkTargetID ?? linkCandidates.first?.id
        return linkCandidates.first { $0.id == id }
    }

    private func apply() {
        editor.updateAxisStopStatFormat(
            axisTag: axis.tag,
            stopID: stop.id,
            format: statFormat,
            linkedValue: statFormat == 3 ? selectedLinkTarget?.value : nil
        )
        onComplete()
        dismiss()
    }
}

// MARK: - Add naming axis

struct AddFileAxisSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let onComplete: () -> Void

    private enum Kind: String, CaseIterable, Identifiable {
        case slope, width, optical, custom
        var id: String { rawValue }

        var title: String {
            switch self {
            case .slope: return "Slope (ital)"
            case .width: return "Width (wdth)"
            case .optical: return "Optical (opsz)"
            case .custom: return "Custom tag"
            }
        }

        var template: RegistrationAxisFactory.TemplateKind? {
            switch self {
            case .slope: return .slope
            case .width: return .width
            case .optical: return .optical
            case .custom: return nil
            }
        }

        var policyTitle: String {
            switch self {
            case .slope: return "Slope policy"
            case .width: return "Width policy"
            case .optical: return "Optical policy"
            case .custom: return "Custom tag policy"
            }
        }
    }

    @State private var kind: Kind = .slope
    @State private var tagText = "GRAD"
    @State private var nameText = ""
    @State private var valueText = "0"
    @State private var codeText = ""
    @State private var slopeOverrideIsItalic: Bool?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case tag, name, value, code
    }

    private var trimmedCode: String? {
        guard editor.isCodeNamingEnabled else { return nil }
        let t = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var sanitizedTag: String {
        RegistrationAxisFactory.sanitizeAxisTag(tagText)
    }

    private var parsedValue: Double? {
        Double(valueText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var detectedIsItalicFile: Bool {
        guard let font = editor.selectedFont else { return false }
        return RegistrationAxisSupport.isItalicFile(font: font)
    }

    /// What actually gets written for the slope stop: the user's override when set,
    /// otherwise whatever the file's own filename/style flags detect.
    private var isItalicFile: Bool {
        slopeOverrideIsItalic ?? detectedIsItalicFile
    }

    private var kindEnabled: Bool {
        switch kind {
        case .slope, .width, .optical:
            return kind.template.map { editor.canAddRegistrationTemplate($0) } ?? false
        case .custom:
            return true
        }
    }

    private var disabledReason: String? {
        guard let template = kind.template else { return nil }
        return editor.namingAxisBlockReason(for: template)
    }

    private var familyTagCollision: Bool {
        guard kind == .custom, !sanitizedTag.isEmpty, let fonts = editor.project?.fonts else {
            return false
        }
        return RegistrationAxisFactory.tagExistsInFamily(tag: sanitizedTag, fonts: fonts)
    }

    private var tagLengthInvalid: Bool {
        kind == .custom && !tagText.isEmpty && sanitizedTag.count != 4
    }

    private var previewStopName: String {
        switch kind {
        case .slope:
            return isItalicFile ? "Italic" : "Roman"
        case .width, .optical, .custom:
            let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
            switch kind {
            case .width: return "Width"
            case .optical: return "Optical Size"
            case .custom: return sanitizedTag.isEmpty ? "Name" : sanitizedTag
            default: return "Name"
            }
        }
    }

    private var previewTag: String {
        switch kind {
        case .slope: return "ital"
        case .width: return "wdth"
        case .optical: return "opsz"
        case .custom: return sanitizedTag.isEmpty ? "····" : sanitizedTag
        }
    }

    private var previewValue: String {
        switch kind {
        case .slope:
            return isItalicFile ? "1" : "0"
        case .width, .optical, .custom:
            return valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "—"
                : valueText
        }
    }

    private var previewCode: String {
        switch kind {
        case .slope: return isItalicFile ? "1" : "0"
        case .width, .optical, .custom:
            return trimmedCode ?? "—"
        }
    }

    private var previewElidable: Bool {
        switch kind {
        case .slope: return !isItalicFile
        case .width, .optical, .custom: return false
        }
    }

    private var previewLinkedLabel: String? {
        guard kind == .slope else { return nil }
        return isItalicFile ? "0" : "1"
    }

    private var previewFmt: String {
        kind == .slope ? "F3" : "F1"
    }

    private var canAdd: Bool {
        guard kindEnabled else { return false }
        switch kind {
        case .slope:
            return true
        case .width, .optical:
            return parsedValue != nil
                && !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .custom:
            return sanitizedTag.count == 4
                && !familyTagCollision
                && !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && parsedValue != nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Add naming axis")
                .font(StudioTypography.emphasis)

            Text("Naming axes label styles across files without joining the instance grid — no fvar scale, one stop per file.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
                Text("Kind")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                kindTabs
                if let disabledReason, !kindEnabled {
                    Label(disabledReason, systemImage: "lock.fill")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if kindEnabled {
                fieldsRow
            } else {
                Text("Select an available kind to configure a tag and name.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }

            policyBox

            previewSection

            if familyTagCollision {
                Text("Tag “\(sanitizedTag)” is already used by another axis in this family.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            } else if tagLengthInvalid {
                Text("Tag must be exactly 4 characters (letters or digits).")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: StudioSpacing.controlGap) {
                Spacer()
                StudioFlatButton(title: "Cancel") {
                    onComplete()
                    dismiss()
                }
                StudioFlatButton(title: "Add Axis", role: .primary, isEnabled: canAdd, isDefaultAction: true) {
                    addIfValid()
                }
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(width: 540)
        .onAppear {
            selectFirstAvailableKind()
            seedFields(for: kind)
            slopeOverrideIsItalic = nil
        }
    }

    private var kindTabs: some View {
        HStack(spacing: StudioSpacing.rowGap) {
            ForEach(Kind.allCases) { option in
                let enabled = optionEnabled(option)
                let selected = kind == option
                Button {
                    kind = option
                    seedFields(for: option)
                } label: {
                    HStack(spacing: StudioSpacing.tightGap) {
                        if !enabled {
                            Image(systemName: "lock.fill")
                                .font(StudioTypography.caption)
                        }
                        Text(option.title)
                    }
                        .font(StudioTypography.caption)
                        .fontWeight(selected ? .medium : .regular)
                        .foregroundStyle(tabForeground(enabled: enabled, selected: selected))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, StudioSpace.x2)
                        .background(tabBackground(enabled: enabled, selected: selected), in: RoundedRectangle.studio(StudioRadius.control))
                }
                .buttonStyle(.plain)
                .studioHoverFill(shape: .roundedRect(cornerRadius: StudioRadius.control), isEnabled: enabled && !selected)
                .disabled(!enabled)
                .help(enabled ? option.title : (option.template.flatMap { editor.namingAxisBlockReason(for: $0) } ?? ""))
            }
        }
    }

    private func optionEnabled(_ option: Kind) -> Bool {
        switch option {
        case .slope, .width, .optical:
            return option.template.map { editor.canAddRegistrationTemplate($0) } ?? false
        case .custom:
            return true
        }
    }

    private func tabForeground(enabled: Bool, selected: Bool) -> Color {
        if !enabled {
            return selected ? .secondary.opacity(0.7) : .secondary.opacity(0.45)
        }
        if selected { return StudioColors.registrationForeground }
        return StudioColors.primaryMuted
    }

    private func tabBackground(enabled: Bool, selected: Bool) -> Color {
        if !enabled {
            return selected ? StudioColors.selectionNeutralFill : StudioColors.surfaceMuted
        }
        if selected { return StudioColors.registrationBackground }
        return StudioColors.buttonSecondaryFill
    }

    @ViewBuilder
    private var fieldsRow: some View {
        switch kind {
        case .slope:
            slopeOverrideRow
        case .width, .optical:
            HStack(spacing: StudioSpacing.sectionGap) {
                StudioTextField(
                    placeholder: "Tag",
                    text: .constant(previewTag),
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .secondary
                )
                .disabled(true)
                StudioTextField(
                    placeholder: "Display name",
                    text: $nameText,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .focused($focusedField, equals: .name)
                StudioTextField(
                    placeholder: "Value",
                    text: $valueText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .frame(width: RegistrationAxisFormLayout.valueFieldWidth)
                .focused($focusedField, equals: .value)
                if editor.isCodeNamingEnabled {
                    StudioTextField(
                        placeholder: "Code",
                        text: $codeText,
                        font: StudioTypography.monoMeta,
                        rowHeight: StudioFieldMetrics.bodyRowHeight,
                        filledForeground: .primary
                    )
                    .frame(width: RegistrationAxisFormLayout.codeFieldWidth)
                    .focused($focusedField, equals: .code)
                    .help("Optional 1–2 character classification code (letters or digits)")
                }
            }
        case .custom:
            HStack(spacing: StudioSpacing.sectionGap) {
                StudioTextField(
                    placeholder: "Tag",
                    text: $tagText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .focused($focusedField, equals: .tag)
                StudioTextField(
                    placeholder: "Display name",
                    text: $nameText,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .focused($focusedField, equals: .name)
                StudioTextField(
                    placeholder: "Value",
                    text: $valueText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: .primary
                )
                .frame(width: RegistrationAxisFormLayout.valueFieldWidth)
                .focused($focusedField, equals: .value)
                if editor.isCodeNamingEnabled {
                    StudioTextField(
                        placeholder: "Code",
                        text: $codeText,
                        font: StudioTypography.monoMeta,
                        rowHeight: StudioFieldMetrics.bodyRowHeight,
                        filledForeground: .primary
                    )
                    .frame(width: RegistrationAxisFormLayout.codeFieldWidth)
                    .focused($focusedField, equals: .code)
                    .help("Optional 1–2 character classification code (letters or digits)")
                }
            }
        }
    }

    private var slopeOverrideRow: some View {
        HStack(spacing: StudioSpacing.sectionGap) {
            Text("Roman / Italic")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: StudioSpace.x0_5) {
                slopeOverrideOption(title: "Roman", isItalic: false)
                slopeOverrideOption(title: "Italic", isItalic: true)
            }
            .padding(StudioSpace.x0_5)
            .background(StudioColors.surfaceMuted, in: RoundedRectangle.studio(StudioRadius.surface))
            .overlay {
                RoundedRectangle.studio(StudioRadius.surface)
                    .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: StudioStroke.hairline)
            }
            if slopeOverrideIsItalic != nil {
                StudioPlainLinkButton(
                    title: "Reset to detected",
                    role: .accent,
                    font: StudioTypography.caption
                ) {
                    slopeOverrideIsItalic = nil
                }
            } else {
                Text("Auto-detected from this file")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func slopeOverrideOption(title: String, isItalic: Bool) -> some View {
        let selected = self.isItalicFile == isItalic
        return Button {
            slopeOverrideIsItalic = (isItalic == detectedIsItalicFile) ? nil : isItalic
        } label: {
            Text(title)
                .font(StudioTypography.caption)
                .fontWeight(selected ? .medium : .regular)
                .foregroundStyle(selected ? StudioColors.registrationForeground : .secondary)
                .padding(.horizontal, StudioSpace.x2_5)
                .padding(.vertical, StudioFieldMetrics.tabChipVerticalPadding)
                .background(
                    selected ? StudioColors.registrationBackground : Color.clear,
                    in: RoundedRectangle.studio(StudioRadius.control)
                )
        }
        .buttonStyle(.plain)
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: StudioRadius.control),
            isEnabled: !selected
        )
    }

    private var policyBox: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.tightGap) {
            Text(kind.policyTitle)
                .font(StudioTypography.caption.weight(.medium))
                .foregroundStyle(kindEnabled ? StudioColors.registrationForeground : .secondary)
            Text(policyCopy)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if kindEnabled {
                Text("Elidable: \(previewElidable ? "yes — name drops when composing" : "no — name stays in the style string"). Naming order: inserts \(editor.namingOrderInsertHint(forNewTag: previewTag)).")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, StudioSpace.x0_5)
            }
        }
        .padding(StudioSpacing.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (kindEnabled ? StudioColors.registrationBackground : StudioColors.surfaceMuted),
            in: RoundedRectangle.studio(StudioRadius.surface)
        )
        .overlay {
            RoundedRectangle.studio(StudioRadius.surface)
                .strokeBorder(
                    kindEnabled ? StudioColors.registrationStroke : StudioColors.surfaceStrokeStrong,
                    lineWidth: StudioStroke.hairline
                )
        }
    }

    private var policyCopy: String {
        switch kind {
        case .slope:
            if !kindEnabled {
                return disabledReason
                    ?? "One Format 3 stop per file. This tag is already spoken for."
            }
            let basis = slopeOverrideIsItalic != nil ? "You’ve set this file as" : "This file looks"
            if isItalicFile {
                return "\(basis) italic — you’ll get one Format 3 stop at 1 (Italic), linked to 0. The link is a convention pointer, not a second named stop on this file."
            }
            return "\(basis) upright — you’ll get one Format 3 stop at 0 (Roman, elided), linked to 1. The link is a convention pointer, not a second named stop on this file."
        case .width:
            if !kindEnabled {
                return disabledReason
                    ?? "Adds wdth as a naming axis only when Width isn’t already an instance axis."
            }
            return "Adds wdth as a naming axis with an ordinary named stop for this file only — siblings don’t inherit this value. Use Add Stop on other files when you’re ready. Not a 0/1 linked pair."
        case .optical:
            if !kindEnabled {
                return disabledReason
                    ?? "Adds opsz as a naming axis only when Optical Size isn’t already an instance axis."
            }
            return "Adds opsz as a naming axis with an ordinary named stop for this file only — siblings don’t inherit this value. Tag is locked to opsz; set the display name and value that describe this file."
        case .custom:
            return "Must be exactly 4 characters. Uppercase reads as a registered-style tag; lowercase signals private-use. Checked against every file in this family. The stop is written only on this file — siblings stay untouched until you add a stop there."
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.rowGap) {
            Text("Axis tree preview")
                .font(StudioTypography.caption)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                if !kindEnabled {
                    Text(disabledReason ?? "Already exists in the Axis Tree.")
                        .font(StudioTypography.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    HStack(spacing: StudioSpacing.controlGap) {
                        Text("N")
                            .font(StudioTypography.tag)
                            .padding(.horizontal, StudioSpacing.tightGap)
                            .padding(.vertical, StudioSpace.x0_5)
                            .foregroundStyle(.primary)
                            .background(StudioColors.registrationBackground, in: RoundedRectangle.studio(StudioRadius.small))
                        Text(previewStopName)
                            .font(StudioTypography.bodyMedium)
                        Text("No fvar scale · this file")
                            .font(StudioTypography.caption)
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 0)
                        StudioTagPill(text: previewTag, compact: true, role: .registration)
                    }

                    HStack(spacing: StudioSpacing.controlGap) {
                        previewColumnHeader("Format", width: FillStopPreviewLayout.formatColumnWidth, alignment: .center)
                        previewColumnHeader("Value", width: FillStopPreviewLayout.valueColumnWidth, alignment: .trailing)
                        previewColumnHeader("Name", width: nil, alignment: .leading)
                        previewColumnHeader("Elided", width: FillStopPreviewLayout.elidableColumnWidth, alignment: .center)
                        if editor.isCodeNamingEnabled {
                            previewColumnHeader("Code", width: FillStopPreviewLayout.codeColumnWidth, alignment: .center)
                        }
                    }

                    HStack(spacing: StudioSpacing.controlGap) {
                        let fmtColor: Color = {
                            switch previewFmt {
                            case "F2": StudioColors.statFormat2
                            case "F3": StudioColors.statFormat3
                            default: StudioColors.statFormat1
                            }
                        }()
                        Text(previewFmt)
                            .font(StudioTypography.tag.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fmtColor.opacity(0.20), in: RoundedRectangle.studio(StudioRadius.chip))
                            .overlay {
                                RoundedRectangle.studio(StudioRadius.chip)
                                    .strokeBorder(fmtColor.opacity(0.35), lineWidth: 0.5)
                            }
                            .frame(width: FillStopPreviewLayout.formatColumnWidth, alignment: .center)
                        StudioAxisValueLabel(
                            text: previewValue,
                            font: StudioTypography.monoMeta
                        )
                        .frame(width: FillStopPreviewLayout.valueColumnWidth, alignment: .trailing)
                        HStack(spacing: StudioSpacing.tightGap) {
                            Text(previewStopName)
                                .font(StudioTypography.caption)
                            if let linked = previewLinkedLabel {
                                StudioFormat3LinkLabel(linkedTargetName: linked)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        StudioRadioMark(isOn: previewElidable)
                            .frame(width: FillStopPreviewLayout.elidableColumnWidth, alignment: .center)
                        if editor.isCodeNamingEnabled {
                            Text(previewCode)
                                .font(StudioTypography.monoMeta)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(StudioColors.codeBackground, in: RoundedRectangle.studio(StudioRadius.chip))
                                .frame(width: FillStopPreviewLayout.codeColumnWidth, alignment: .center)
                        }
                    }
                }
            }
            .padding(StudioSpacing.contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioColors.surfaceSubtle, in: RoundedRectangle.studio(StudioRadius.surface))
            .overlay {
                RoundedRectangle.studio(StudioRadius.control)
                    .strokeBorder(StudioColors.surfaceStrokeStrong, lineWidth: StudioStroke.hairline)
            }
        }
    }

    private func previewColumnHeader(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(StudioTypography.caption)
            .foregroundStyle(.tertiary)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private func selectFirstAvailableKind() {
        if editor.canAddRegistrationTemplate(.slope) {
            kind = .slope
        } else if editor.canAddRegistrationTemplate(.width) {
            kind = .width
        } else if editor.canAddRegistrationTemplate(.optical) {
            kind = .optical
        } else {
            kind = .custom
        }
    }

    private func seedFields(for option: Kind) {
        switch option {
        case .slope:
            break
        case .width:
            nameText = "Normal"
            valueText = "100"
            focusedField = .name
        case .optical:
            nameText = "Display"
            valueText = "18"
            focusedField = .name
        case .custom:
            if tagText.isEmpty { tagText = "GRAD" }
            if nameText.isEmpty || nameText == "Normal" || nameText == "Display" {
                nameText = "Grade"
            }
            if valueText.isEmpty || valueText == "100" || valueText == "18" {
                valueText = "0"
            }
            focusedField = .tag
        }
    }

    private func addIfValid() {
        guard canAdd else { return }
        let ok: Bool
        switch kind {
        case .slope:
            ok = editor.addRegistrationTemplate(.slope, italicOverride: slopeOverrideIsItalic)
        case .width:
            ok = editor.addRegistrationTemplate(
                .width,
                displayName: nameText,
                value: parsedValue,
                code: trimmedCode
            )
        case .optical:
            ok = editor.addRegistrationTemplate(
                .optical,
                displayName: nameText,
                value: parsedValue,
                code: trimmedCode
            )
        case .custom:
            ok = editor.addRegistrationAxis(
                tag: sanitizedTag,
                displayName: nameText,
                value: parsedValue ?? 0,
                elidable: false,
                code: trimmedCode
            )
        }
        guard ok else { return }
        onComplete()
        dismiss()
    }
}
