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
            StudioTextField(
                placeholder: "Sample text",
                text: $sampleText,
                font: StudioTypography.bodyMedium,
                rowHeight: StudioFieldMetrics.tabChipRowHeight
            )
            .frame(maxWidth: .infinity)

            HStack(spacing: StudioSpacing.rowGap) {
                Text("Size")
                    .font(StudioTypography.caption)
                    .foregroundStyle(.tertiary)

                Slider(value: $previewSize, in: 24...72, step: 1)
                    .frame(width: 100)
                    .controlSize(.mini)

                Text("\(Int(previewSize.rounded()))")
                    .font(StudioTypography.monoMeta)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 24, alignment: .trailing)
            }

            alignmentPicker
        }
    }

    private var alignmentPicker: some View {
        HStack(spacing: StudioSpacing.instanceRowGap) {
            ForEach(FontPreviewAlignment.allCases) { option in
                Button {
                    alignment = option
                } label: {
                    Image(systemName: option.systemImage)
                        .font(StudioTypography.caption)
                        .foregroundStyle(alignment == option ? StudioColors.brand : .secondary)
                        .frame(width: StudioFieldMetrics.toolbarIconHitSize, height: StudioFieldMetrics.tabChipRowHeight)
                        .background {
                            RoundedRectangle(cornerRadius: StudioRadius.small)
                                .fill(alignment == option ? StudioColors.brand.opacity(0.12) : Color.clear)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: StudioRadius.small))
                }
                .buttonStyle(.plain)
                .studioHoverIcon(
                    isEnabled: alignment != option,
                    tint: alignment == option ? StudioColors.brand : nil
                )
                .help(option.help)
            }
        }
        .padding(StudioSpace.x0_5)
        .background(StudioColors.surfaceInset, in: RoundedRectangle(cornerRadius: StudioRadius.control))
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
                Text(sampleText.isEmpty ? " " : sampleText)
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
            Text("Select an instance to preview")
                .font(StudioTypography.caption)
                .foregroundStyle(StudioColors.canvasTertiary)
            Text(editor.isPreviewHoverPeeking ? "Peek · hover" : "Source · live")
                .font(StudioTypography.caption)
                .foregroundStyle(statusPillForeground)
                .padding(.horizontal, StudioSpacing.contentInset)
                .padding(.vertical, StudioSpace.x0_5)
                .background(
                    Capsule()
                        .strokeBorder(
                            editor.isPreviewHoverPeeking
                                ? StudioColors.canvasTertiary
                                : StudioColors.canvasDivider,
                            lineWidth: StudioStroke.regular
                        )
                        .background(
                            Capsule().fill(
                                editor.isPreviewHoverPeeking
                                    ? StudioColors.canvasHoverFill
                                    : Color.clear
                            )
                        )
                )
        }
        .padding(.horizontal, StudioSpacing.contentInset)
        .padding(.vertical, StudioSpacing.panelVertical)
        .background(StudioColors.canvasPhaseHeader)
    }

    private var statusPillForeground: Color {
        editor.isPreviewHoverPeeking
            ? StudioColors.canvasSecondary
            : StudioColors.canvasTertiary
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
