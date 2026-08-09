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

                StudioCompactSlider(value: $previewSize, range: 24...72, step: 1)
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
            .background(chrome.idleFill, in: RoundedRectangle(cornerRadius: chrome.cornerRadius))
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
                            in: RoundedRectangle(cornerRadius: chrome.segmentcornerRadius)
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
        .background(chrome.idleFill, in: RoundedRectangle(cornerRadius: chrome.cornerRadius))
    }
}

/// Live source-font glyph preview for the editor footer.
struct FontPreviewPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @AppStorage("studio.fontPreviewSample") private var sampleText = "Handgloves"
    @AppStorage("studio.fontPreviewSize") private var previewSize = 48.0
    @AppStorage("studio.fontPreviewAlignment") private var alignmentRaw = FontPreviewAlignment.leading.rawValue

    private var alignment: FontPreviewAlignment {
        get { FontPreviewAlignment(rawValue: alignmentRaw) ?? .leading }
        nonmutating set { alignmentRaw = newValue.rawValue }
    }

    /// Empty / whitespace sample → active instance composed name; else a space so
    /// the canvas still lays out a glyph run while nothing is selected.
    private var displaySample: String {
        let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let name = editor.previewActiveInstance?.composedName, !name.isEmpty {
            return name
        }
        return " "
    }

    private static let canvasColor = StudioColors.canvasBackground

    /// Floor on the glyph canvas height so it never collapses to nothing if the
    /// shared naming-order/preview footer height is ever smaller than expected.
    private static let minCanvasHeight: CGFloat = 96

    /// Former in-panel toolbar allotment — now folded into the canvas so the
    /// shared footer footprint stays identical after moving controls into the
    /// disclosure header.
    private static let reclaimedToolbarHeight: CGFloat =
        StudioFieldMetrics.bodyMediumRowHeight
        + StudioSpacing.toolbarVertical * 2

    /// Comfortable natural height for this panel (glyph canvas + status bar, with
    /// the former toolbar row folded into the canvas). Used as a floor so the
    /// shared naming-order/preview footer height never squeezes the canvas down
    /// and switching tabs never changes panel size.
    static let preferredHeight: CGFloat =
        reclaimedToolbarHeight
        + minCanvasHeight
        + 28                                      // status bar row

    var body: some View {
        VStack(spacing: 0) {
            // The canvas claims every bit of leftover height (via maxHeight:
            // .infinity) while `statusBar` below only takes its natural height —
            // standard VStack flex negotiation, so the two always sum to exactly
            // the space this panel is given, with no measuring required and no
            // residual gap above the status strip.
            //
            // Glyphs render at the requested size (no shrink-to-fit). When the
            // sample is wider than the canvas — large size and/or expanded wdth —
            // horizontal scroll preserves true width instead of compressing.
            ZStack {
                Self.canvasColor

                GeometryReader { geo in
                    ScrollView(.horizontal, showsIndicators: true) {
                        canvasForeground
                            .frame(
                                minWidth: geo.size.width,
                                minHeight: geo.size.height,
                                alignment: alignment.frameAlignment
                            )
                    }
                }
            }
            .frame(minHeight: Self.minCanvasHeight, maxHeight: .infinity)
            .clipped()
            .environment(\.colorScheme, .light)

            statusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var canvasForeground: some View {
        Group {
            if let nsFont = previewFont {
                Text(displaySample)
                    .font(Font(nsFont))
                    .foregroundStyle(StudioColors.canvasForeground)
                    .multilineTextAlignment(alignment.textAlignment)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .opacity(editor.isPreviewHoverPeeking ? 0.92 : 1)
            } else {
                Text(unavailableMessage)
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.canvasTertiary)
            }
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpace.x2_5)
    }

    private var statusBar: some View {
        HStack(spacing: StudioSpacing.controlGap) {
            if let instance = editor.previewActiveInstance {
                Text(instance.composedName)
                    .font(StudioTypography.caption)
                    .foregroundStyle(
                        editor.isPreviewHoverPeeking
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
            } else {
                Text("Select an instance to preview")
                    .font(StudioTypography.caption)
                    .foregroundStyle(StudioColors.canvasTertiary)
            }

            Spacer(minLength: 0)

            sourcePeekPill
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpacing.panelVertical)
        .background(StudioColors.canvasPhaseHeader)
    }

    /// Source = quiet baseline on paper. Peek = soft blue wash + blue-700 label
    /// (paper-safe — never dark-mode selection navy).
    private var sourcePeekPill: some View {
        let peeking = editor.isPreviewHoverPeeking
        return Text(peeking ? "Peek · hover" : "Source · live")
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
    }

    private var previewFont: NSFont? {
        guard let font = editor.selectedFont,
              let fontID = editor.selectedFontID,
              let instance = editor.previewActiveInstance else {
            return nil
        }
        return editor.fontPreviewCache.nsFont(
            fontID: fontID,
            bookmark: editor.sourceBookmarks[fontID],
            sourcePath: font.sourcePath,
            coords: instance.coords,
            size: CGFloat(previewSize)
        )
    }

    private var unavailableMessage: String {
        if editor.selectedFont == nil {
            return "Open a variable font to preview."
        }
        if editor.previewActiveInstance == nil {
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
