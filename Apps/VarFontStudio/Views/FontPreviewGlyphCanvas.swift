import AppKit
import CoreText
import QuartzCore
import SwiftUI

/// Advance vs ink metrics for the preview stage.
///
/// `NSString.size(withAttributes:)` is advance-based; slanted / italic ink often
/// overhangs that box. Sizing the layer from advances alone + clipping shaves
/// the ends — pad with `CTLineGetImageBounds` so overhang stays visible.
enum FontPreviewGlyphMeasurement {
    struct Metrics {
        /// Full intrinsic size (left overhang + advance + right overhang).
        var contentSize: CGSize
        /// Offset of the advance origin inside `contentSize` (left ink pad).
        var leftInset: CGFloat
        /// CATextLayer width: advance + right ink pad.
        var layerWidth: CGFloat
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
                leftInset: 0,
                layerWidth: 1
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

        let leftInset = max(0, -ink.minX) + hairline
        let rightPad = max(0, ink.maxX - advanceWidth) + hairline
        let layerWidth = max(advanceWidth + rightPad, 1)
        let contentWidth = max(leftInset + layerWidth, 1)
        // Image bounds are baseline-relative; use ink height when it exceeds typographic.
        let height = max(heightFloor, ink.height + hairline * 2, 1)

        return Metrics(
            contentSize: CGSize(
                width: contentWidth.rounded(.up),
                height: height.rounded(.up)
            ),
            leftInset: leftInset.rounded(.up),
            layerWidth: layerWidth.rounded(.up)
        )
    }
}

/// Single-line glyph stage backed by `CATextLayer` — avoids SwiftUI `Text` reshaping
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
    private let textLayer = CATextLayer()
    private var lastIntrinsic = CGSize.zero
    private var lockedSize: CGSize?
    private var leftInset: CGFloat = 0
    private var layerWidth: CGFloat = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        clipsToBounds = false
        layer?.addSublayer(textLayer)
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
        textLayer.masksToBounds = false
        textLayer.actions = [
            "contents": NSNull(),
            "string": NSNull(),
            "fontSize": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "opacity": NSNull(),
            "font": NSNull(),
        ]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    func lockContentSize(width: CGFloat, height: CGFloat) {
        lockedSize = CGSize(width: width, height: height)
        lastIntrinsic = lockedSize ?? lastIntrinsic
        invalidateIntrinsicContentSize()
    }

    func unlockContentSize() {
        guard lockedSize != nil else { return }
        lockedSize = nil
        invalidateIntrinsicContentSize()
    }

    /// Slideshow path: swap variation font without SwiftUI involvement.
    func applyVariationFont(_ font: NSFont, lockWidth: Bool) {
        textLayer.font = font
        textLayer.fontSize = font.pointSize
        let text = (textLayer.string as? String) ?? ""
        let metrics = FontPreviewGlyphMeasurement.measure(text: text, font: font)
        leftInset = metrics.leftInset
        layerWidth = metrics.layerWidth

        let height: CGFloat
        if lockWidth, let locked = lockedSize {
            height = max(metrics.contentSize.height, locked.height)
            // Intrinsic stays at the precomputed max so morphing doesn't reflow.
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

        textLayer.frame = CGRect(x: leftInset, y: 0, width: layerWidth, height: height)
        needsLayout = true
    }

    func applyChrome(
        text: String,
        textColor: NSColor,
        alignment: NSTextAlignment,
        opacity: CGFloat
    ) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        textLayer.contentsScale = scale
        textLayer.string = text
        textLayer.foregroundColor = textColor.cgColor
        textLayer.opacity = Float(opacity)
        textLayer.alignmentMode = alignmentMode(for: alignment)
        needsLayout = true
    }

    func apply(
        text: String,
        font: NSFont,
        textColor: NSColor,
        alignment: NSTextAlignment,
        opacity: CGFloat
    ) {
        applyChrome(text: text, textColor: textColor, alignment: alignment, opacity: opacity)
        applyVariationFont(font, lockWidth: false)
    }

    override var intrinsicContentSize: NSSize {
        if let lockedSize { return lockedSize }
        if lastIntrinsic != .zero { return lastIntrinsic }
        let frame = textLayer.frame
        return NSSize(
            width: max(frame.maxX, 1),
            height: max(frame.height, 1)
        )
    }

    override func layout() {
        super.layout()
        let contentWidth = lockedSize?.width ?? max(lastIntrinsic.width, leftInset + layerWidth)
        let contentHeight = max(
            lockedSize?.height ?? lastIntrinsic.height,
            textLayer.frame.height,
            1
        )

        let boxX: CGFloat
        switch textLayer.alignmentMode {
        case .center:
            boxX = max((bounds.width - contentWidth) / 2, 0)
        case .right:
            boxX = max(bounds.width - contentWidth, 0)
        default:
            boxX = 0
        }
        let boxY = max((bounds.height - contentHeight) / 2, 0)

        textLayer.frame = CGRect(
            x: boxX + leftInset,
            y: boxY,
            width: layerWidth,
            height: contentHeight
        )
    }

    private func alignmentMode(for alignment: NSTextAlignment) -> CATextLayerAlignmentMode {
        switch alignment {
        case .center: .center
        case .right: .right
        default: .left
        }
    }
}
