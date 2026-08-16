import AppKit
import QuartzCore
import SwiftUI

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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(textLayer)
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
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
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let text = (textLayer.string as? String) ?? ""
        let size = (text as NSString).size(withAttributes: attributes)
        let height = max(size.height, font.ascender - font.descender + font.leading)
        let width = max(size.width.rounded(.up), 1)
        if lockWidth, let locked = lockedSize {
            textLayer.frame = CGRect(
                x: 0,
                y: 0,
                width: max(locked.width, width),
                height: max(locked.height, height)
            )
        } else {
            textLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
            let next = CGSize(width: width, height: height)
            if abs(next.width - lastIntrinsic.width) + abs(next.height - lastIntrinsic.height) > 1 {
                lastIntrinsic = next
                invalidateIntrinsicContentSize()
            }
        }
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
        return NSSize(width: max(frame.width, 1), height: max(frame.height, 1))
    }

    override func layout() {
        super.layout()
        var frame = textLayer.frame
        if let locked = lockedSize {
            frame.size.width = locked.width
            frame.size.height = max(frame.size.height, locked.height)
        }
        switch textLayer.alignmentMode {
        case .center:
            frame.origin.x = max((bounds.width - frame.width) / 2, 0)
        case .right:
            frame.origin.x = max(bounds.width - frame.width, 0)
        default:
            frame.origin.x = 0
        }
        frame.origin.y = max((bounds.height - frame.height) / 2, 0)
        textLayer.frame = frame
    }

    private func alignmentMode(for alignment: NSTextAlignment) -> CATextLayerAlignmentMode {
        switch alignment {
        case .center: .center
        case .right: .right
        default: .left
        }
    }
}
