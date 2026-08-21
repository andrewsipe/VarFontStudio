import AppKit
import CoreText
import SwiftUI

/// Advance vs ink metrics for the preview stage.
///
/// `NSString.size(withAttributes:)` is advance-based; slanted / italic ink often
/// overhangs that box. The drawable width must span the full ink rect and text
/// must be drawn with a left offset so negative `ink.minX` is not clipped.
enum FontPreviewGlyphMeasurement {
    struct Metrics {
        /// Full intrinsic size (left ink pad + advance + right ink pad).
        var contentSize: CGSize
        /// X offset from the content box origin to the line origin when drawing.
        var drawOffsetX: CGFloat
    }

    private static let hairline: CGFloat = 1

    static func measure(text: String, font: NSFont) -> Metrics {
        let typographicHeight = max(
            font.ascender - font.descender + font.leading,
            font.pointSize,
            1
        )
        guard !text.isEmpty else {
            return Metrics(
                contentSize: CGSize(width: 1, height: typographicHeight),
                drawOffsetX: 0
            )
        }

        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let advance = (text as NSString).size(withAttributes: attributes)
        let advanceWidth = max(advance.width, 0)
        let heightFloor = max(advance.height, typographicHeight)

        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        let ink = CTLineGetImageBounds(line, nil)

        let leftPad = max(0, -ink.minX) + hairline
        let rightPad = max(0, ink.maxX - advanceWidth) + hairline
        let contentWidth = max(leftPad + advanceWidth + rightPad, ink.width + hairline * 2, 1)
        let height = max(heightFloor, ink.height + hairline * 2, 1)

        return Metrics(
            contentSize: CGSize(
                width: contentWidth.rounded(.up),
                height: height.rounded(.up)
            ),
            drawOffsetX: leftPad.rounded(.up)
        )
    }
}

/// Single-line glyph stage using Core Text — avoids SwiftUI `Text` reshaping
/// on every preview invalidation while keeping horizontal pan via the outer ScrollView.
struct FontPreviewGlyphCanvas: NSViewRepresentable {
    var text: String
    var font: NSFont
    var textColor: NSColor
    var alignment: NSTextAlignment
    var opacity: CGFloat
    /// When true, SwiftUI must not overwrite the layer font — slideshow drives it.
    var driveExternally: Bool = false
    var bridge: PreviewGlyphBridge?

    func makeNSView(context: Context) -> FontPreviewGlyphNSView {
        let view = FontPreviewGlyphNSView()
        bridge?.canvas = view
        return view
    }

    func updateNSView(_ nsView: FontPreviewGlyphNSView, context: Context) {
        bridge?.canvas = nsView
        if driveExternally {
            nsView.applyChrome(
                text: text,
                textColor: textColor,
                alignment: alignment,
                opacity: opacity
            )
            return
        }
        nsView.unlockContentSize()
        nsView.apply(
            text: text,
            font: font,
            textColor: textColor,
            alignment: alignment,
            opacity: opacity
        )
    }
}

final class FontPreviewGlyphNSView: NSView {
    private var displayText = ""
    private var displayFont = NSFont.systemFont(ofSize: 12)
    private var displayColor: NSColor = .labelColor
    private var contentAlignment: NSTextAlignment = .left
    private var displayOpacity: CGFloat = 1

    private var metrics = FontPreviewGlyphMeasurement.measure(text: " ", font: .systemFont(ofSize: 12))
    private var lastIntrinsic = CGSize.zero
    private var lockedSize: CGSize?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        clipsToBounds = false
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override var isFlipped: Bool { true }

    func lockContentSize(width: CGFloat, height: CGFloat) {
        lockedSize = CGSize(width: width, height: height)
        lastIntrinsic = lockedSize ?? lastIntrinsic
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func unlockContentSize() {
        guard lockedSize != nil else { return }
        lockedSize = nil
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    /// Slideshow path: swap variation font without SwiftUI involvement.
    func applyVariationFont(_ font: NSFont, lockWidth: Bool) {
        displayFont = font
        let metrics = FontPreviewGlyphMeasurement.measure(text: displayText, font: font)
        self.metrics = metrics

        let height: CGFloat
        if lockWidth, let locked = lockedSize {
            height = max(metrics.contentSize.height, locked.height)
            lastIntrinsic = CGSize(
                width: max(locked.width, metrics.contentSize.width),
                height: height
            )
        } else {
            height = metrics.contentSize.height
            let next = metrics.contentSize
            if abs(next.width - lastIntrinsic.width) + abs(next.height - lastIntrinsic.height) > 1 {
                lastIntrinsic = next
                invalidateIntrinsicContentSize()
            } else {
                lastIntrinsic = next
            }
        }

        needsDisplay = true
    }

    func applyChrome(
        text: String,
        textColor: NSColor,
        alignment: NSTextAlignment,
        opacity: CGFloat
    ) {
        displayText = text
        displayColor = textColor
        contentAlignment = alignment
        displayOpacity = opacity
        needsDisplay = true
    }

    func apply(
        text: String,
        font: NSFont,
        textColor: NSColor,
        alignment: NSTextAlignment,
        opacity: CGFloat
    ) {
        displayText = text
        displayFont = font
        displayColor = textColor
        contentAlignment = alignment
        displayOpacity = opacity
        applyVariationFont(font, lockWidth: false)
    }

    override var intrinsicContentSize: NSSize {
        if let lockedSize { return lockedSize }
        if lastIntrinsic != .zero { return lastIntrinsic }
        return NSSize(
            width: max(metrics.contentSize.width, 1),
            height: max(metrics.contentSize.height, 1)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !displayText.isEmpty,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let contentWidth = lockedSize?.width ?? max(lastIntrinsic.width, metrics.contentSize.width)
        let contentHeight = max(
            lockedSize?.height ?? lastIntrinsic.height,
            metrics.contentSize.height,
            1
        )

        let boxX: CGFloat
        switch contentAlignment {
        case .center:
            boxX = max((bounds.width - contentWidth) / 2, 0)
        case .right:
            boxX = max(bounds.width - contentWidth, 0)
        default:
            boxX = 0
        }
        let boxY = max((bounds.height - contentHeight) / 2, 0)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: displayFont,
            .foregroundColor: displayColor.withAlphaComponent(displayOpacity),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: displayText, attributes: attributes)
        )

        context.saveGState()
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.textPosition = CGPoint(
            x: boxX + metrics.drawOffsetX,
            y: boxY + displayFont.ascender
        )
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
