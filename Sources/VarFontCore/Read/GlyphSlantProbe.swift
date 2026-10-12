import CoreGraphics
import CoreText
import Foundation

/// Whether the default outlines lean, using H, I, and N.
/// Same stems FontFixer samples when `post.italicAngle` and the style flags are silent.
public enum GlyphSlantProbe {
    /// Degrees of lean before a stem counts as italic. Matches FontFixer's floor.
    public static let minimumDegrees = 2.0

    public static func looksItalic(_ font: CTFont) -> Bool {
        let samples = [UniChar(0x48), 0x49, 0x4E].compactMap { character -> Double? in
            guard let degrees = slantDegrees(font: font, character: character) else { return nil }
            return abs(degrees) >= minimumDegrees ? degrees : nil
        }
        guard !samples.isEmpty else { return false }
        let negative = samples.filter { $0 < 0 }
        let positive = samples.filter { $0 > 0 }
        let chosen: [Double]
        if negative.count > positive.count {
            chosen = negative
        } else if positive.count > negative.count {
            chosen = positive
        } else {
            chosen = samples
        }
        let sorted = chosen.sorted()
        return abs(sorted[sorted.count / 2]) >= minimumDegrees
    }

    /// Italic angle in degrees from outline points. Positive when the top sits to the right of the bottom.
    public static func slantDegrees(points: [CGPoint]) -> Double? {
        guard points.count >= 4 else { return nil }
        let ys = points.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max() else { return nil }
        let height = maxY - minY
        guard height > 1 else { return nil }
        let lowCut = minY + height * 0.25
        let highCut = maxY - height * 0.25
        let low = points.filter { $0.y <= lowCut }
        let high = points.filter { $0.y >= highCut }
        guard !low.isEmpty, !high.isEmpty else { return nil }
        let lowX = low.map(\.x).reduce(0, +) / CGFloat(low.count)
        let highX = high.map(\.x).reduce(0, +) / CGFloat(high.count)
        return Double(atan2(highX - lowX, height)) * 180 / .pi
    }

    private static func slantDegrees(font: CTFont, character: UniChar) -> Double? {
        var chars = [character]
        var glyph = CGGlyph()
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1), glyph != 0 else { return nil }
        guard let path = CTFontCreatePathForGlyph(font, glyph, nil) else { return nil }
        var points: [CGPoint] = []
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(element.pointee.points[0])
            case .addQuadCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
            case .addCurveToPoint:
                points.append(element.pointee.points[0])
                points.append(element.pointee.points[1])
                points.append(element.pointee.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return slantDegrees(points: points)
    }
}
