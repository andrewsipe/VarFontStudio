import Foundation

/// Canonical formatting for fvar/STAT axis coordinates.
public enum AxisCoordinateFormat {
    /// Rounds to two decimal places for stable keys and display.
    public static func canonical(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    public static func format(_ value: Double) -> String {
        let value = canonical(value)
        if value.rounded() == value {
            return String(Int(value))
        }
        var text = String(format: "%.2f", value)
        while text.last == "0" { text.removeLast() }
        if text.last == "." { text.removeLast() }
        return text
    }
}
