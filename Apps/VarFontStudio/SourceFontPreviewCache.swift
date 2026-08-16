import AppKit
import CoreText
import Foundation

/// Cached source-font descriptor for live glyph preview.
///
/// Loads once per font file (via the same temp-cache path as vfcommit), then
/// applies variation coordinates without re-reading the font. Varied `NSFont`
/// instances are cached by coordinates + size for the current base entry.
@MainActor
final class SourceFontPreviewCache {
    private struct Entry {
        let fontID: String
        let sourcePath: String
        let cachePath: String
        let descriptor: CTFontDescriptor
    }

    private struct VariedKey: Hashable {
        let coordsKey: String
        let size: Int
    }

    private var entry: Entry?
    private var variedFonts: [VariedKey: NSFont] = [:]

    func invalidate(fontID: String? = nil) {
        if let fontID {
            if entry?.fontID == fontID {
                entry = nil
                variedFonts.removeAll(keepingCapacity: true)
            }
        } else {
            entry = nil
            variedFonts.removeAll(keepingCapacity: true)
        }
    }

    /// Returns an `NSFont` at `size` with native fvar coordinates applied.
    /// Coordinates for axes absent from the source font are ignored.
    /// - Parameter cache: When false (slideshow frames), skip the varied-font cache.
    func nsFont(
        fontID: String,
        bookmark: Data?,
        sourcePath: String,
        coords: [String: Double],
        size: CGFloat,
        cache: Bool = true
    ) -> NSFont? {
        guard let descriptor = baseDescriptor(
            fontID: fontID,
            bookmark: bookmark,
            sourcePath: sourcePath
        ) else {
            return nil
        }

        let quantizedSize = Int((size * 100).rounded())
        let key = VariedKey(coordsKey: Self.coordsCacheKey(coords), size: quantizedSize)
        if cache, let cached = variedFonts[key] {
            return cached
        }

        let variation = variationDictionary(from: coords)
        let attributed: CTFontDescriptor
        if variation.count == 0 {
            attributed = descriptor
        } else {
            attributed = CTFontDescriptorCreateCopyWithAttributes(
                descriptor,
                [kCTFontVariationAttribute: variation] as CFDictionary
            )
        }

        guard let font = NSFont(descriptor: attributed as NSFontDescriptor, size: size) else {
            return nil
        }
        if cache {
            // Bound memory if the user scrubs many sizes / peeks many instances.
            if variedFonts.count > 64 {
                variedFonts.removeAll(keepingCapacity: true)
            }
            variedFonts[key] = font
        }
        return font
    }

    private func baseDescriptor(
        fontID: String,
        bookmark: Data?,
        sourcePath: String
    ) -> CTFontDescriptor? {
        if let entry,
           entry.fontID == fontID,
           entry.sourcePath == sourcePath,
           FileManager.default.fileExists(atPath: entry.cachePath) {
            return entry.descriptor
        }

        do {
            let cachePath = try SourceFontAccess.helperSourcePath(
                bookmark: bookmark,
                fallbackPath: sourcePath,
                fontID: fontID
            )
            let url = URL(fileURLWithPath: cachePath)
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let descriptor = descriptors.first else {
                entry = nil
                variedFonts.removeAll(keepingCapacity: true)
                return nil
            }
            entry = Entry(
                fontID: fontID,
                sourcePath: sourcePath,
                cachePath: cachePath,
                descriptor: descriptor
            )
            variedFonts.removeAll(keepingCapacity: true)
            return descriptor
        } catch {
            entry = nil
            variedFonts.removeAll(keepingCapacity: true)
            return nil
        }
    }

    private func variationDictionary(from coords: [String: Double]) -> NSDictionary {
        let result = NSMutableDictionary()
        for (tag, value) in coords {
            guard let axisID = fourCharCode(tag) else { continue }
            result[NSNumber(value: axisID)] = NSNumber(value: value)
        }
        return result
    }

    private static func coordsCacheKey(_ coords: [String: Double]) -> String {
        coords.keys.sorted().map { tag in
            let value = coords[tag] ?? 0
            return "\(tag)=\(String(format: "%.4f", value))"
        }.joined(separator: "|")
    }

    private func fourCharCode(_ tag: String) -> FourCharCode? {
        let bytes = Array(tag.utf8)
        guard bytes.count == 4 else { return nil }
        return (UInt32(bytes[0]) << 24)
            | (UInt32(bytes[1]) << 16)
            | (UInt32(bytes[2]) << 8)
            | UInt32(bytes[3])
    }
}
