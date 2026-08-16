import AppKit
import SwiftUI
import VarFontCore

private enum FontPreviewAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }

    var help: String {
        switch self {
        case .leading: "Align left"
        case .center: "Align center"
        case .trailing: "Align right"
        }
    }
}

/// Bundled waterfall word list for the Preview sample-field dice control.
private enum FontPreviewSampleWords {
    private static let lock = NSLock()
    private static var cached: [String]?

    static func randomWord() -> String {
        let list = words
        guard let word = list.randomElement(), !word.isEmpty else {
            return "Handgloves"
        }
        return word
    }

    private static var words: [String] {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = load()
        cached = loaded
        return loaded
    }

    private static func load() -> [String] {
        guard let url = Bundle.main.url(forResource: "waterfall-default", withExtension: "txt"),
              let body = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return body
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Sample text / size / alignment — lives in the footer disclosure header beside
/// Naming Order | Preview so the glyph canvas can claim the former toolbar row.
struct FontPreviewHeaderControls: View {
    @AppStorage("studio.fontPreviewSample") private var sampleText = "Compartmentalization"
    @AppStorage("studio.fontPreviewSize") private var previewSize = 48.0
    @AppStorage("studio.fontPreviewAlignment") private var alignmentRaw = FontPreviewAlignment.leading.rawValue

    private var alignment: FontPreviewAlignment {
        get { FontPreviewAlignment(rawValue: alignmentRaw) ?? .leading }
        nonmutating set { alignmentRaw = newValue.rawValue }
    }

    var body: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            HStack(spacing: StudioSpacing.tightGap) {
                StudioTextField(
                    placeholder: "Instance name when empty",
                    text: $sampleText,
                    font: StudioTypography.bodyMedium,
                    rowHeight: StudioFieldMetrics.tabChipRowHeight,
                    showsClearButton: true
                )

                randomWordButton
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: StudioSpacing.rowGap) {
                Text("Size")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)

                StudioCompactSlider(value: $previewSize, range: 24...144, step: 1)
                    .frame(width: 100)

                Text("\(Int(previewSize.rounded()))")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
                    .monospacedDigit()
            }

            alignmentPicker
        }
    }

    private var randomWordButton: some View {
        let chrome = StudioCompactControlChrome.self
        return Button {
            sampleText = FontPreviewSampleWords.randomWord()
        } label: {
            HStack(spacing: StudioSpacing.tightGap) {
                Text("Random Word")
                    .font(chrome.labelFont)
                Image(systemName: "dice")
                    .font(chrome.symbolFont)
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, chrome.horizontalPadding)
            .frame(height: chrome.controlHeight)
            .background(chrome.idleFill, in: RoundedRectangle.studio(chrome.cornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(shape: .roundedRect(cornerRadius: chrome.cornerRadius))
        .help("Fills font preview with a random word")
    }

    private var alignmentPicker: some View {
        // Same tray + neutral-raised segment language as Instances Names|Coords —
        // mutually exclusive choice, not a brand/selection locus.
        let chrome = StudioCompactControlChrome.self
        return HStack(spacing: 0) {
            ForEach(FontPreviewAlignment.allCases) { option in
                let isSelected = alignment == option
                Button {
                    alignment = option
                } label: {
                    Image(systemName: option.systemImage)
                        .font(chrome.symbolFont)
                        .foregroundStyle(chrome.foreground(isActive: isSelected))
                        .frame(width: StudioFieldMetrics.toolbarIconHitSize, height: chrome.segmentHeight)
                        .background(
                            isSelected ? chrome.activeFill : Color.clear,
                            in: RoundedRectangle.studio(chrome.segmentcornerRadius)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .studioHoverFill(
                    shape: .roundedRect(cornerRadius: chrome.segmentcornerRadius),
                    isEnabled: !isSelected
                )
                .help(option.help)
            }
        }
        .padding(chrome.trayInset)
        .background(chrome.idleFill, in: RoundedRectangle.studio(chrome.cornerRadius))
    }
}

/// Live source-font glyph preview for the editor footer.
struct FontPreviewPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var previewInteraction: PreviewInteractionStore
    @AppStorage("studio.fontPreviewSample") private var sampleText = "Handgloves"
    @AppStorage("studio.fontPreviewSize") private var previewSize = 48.0
    @AppStorage("studio.fontPreviewAlignment") private var alignmentRaw = FontPreviewAlignment.leading.rawValue

    private var alignment: FontPreviewAlignment {
        get { FontPreviewAlignment(rawValue: alignmentRaw) ?? .leading }
        nonmutating set { alignmentRaw = newValue.rawValue }
    }

    private var isHoverPeeking: Bool {
        guard editor.footerPanelMode == .preview,
              previewInteraction.isHoverActive,
              let hover = previewInteraction.hoverInstanceKey else { return false }
        return hover != editor.selectedInstanceKey
    }

    private var isMorphing: Bool {
        previewInteraction.isMorphing
    }

    private var previewActiveInstance: PlannedInstance? {
        // During a morph, prefer the destination instance for captions.
        if editor.footerPanelMode == .preview,
           let key = previewInteraction.morphTargetKey
            ?? previewInteraction.hoverInstanceKey,
           let plan = editor.instancePlan,
           let matched = plan.instances.first(where: { $0.key == key }) {
            return matched
        }
        if let selected = editor.selectedInstance {
            return selected
        }
        return editor.instancePlan?.instances.first
    }

    private var previewCoords: [String: Double]? {
        previewActiveInstance?.coords
    }

    /// Empty / whitespace sample → active instance composed name; else a space so
    /// the canvas still lays out a glyph run while nothing is selected.
    private var displaySample: String {
        let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let name = previewActiveInstance?.composedName, !name.isEmpty {
            return name
        }
        return " "
    }

    private static let canvasColor = StudioColors.canvasBackground

    /// Floor for the glyph stage when the shared footer slot is at its minimum.
    private static let minCanvasHeight: CGFloat = 96

    /// Former in-panel toolbar allotment — folded into the canvas so the
    /// disclosure header can host sample/size/align without shrinking the stage.
    private static let reclaimedToolbarHeight: CGFloat =
        StudioFieldMetrics.bodyMediumRowHeight
        + StudioSpacing.toolbarVertical * 2

    static var statusBarHeight: CGFloat {
        StudioCompactControlChrome.controlHeight
            + StudioSpace.x1 * 2
            + StudioSpacing.panelVertical * 2
    }

    /// Minimum Preview / Naming Order body height. The live shared slot may be
    /// taller when Naming Order’s content needs more room — Preview fills that
    /// same slot and clips glyph overflow instead of growing further.
    static var preferredHeight: CGFloat {
        reclaimedToolbarHeight + minCanvasHeight + statusBarHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fills the shared footer slot (same height as Naming Order). Glyphs
            // render at the chosen size — vertical overflow clips; wide samples pan.
            ZStack {
                Self.canvasColor

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: true) {
                        canvasForeground
                            .frame(
                                minWidth: geo.size.width,
                                minHeight: geo.size.height,
                                maxHeight: geo.size.height,
                                alignment: alignment.frameAlignment
                            )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }
            .frame(minHeight: Self.minCanvasHeight, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .clipped()
            .environment(\.colorScheme, .light)

            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PreviewSlideshowArrowKeyMonitor())
    }

    private var canvasForeground: some View {
        Group {
            if let nsFont = previewFont {
                FontPreviewGlyphCanvas(
                    text: displaySample,
                    font: nsFont,
                    textColor: NSColor(StudioColors.canvasForeground),
                    alignment: alignment.nsTextAlignment,
                    opacity: isHoverPeeking ? 0.92 : 1,
                    driveExternally: isMorphing,
                    bridge: previewInteraction.glyphBridge
                )
                .fixedSize(horizontal: true, vertical: true)
            } else {
                Text(unavailableMessage)
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.canvasTertiary)
            }
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpace.x2_5)
        .onAppear { wireGlyphBridge() }
        .onChange(of: editor.selectedFontID) { _, _ in wireGlyphBridge() }
        .onChange(of: previewSize) { _, _ in wireGlyphBridge() }
    }

    private func wireGlyphBridge() {
        guard let font = editor.selectedFont,
              let fontID = editor.selectedFontID else {
            previewInteraction.glyphBridge.makeFont = nil
            return
        }
        let bookmark = editor.sourceBookmarks[fontID]
        let sourcePath = font.sourcePath
        let size = CGFloat(previewSize)
        let cache = editor.fontPreviewCache
        previewInteraction.glyphBridge.makeFont = { coords in
            cache.nsFont(
                fontID: fontID,
                bookmark: bookmark,
                sourcePath: sourcePath,
                coords: coords,
                size: size,
                cache: false
            )
        }
    }

    private var statusBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let showsSourcePeek = width >= 520
            let showsCaption = width >= 360
            statusBarRow(showsCaption: showsCaption, showsSourcePeek: showsSourcePeek)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Self.statusBarHeight)
        .padding(.horizontal, StudioSpacing.contentInset)
        .background(StudioColors.canvasPhaseHeader)
    }

    private func statusBarRow(showsCaption: Bool, showsSourcePeek: Bool) -> some View {
        HStack(spacing: StudioSpacing.controlGap) {
            Group {
                if showsCaption {
                    instanceStatusCaption
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            previewSlideshowControls

            Group {
                if showsSourcePeek {
                    sourcePeekPill
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var instanceStatusCaption: some View {
        if let instance = previewActiveInstance {
            HStack(spacing: StudioSpacing.controlGap) {
                Text(instance.composedName)
                    .font(StudioTypography.caption)
                    .foregroundStyle(
                        isHoverPeeking
                            ? StudioColors.canvasSecondary
                            : StudioColors.canvasForeground
                    )
                    .lineLimit(1)

                Text("·")
                    .foregroundStyle(StudioColors.canvasQuaternary)

                Text(coordsCaption(for: instance))
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(StudioColors.canvasSecondary)
                    .lineLimit(1)
            }
        } else {
            Text("Select an instance to preview")
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.canvasTertiary)
        }
    }

    private var previewSlideshowControls: some View {
        let chrome = StudioCompactControlChrome.self
        let enabled = editor.canRunPreviewSlideshow
        let playing = editor.isPreviewSlideshowPlaying
        // Same compact chrome as Random Word / alignment in the Preview header.
        // Sit on window background so adaptive (dark/light) ink matches those
        // controls — the paper status strip alone would wash out dark-mode secondary.
        return HStack(spacing: StudioSpacing.tightGap) {
            HStack(spacing: 0) {
                slideshowTransportButton(
                    systemName: "chevron.up",
                    isActive: playing && editor.previewSlideshowDirection == .up,
                    help: editor.previewSlideshowDirectionHelp(.up),
                    isEnabled: enabled
                ) {
                    editor.handlePreviewSlideshowDirection(.up)
                }
                slideshowTransportButton(
                    systemName: "stop.fill",
                    isActive: false,
                    help: "Stop slideshow",
                    isEnabled: enabled && playing
                ) {
                    editor.stopPreviewSlideshow()
                }
                slideshowTransportButton(
                    systemName: "play.fill",
                    isActive: playing,
                    help: "Play slideshow",
                    isEnabled: enabled && !playing
                ) {
                    editor.startPreviewSlideshow()
                }
                slideshowTransportButton(
                    systemName: "chevron.down",
                    isActive: playing && editor.previewSlideshowDirection == .down,
                    help: editor.previewSlideshowDirectionHelp(.down),
                    isEnabled: enabled
                ) {
                    editor.handlePreviewSlideshowDirection(.down)
                }
            }
            .padding(chrome.trayInset)
            .background(chrome.idleFill, in: RoundedRectangle.studio(chrome.cornerRadius))
            .opacity(enabled ? 1 : 0.45)

            Button {
                editor.cyclePreviewSlideshowSpeed()
            } label: {
                Text(editor.previewSlideshowSpeed.label)
                    .font(chrome.labelFont)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, chrome.horizontalPadding)
                    .frame(height: chrome.controlHeight)
                    .background(chrome.idleFill, in: RoundedRectangle.studio(chrome.cornerRadius))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .studioHoverFill(shape: .roundedRect(cornerRadius: chrome.cornerRadius), isEnabled: enabled)
            .disabled(!enabled)
            .help("Slideshow speed")
            .opacity(enabled ? 1 : 0.45)
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpace.x1)
        .background(
            Color(nsColor: .windowBackgroundColor),
            in: RoundedRectangle.studio(chrome.cornerRadius)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private func slideshowTransportButton(
        systemName: String,
        isActive: Bool,
        help: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let chrome = StudioCompactControlChrome.self
        return Button(action: action) {
            Image(systemName: systemName)
                .font(chrome.symbolFont)
                .foregroundStyle(chrome.foreground(isActive: isActive, isEnabled: isEnabled))
                .frame(width: StudioFieldMetrics.toolbarIconHitSize, height: chrome.segmentHeight)
                .background(
                    isActive ? chrome.activeFill : Color.clear,
                    in: RoundedRectangle.studio(chrome.segmentcornerRadius)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .studioHoverFill(
            shape: .roundedRect(cornerRadius: chrome.segmentcornerRadius),
            isEnabled: isEnabled && !isActive
        )
        .disabled(!isEnabled)
        .help(help)
    }

    /// Source = quiet baseline on paper. Peek = soft blue wash + blue-700 label
    /// (paper-safe — never dark-mode selection navy).
    private var sourcePeekPill: some View {
        let peeking = isHoverPeeking
        return Text(peeking ? "Peek · hover" : (isMorphing ? "Source · morph" : "Source · live"))
            .font(StudioTypography.caption)
            .foregroundStyle(
                peeking
                    ? StudioColors.canvasPeekForeground
                    : StudioColors.canvasSecondary
            )
            .padding(.horizontal, StudioSpacing.contentInset)
            .padding(.vertical, StudioSpace.x0_5)
            .background {
                Capsule()
                    .fill(peeking ? StudioColors.canvasHoverFill : Color.clear)
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        peeking
                            ? StudioColors.canvasPeekForeground.opacity(0.35)
                            : StudioColors.canvasDivider,
                        lineWidth: StudioStroke.hairline
                    )
            }
            .fixedSize(horizontal: true, vertical: false)
    }

    private var previewFont: NSFont? {
        guard let font = editor.selectedFont,
              let fontID = editor.selectedFontID,
              let coords = previewCoords else {
            return nil
        }
        return editor.fontPreviewCache.nsFont(
            fontID: fontID,
            bookmark: editor.sourceBookmarks[fontID],
            sourcePath: font.sourcePath,
            coords: coords,
            size: CGFloat(previewSize),
            cache: true
        )
    }

    private var unavailableMessage: String {
        if editor.selectedFont == nil {
            return "Open a variable font to preview."
        }
        if previewCoords == nil {
            return "Select an instance to preview."
        }
        return "Preview unavailable for this font file."
    }

    private func coordsCaption(for instance: PlannedInstance) -> String {
        let order = editor.selectedFont?.axes.map(\.tag) ?? Array(instance.coords.keys).sorted()
        return StudioFormatting.coordPairs(coords: instance.coords, namingOrder: order)
            .joined(separator: " · ")
            .replacingOccurrences(of: "=", with: ":")
    }
}

// MARK: - Arrow keys (Preview slideshow)

/// ↑/↓ match the transport chevrons while Preview is showing. Skips when a text
/// field is editing so sample / search fields keep normal caret movement.
private struct PreviewSlideshowArrowKeyMonitor: NSViewRepresentable {
    @EnvironmentObject private var editor: EditorViewModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(editor: editor)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(editor: editor)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private weak var editor: EditorViewModel?
        private var monitor: Any?

        func attach(editor: EditorViewModel) {
            self.editor = editor
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            editor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let editor,
                  editor.footerPanelMode == .preview,
                  editor.canRunPreviewSlideshow,
                  event.modifierFlags
                    .intersection([.command, .option, .control, .shift])
                    .isEmpty
            else {
                return event
            }
            if Self.isEditingTextField {
                return event
            }

            // kVK_UpArrow = 126, kVK_DownArrow = 125
            switch event.keyCode {
            case 126:
                editor.handlePreviewSlideshowDirection(.up)
                return nil
            case 125:
                editor.handlePreviewSlideshowDirection(.down)
                return nil
            default:
                return event
            }
        }

        private static var isEditingTextField: Bool {
            StudioTextEditingFocus.isActive
        }
    }
}
