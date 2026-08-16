import AppKit
import Combine
import Foundation

/// Hover / peek / morph chrome for the footer Preview — kept off `EditorViewModel`
/// so pointer and slideshow work do not republish the whole tree.
///
/// Per-frame variation during a morph is pushed through `glyphBridge` directly onto
/// the CATextLayer (no `@Published` coords), which avoids SwiftUI layout thrash /
/// “waviness” as glyph advances change.
@MainActor
final class PreviewInteractionStore: ObservableObject {
    /// Last instance hovered in Preview (sticky across row gaps).
    @Published var hoverInstanceKey: String?
    /// True while the pointer is over an instance row in Preview mode.
    @Published var isHoverActive = false
    /// True while a slideshow morph segment is in progress (status chrome only).
    @Published var isMorphing = false
    /// Instance key the current morph is heading toward (status caption / settle target).
    @Published var morphTargetKey: String?

    /// Imperative glyph stage — registered by `FontPreviewGlyphCanvas`.
    let glyphBridge = PreviewGlyphBridge()

    private var hoverDebounceTask: Task<Void, Never>?

    /// - Parameter key: Pass a key on enter; leave `nil` on exit so the last hover stays sticky.
    func setHoverInstanceKey(_ key: String?, active: Bool, onActivateWhilePlaying: ((String) -> Void)? = nil) {
        if active, let key {
            onActivateWhilePlaying?(key)
        }
        hoverDebounceTask?.cancel()
        if !active {
            if isHoverActive {
                isHoverActive = false
            }
            return
        }
        hoverDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 30_000_000)
            guard !Task.isCancelled else { return }
            if let key, hoverInstanceKey != key {
                hoverInstanceKey = key
            }
            if !isHoverActive {
                isHoverActive = true
            }
        }
    }

    func clear() {
        hoverDebounceTask?.cancel()
        hoverDebounceTask = nil
        hoverInstanceKey = nil
        isHoverActive = false
        clearMorph()
    }

    func pinToSelection(_ key: String?) {
        hoverDebounceTask?.cancel()
        hoverDebounceTask = nil
        hoverInstanceKey = key
        isHoverActive = false
        clearMorph()
    }

    func beginMorph(toward key: String) {
        morphTargetKey = key
        isMorphing = true
    }

    func clearMorph() {
        isMorphing = false
        morphTargetKey = nil
        glyphBridge.unlockWidth()
    }
}

/// Direct pipe from slideshow → `CATextLayer`, bypassing SwiftUI invalidation.
@MainActor
final class PreviewGlyphBridge {
    weak var canvas: FontPreviewGlyphNSView?
    /// Builds an NSFont for arbitrary variation coords (uncached during morph).
    var makeFont: (([String: Double]) -> NSFont?)?

    func applyCoords(_ coords: [String: Double]) {
        guard let canvas, let font = makeFont?(coords) else { return }
        canvas.applyVariationFont(font, lockWidth: true)
    }

    func prepareMorphWidth(from fromCoords: [String: Double], to toCoords: [String: Double], sample: String) {
        guard let canvas else { return }
        let fromFont = makeFont?(fromCoords)
        let toFont = makeFont?(toCoords)
        let fromWidth = fromFont.map { sampleSize(sample, font: $0).width } ?? 0
        let toWidth = toFont.map { sampleSize(sample, font: $0).width } ?? 0
        let height = max(
            fromFont.map { sampleSize(sample, font: $0).height } ?? 0,
            toFont.map { sampleSize(sample, font: $0).height } ?? 0
        )
        canvas.lockContentSize(
            width: max(fromWidth, toWidth, 1),
            height: max(height, 1)
        )
    }

    func unlockWidth() {
        canvas?.unlockContentSize()
    }

    private func sampleSize(_ text: String, font: NSFont) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        let height = max(size.height, font.ascender - font.descender + font.leading)
        return CGSize(width: max(size.width.rounded(.up), 1), height: height)
    }
}
