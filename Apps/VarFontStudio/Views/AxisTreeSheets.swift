import SwiftUI
import VarFontCore

// MARK: - Add stop sheet

struct AddAxisStopSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    let axis: AxisDefinition
    let onComplete: () -> Void

    @State private var statFormat = 1
    @State private var pinText = ""
    @State private var minText = ""
    @State private var maxText = ""
    @State private var nameText = ""
    @State private var linkTargetID: String?
    @State private var tabKeyMonitor: TabKeyMonitor?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case pin, min, max, name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Add Stop")
                .font(StudioTypography.emphasis)

            Text(axisSubtitle)
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)

            Picker("STAT format", selection: $statFormat) {
                Text("Format 1 — static").tag(1)
                Text("Format 2 — range").tag(2)
                Text("Format 3 — linked").tag(3)
            }
            .pickerStyle(.menu)
            .onChange(of: statFormat) { _, _ in seedDefaults() }

            VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
                formatFields
                StudioTextField(
                    placeholder: "Name",
                    text: $nameText,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    onSubmit: addStopIfValid
                )
                .focused($focusedField, equals: .name)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onComplete()
                    dismiss()
                }
                Button("Add Stop") {
                    addStopIfValid()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            seedDefaults()
            nameText = "Name"
            focusedField = .pin
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
        .onDisappear {
            tabKeyMonitor?.stop()
            tabKeyMonitor = nil
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
            Picker("Link to", selection: Binding(
                get: { linkTargetID ?? linkCandidates.first?.id },
                set: { linkTargetID = $0 }
            )) {
                ForEach(linkCandidates) { candidate in
                    Text(candidate.name).tag(Optional(candidate.id))
                }
            }
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

    private func advanceFocusedField(from field: Field) {
        let order = fieldOrder
        guard let index = order.firstIndex(of: field) else { return }
        if index + 1 < order.count {
            focusedField = order[index + 1]
        } else {
            focusedField = .name
        }
    }

    private var fieldOrder: [Field] {
        switch statFormat {
        case 2: [.min, .pin, .max, .name]
        default: [.pin, .name]
        }
    }

    private var linkCandidates: [AxisValue] {
        axis.values.filter { $0.statFormat != 3 }
    }

    private func seedDefaults() {
        let suggested = editor.suggestedNewStopValue(for: axis)
        pinText = StudioFormatting.axisValue(suggested)
        minText = StudioFormatting.axisValue(max((axis.min ?? suggested) , suggested - 20))
        maxText = StudioFormatting.axisValue(min((axis.max ?? suggested + 20), suggested + 20))
        if linkTargetID == nil {
            linkTargetID = linkCandidates.first?.id
        }
    }

    private var axisSubtitle: String {
        let title = axis.displayName ?? axis.tag
        if let min = axis.min, let max = axis.max {
            return "\(title) · allowed \(StudioFormatting.axisValue(min)) – \(StudioFormatting.axisValue(max))"
        }
        return title
    }

    private var parsedPin: Double? { Double(pinText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var parsedMin: Double? { Double(minText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    private var parsedMax: Double? { Double(maxText.trimmingCharacters(in: .whitespacesAndNewlines)) }

    private var trimmedName: String {
        nameText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationMessage: String? {
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
            guard linkTargetID != nil else { return "Choose a link target." }
            return parsedPin.flatMap { editor.validateAxisStopValue($0, for: axis) }
        default:
            guard let pin = parsedPin else { return "Enter a valid static value." }
            return editor.validateAxisStopValue(pin, for: axis)
        }
    }

    private var canAdd: Bool { validationMessage == nil }

    private func addStopIfValid() {
        guard canAdd else { return }
        let name = trimmedName
        let tag = axis.tag
        onComplete()
        dismiss()
        Task { @MainActor in
            switch statFormat {
            case 2:
                guard let pin = parsedPin, let min = parsedMin, let max = parsedMax else { return }
                editor.insertAxisStop(axisTag: tag, value: pin, name: name, statFormat: 2, rangeMin: min, rangeMax: max)
            case 3:
                guard let pin = parsedPin else { return }
                editor.insertAxisStop(axisTag: tag, value: pin, name: name, statFormat: 3, linkedStopID: linkTargetID)
            default:
                guard let pin = parsedPin else { return }
                editor.insertAxisStop(axisTag: tag, value: pin, name: name)
            }
        }
    }
}

// MARK: - Fill stops sheet

/// Standalone quick-fill tool, reachable anytime from the axis tree (not gated behind a plan
/// warning). Unlike the resolver's empty-axis fix, this replaces whatever stops already exist,
/// so it doubles as a way to re-fill gaps or redo a fill with a different count/interval —
/// just reopen the sheet and apply again, no undo required.
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
            VStack(alignment: .leading, spacing: 4) {
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

            HStack {
                Spacer()
                Button("Cancel") {
                    onComplete()
                    dismiss()
                }
                Button("Fill") {
                    if hasCustomNamedStops {
                        confirmingReplace = true
                    } else {
                        apply()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
            }
        }
        .padding(20)
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
        if stop.statFormat == 3, let linkedValue = stop.linkedValue,
           let target = axis.values.first(where: { $0.id != stop.id && AxisCoordinate.valuesEqual($0.value, linkedValue) }) {
            _linkTargetID = State(initialValue: target.id)
        }
    }

    private var linkCandidates: [AxisValue] {
        axis.values.filter { $0.id != stop.id && $0.statFormat != 3 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Format · \(stop.name)")
                .font(StudioTypography.emphasis)

            Picker("STAT format", selection: $statFormat) {
                Text("Format 1 — static").tag(1)
                Text("Format 2 — range").tag(2)
                Text("Format 3 — linked").tag(3)
            }
            .pickerStyle(.menu)

            if statFormat == 3 {
                Picker("Link to", selection: Binding(
                    get: { linkTargetID ?? linkCandidates.first?.id },
                    set: { linkTargetID = $0 }
                )) {
                    ForEach(linkCandidates) { candidate in
                        Text(candidate.name).tag(Optional(candidate.id))
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onComplete()
                    dismiss()
                }
                Button("Apply") {
                    apply()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(statFormat == 3 && linkTargetID == nil && linkCandidates.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func apply() {
        editor.updateAxisStopStatFormat(
            axisTag: axis.tag,
            stopID: stop.id,
            format: statFormat,
            linkTargetStopID: statFormat == 3 ? linkTargetID : nil
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
    }

    @State private var kind: Kind = .slope
    @State private var tagText = ""
    @State private var nameText = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case tag, name
    }

    private var sanitizedTag: String {
        RegistrationAxisFactory.sanitizeAxisTag(tagText)
    }

    private var templateAvailable: Bool {
        guard let template = kind.template else { return true }
        return editor.canAddRegistrationTemplate(template)
    }

    private var customCollision: Bool {
        guard kind == .custom, let axes = editor.selectedFont?.axes, !sanitizedTag.isEmpty else {
            return false
        }
        return !RegistrationAxisFactory.canAddRegistrationAxis(tag: sanitizedTag, axes: axes)
    }

    private var canAdd: Bool {
        switch kind {
        case .slope, .width, .optical:
            return templateAvailable
        case .custom:
            return !sanitizedTag.isEmpty
                && !customCollision
                && !nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.sectionGap) {
            Text("Add Naming Axis")
                .font(StudioTypography.emphasis)

            infoBlock

            Picker("Kind", selection: $kind) {
                ForEach(Kind.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { _, newKind in
                if newKind != .custom {
                    focusedField = nil
                } else {
                    focusedField = .tag
                }
            }

            kindDetail

            if kind != .custom, !templateAvailable {
                Text("An axis with this tag already exists in the Axis Tree.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }
            if customCollision {
                Text("An axis with tag “\(sanitizedTag)” already exists.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onComplete()
                    dismiss()
                }
                Button("Add Axis") {
                    addIfValid()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            if !editor.canAddRegistrationTemplate(.slope) {
                if editor.canAddRegistrationTemplate(.width) {
                    kind = .width
                } else if editor.canAddRegistrationTemplate(.optical) {
                    kind = .optical
                } else {
                    kind = .custom
                    focusedField = .tag
                }
            }
        }
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
            Text("Naming axes contribute style names across files in a family — Roman vs Italic, or a custom GRADE — without joining the instance grid. They have no fvar scale: each file carries the stop that describes that file.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Italic (ital) follows Playfair’s STAT pattern: the Roman file has one Format 3 stop at 0 (Roman, linked to 1); the Italic file has one Format 3 stop at 1 (Italic, linked to 0). The linked value is a convention pointer — not a second named stop on the same file. Width, optical, and custom naming axes use ordinary named stops instead of a 0/1 switch.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioColors.registrationBackground, in: RoundedRectangle(cornerRadius: StudioRadius.row))
        .overlay {
            RoundedRectangle(cornerRadius: StudioRadius.row)
                .strokeBorder(StudioColors.registrationStroke, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var kindDetail: some View {
        switch kind {
        case .slope:
            Text("Adds `ital` with one Format 3 stop per file — Roman 0→1 on upright files, Italic 1→0 on italic files.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        case .width:
            Text("Adds `wdth` as a naming axis only when Width isn’t already an instance axis.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        case .optical:
            Text("Adds `opsz` as a naming axis only when Optical Size isn’t already an instance axis.")
                .font(StudioTypography.caption)
                .foregroundStyle(.secondary)
        case .custom:
            VStack(alignment: .leading, spacing: StudioSpacing.controlGap) {
                Text("Any unique 4-character tag (e.g. GRAD) plus a display name.")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.secondary)
                StudioTextField(
                    placeholder: "Tag (e.g. GRAD)",
                    text: $tagText,
                    font: StudioTypography.monoMeta,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: StudioColors.registrationForeground
                )
                .focused($focusedField, equals: .tag)
                StudioTextField(
                    placeholder: "Display name (e.g. Grade)",
                    text: $nameText,
                    rowHeight: StudioFieldMetrics.bodyRowHeight,
                    filledForeground: StudioColors.registrationForeground,
                    onSubmit: addIfValid
                )
                .focused($focusedField, equals: .name)
            }
        }
    }

    private func addIfValid() {
        guard canAdd else { return }
        let ok: Bool
        switch kind {
        case .slope:
            ok = editor.addRegistrationTemplate(.slope)
        case .width:
            ok = editor.addRegistrationTemplate(.width)
        case .optical:
            ok = editor.addRegistrationTemplate(.optical)
        case .custom:
            ok = editor.addRegistrationAxis(tag: sanitizedTag, displayName: nameText)
        }
        guard ok else { return }
        onComplete()
        dismiss()
    }
}

