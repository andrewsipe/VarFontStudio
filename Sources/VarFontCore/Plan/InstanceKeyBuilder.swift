import Foundation

/// Stable string keys for instance coordinates (`tag:value|tag:value`).
public enum InstanceKeyBuilder {
    /// Sorted axis tags joined as `tag:value|tag:value` (OpenType axis tag order).
    public static func makeKey(coords: [String: Double]) -> String {
        coords.keys.sorted().map { tag in
            let value = coords[tag] ?? 0
            return "\(tag):\(formatValue(value))"
        }.joined(separator: "|")
    }

    public static func parseKey(_ key: String) -> [String: Double] {
        var coords: [String: Double] = [:]
        for part in key.split(separator: "|") {
            let pieces = part.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            let tag = String(pieces[0])
            coords[tag] = Double(pieces[1]) ?? 0
        }
        return coords
    }

    private static func formatValue(_ value: Double) -> String {
        AxisCoordinateFormat.format(value)
    }
}
