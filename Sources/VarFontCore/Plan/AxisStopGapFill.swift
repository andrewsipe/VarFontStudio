import Foundation

/// Inserts missing stops on an inferred regular grid without touching existing stops.
///
/// Designed for the common “designer omitted the in-between CSS weights” case
/// (100, 300, 400, 500, 700, 900 → 200, 600, 800) without assuming every axis is
/// a clean 100-unit ladder. If the existing stops don’t look like a coarse regular
/// grid, this returns `nil` rather than inventing a fine mesh.
public enum AxisStopGapFill {
    /// Need enough points to tell a grid from two masters.
    public static let minimumExistingStops = 3
    /// Above this, the axis is too sparse/irregular to auto-fill.
    public static let maxAddedStops = 8
    /// Reject when the typical gap is more than this many inferred steps
    /// (e.g. opsz 8 / 14 / 36 has GCD 2 but a median gap of 14).
    public static let maxMedianGapSteps = 2.0

    public struct Proposal: Equatable, Sendable {
        public var values: [Double]
        public var step: Double
        /// Human-readable source for UI help — not a STAT field.
        public var source: String

        public init(values: [Double], step: Double, source: String) {
            self.values = values
            self.step = step
            self.source = source
        }

        public var previewLabel: String {
            values.map { AxisStopSuggestions.formatValue($0) }.joined(separator: ", ")
        }
    }

    public static func proposal(for axis: AxisDefinition) -> Proposal? {
        guard axis.role == .instance, !axis.isDesignRecordOnly else { return nil }

        let existing = deduplicatedSorted(axis.values.map(\.value))
        guard existing.count >= minimumExistingStops else { return nil }

        let gapUnits = zip(existing, existing.dropFirst()).map { upper, lower in
            millunits(upper) - millunits(lower)
        }
        guard let stepUnits = gcd(gapUnits), stepUnits > 0 else { return nil }

        let step = Double(stepUnits) / 100.0
        let gaps = zip(existing, existing.dropFirst()).map { $1 - $0 }
        let medianGap = median(gaps)
        guard medianGap / step <= maxMedianGapSteps + 1e-6 else { return nil }

        let first = millunits(existing[0])
        let last = millunits(existing[existing.count - 1])
        var missing: [Double] = []
        var cursor = first + stepUnits
        while cursor < last {
            let value = AxisCoordinateFormat.canonical(Double(cursor) / 100.0)
            if inAxisRange(value, axis: axis), !isTaken(value, existing: existing) {
                missing.append(value)
            }
            cursor += stepUnits
        }

        guard !missing.isEmpty, missing.count <= maxAddedStops else { return nil }

        return Proposal(
            values: missing,
            step: step,
            source: "Inferred \(AxisStopSuggestions.formatValue(step))-unit grid between existing stops"
        )
    }

    // MARK: - Private

    private static func millunits(_ value: Double) -> Int {
        Int((AxisCoordinateFormat.canonical(value) * 100).rounded())
    }

    private static func gcd(_ values: [Int]) -> Int? {
        guard let first = values.first else { return nil }
        return values.dropFirst().reduce(abs(first)) { gcd($0, abs($1)) }
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 {
            let remainder = a % b
            a = b
            b = remainder
        }
        return a
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        if count == 0 { return 0 }
        if count % 2 == 1 { return sorted[count / 2] }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }

    private static func isTaken(_ value: Double, existing: [Double]) -> Bool {
        existing.contains { AxisCoordinate.valuesEqual($0, value) }
    }

    private static func inAxisRange(_ value: Double, axis: AxisDefinition) -> Bool {
        if let minV = axis.min, value < minV - AxisCoordinate.tolerance { return false }
        if let maxV = axis.max, value > maxV + AxisCoordinate.tolerance { return false }
        return true
    }

    private static func deduplicatedSorted(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values {
            let canonical = AxisCoordinateFormat.canonical(value)
            if !result.contains(where: { AxisCoordinate.valuesEqual($0, canonical) }) {
                result.append(canonical)
            }
        }
        return result.sorted()
    }
}
