import Foundation

public struct AxisStopFillOptions: Sendable, Equatable {
    public var axisTag: String
    public var displayName: String
    public var minValue: Double
    public var maxValue: Double
    public var defaultValue: Double?
    public var countRange: ClosedRange<Int>
    public var defaultCount: Int
    public var typicalStep: Double?

    public init(
        axisTag: String,
        displayName: String,
        minValue: Double,
        maxValue: Double,
        defaultValue: Double?,
        countRange: ClosedRange<Int>,
        defaultCount: Int,
        typicalStep: Double?
    ) {
        self.axisTag = axisTag
        self.displayName = displayName
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.countRange = countRange
        self.defaultCount = defaultCount
        self.typicalStep = typicalStep
    }
}

public struct AxisStopFillPlan: Sendable, Equatable {
    public var stops: [PlannedStop]
    public var step: Double
    public var snapping: Bool
    public var typicalStep: Double?
    public var onSuggestedCount: Bool
    public var snapFits: Bool
    public var tickCount: Int
    public var statFormat: Int

    public struct PlannedStop: Sendable, Equatable, Identifiable {
        public var value: Double
        public var name: String
        public var rangeMin: Double
        public var rangeMax: Double
        public var elidable: Bool
        public var statFormat: Int

        public var id: String {
            AxisStopSuggestions.formatValue(value)
        }

        public init(
            value: Double,
            name: String,
            rangeMin: Double,
            rangeMax: Double,
            elidable: Bool,
            statFormat: Int
        ) {
            self.value = value
            self.name = name
            self.rangeMin = rangeMin
            self.rangeMax = rangeMax
            self.elidable = elidable
            self.statFormat = statFormat
        }
    }
}

public enum AxisStopFillPlanner {
    public static let maxStopCount = 12
    public static let minStopCount = 2

    /// Below this span, evenly-spaced fills don't produce meaningful design choices
    /// (e.g. a boolean-style axis like `ital` running 0–1). The axis tree still supports adding
    /// single stops manually; quick fill just doesn't offer to subdivide a range this narrow.
    public static let minimumRangeForFill: Double = 2

    /// Typical lattice used only to preselect count (and as the optional Snap target).
    /// Not a grid every fill must land on.
    public static let typicalSteps: [String: Double] = [
        "wght": 100,
        "wdth": 25,
        "slnt": 1,
        "GRAD": 50,
    ]

    /// True when the axis is eligible for quick fill, regardless of whether it currently has stops.
    public static func supportsFill(_ axis: AxisDefinition) -> Bool {
        guard axis.role == .instance,
              !axis.isDesignRecordOnly,
              let minV = axis.min,
              let maxV = axis.max else { return false }
        return maxV - minV >= minimumRangeForFill
    }

    public static func typicalStep(for tag: String) -> Double? {
        typicalSteps[tag]
    }

    /// Format 2 when the axis already has a range stop; otherwise Format 1.
    public static func defaultFormat(for axis: AxisDefinition) -> Int {
        axis.values.contains(where: { $0.statFormat == 2 }) ? 2 : 1
    }

    public static func options(for axis: AxisDefinition) -> AxisStopFillOptions? {
        guard supportsFill(axis),
              let minV = axis.min,
              let maxV = axis.max else { return nil }

        let countRange = evenCountRange(min: minV, max: maxV)
        let step = typicalStep(for: axis.tag)
        let defaultCount = suggestedCount(min: minV, max: maxV, typicalStep: step, within: countRange)

        return AxisStopFillOptions(
            axisTag: axis.tag,
            displayName: axis.displayName ?? axis.tag,
            minValue: minV,
            maxValue: maxV,
            defaultValue: axis.default,
            countRange: countRange,
            defaultCount: defaultCount,
            typicalStep: step
        )
    }

    public static func suggestedCount(for axis: AxisDefinition) -> Int? {
        options(for: axis)?.defaultCount
    }

    /// Evenly spaced noms from min through max. Count is the contract: the result has
    /// `count` values whenever that many distinct coordinates fit the range.
    public static func values(for axis: AxisDefinition, count: Int, snap: Bool = false) -> [Double]? {
        guard let options = options(for: axis) else { return nil }
        let clamped = min(max(count, options.countRange.lowerBound), options.countRange.upperBound)
        let noms = noms(count: clamped, options: options, snap: snap)
        return noms.isEmpty ? nil : noms
    }

    public static func plan(
        for axis: AxisDefinition,
        count: Int,
        snap: Bool,
        statFormat: Int
    ) -> AxisStopFillPlan? {
        guard let options = options(for: axis) else { return nil }
        return plan(options: options, count: count, snap: snap, statFormat: statFormat)
    }

    public static func plan(
        options: AxisStopFillOptions,
        count: Int,
        snap: Bool,
        statFormat: Int
    ) -> AxisStopFillPlan {
        let clamped = min(max(count, options.countRange.lowerBound), options.countRange.upperBound)
        let ticks = typicalTicks(min: options.minValue, max: options.maxValue, step: options.typicalStep)
        let snapFits = ticks.count >= max(minStopCount, clamped)
        let snapping = snap && snapFits
        let noms = noms(count: clamped, options: options, snap: snapping)
        let format = statFormat == 2 ? 2 : 1
        let tiled = AxisStopRangeGeometry.tile(
            noms: noms,
            axisMin: options.minValue,
            axisMax: options.maxValue
        )
        let step: Double = {
            guard noms.count >= 2 else { return 0 }
            return (noms[noms.count - 1] - noms[0]) / Double(noms.count - 1)
        }()
        let suggested = suggestedCount(
            min: options.minValue,
            max: options.maxValue,
            typicalStep: options.typicalStep,
            within: options.countRange
        )
        let stops = tiled.map { row in
            AxisStopFillPlan.PlannedStop(
                value: row.nom,
                name: fillName(for: row.nom, axisTag: options.axisTag, axisDefault: options.defaultValue),
                rangeMin: row.min,
                rangeMax: row.max,
                elidable: options.defaultValue.map { AxisCoordinate.valuesEqual(row.nom, $0) } ?? false,
                statFormat: format
            )
        }
        return AxisStopFillPlan(
            stops: stops,
            step: step,
            snapping: snapping,
            typicalStep: options.typicalStep,
            onSuggestedCount: !snapping && clamped == suggested && options.typicalStep != nil,
            snapFits: snapFits,
            tickCount: ticks.count,
            statFormat: format
        )
    }

    public static func fillName(for value: Double, axisTag: String, axisDefault: Double?) -> String {
        if let named = namedStop(for: value, axisTag: axisTag) {
            return named
        }
        if let axisDefault, AxisCoordinate.valuesEqual(value, axisDefault),
           let elidable = AxisStopNamingDefaults.defaultElidableName(for: axisTag) {
            return elidable
        }
        return AxisStopSuggestions.formatValue(value)
    }

    public static func previewLabel(for values: [Double]) -> String {
        values.map { AxisStopSuggestions.formatValue($0) }.joined(separator: ", ")
    }

    public static func caption(for plan: AxisStopFillPlan) -> String {
        let count = plan.stops.count
        if plan.snapping, let step = plan.typicalStep {
            return "Snapped to this axis’s \(AxisStopSuggestions.formatValue(step))-unit step. \(count) noms."
        }
        if plan.onSuggestedCount, let step = plan.typicalStep {
            return "Suggested count \(count) from this axis’s \(AxisStopSuggestions.formatValue(step))-unit step. \(count) noms."
        }
        let stepText = AxisStopSuggestions.formatValue(plan.step)
        var text = "\(count) noms, evenly spaced (step \(stepText))."
        if !plan.snapFits, let step = plan.typicalStep {
            text += " This axis’s \(AxisStopSuggestions.formatValue(step))-unit step only has \(plan.tickCount) ticks."
        }
        return text
    }

    // MARK: - Private

    private static let weightNames: [Int: String] = [
        100: "Extrathin",
        200: "Thin",
        300: "Light",
        400: "Regular",
        500: "Medium",
        600: "Semibold",
        700: "Bold",
        800: "ExtraBold",
        900: "Black",
    ]

    private static func namedStop(for value: Double, axisTag: String) -> String? {
        let key = Int(value.rounded())
        guard abs(value - Double(key)) < AxisCoordinate.tolerance else { return nil }
        switch axisTag {
        case "wght":
            return weightNames[key]
        case "wdth" where key == 100:
            return "Normal"
        default:
            return nil
        }
    }

    private static func suggestedCount(
        min minV: Double,
        max maxV: Double,
        typicalStep: Double?,
        within range: ClosedRange<Int>
    ) -> Int {
        guard let step = typicalStep, step > 0 else {
            return min(6, range.upperBound)
        }
        let raw = Int(((maxV - minV) / step).rounded()) + 1
        return min(max(raw, range.lowerBound), range.upperBound)
    }

    private static func evenCountRange(min minV: Double, max maxV: Double) -> ClosedRange<Int> {
        let upper = min(maxStopCount, maxDistinctEvenCount(min: minV, max: maxV))
        return minStopCount...max(minStopCount, upper)
    }

    private static func maxDistinctEvenCount(min minV: Double, max maxV: Double) -> Int {
        var count = minStopCount
        while count < maxStopCount {
            let next = count + 1
            let current = evenNoms(min: minV, max: maxV, count: count)
            let candidate = evenNoms(min: minV, max: maxV, count: next)
            if current == candidate { break }
            count = next
        }
        return count
    }

    private static func noms(count: Int, options: AxisStopFillOptions, snap: Bool) -> [Double] {
        if snap {
            let ticks = typicalTicks(min: options.minValue, max: options.maxValue, step: options.typicalStep)
            if ticks.count >= count {
                return evenOnTicks(count: count, ticks: ticks)
            }
        }
        return evenNoms(min: options.minValue, max: options.maxValue, count: count)
    }

    static func typicalTicks(min minV: Double, max maxV: Double, step: Double?) -> [Double] {
        guard let step, step > 0, maxV > minV else { return [] }
        var ticks = [AxisCoordinateFormat.canonical(minV)]
        var cursor = (minV / step).rounded(.up) * step
        if AxisCoordinate.valuesEqual(cursor, minV) {
            cursor += step
        }
        while cursor < maxV - AxisCoordinate.tolerance {
            let value = AxisCoordinateFormat.canonical(cursor)
            if ticks.contains(where: { AxisCoordinate.valuesEqual($0, value) }) == false {
                ticks.append(value)
            }
            cursor += step
        }
        let maxCanonical = AxisCoordinateFormat.canonical(maxV)
        if ticks.contains(where: { AxisCoordinate.valuesEqual($0, maxCanonical) }) == false {
            ticks.append(maxCanonical)
        }
        return ticks
    }

    private static func evenNoms(min minV: Double, max maxV: Double, count: Int) -> [Double] {
        guard count >= 2, maxV > minV else {
            return count >= 1 ? [AxisCoordinateFormat.canonical(minV)] : []
        }
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            return AxisCoordinateFormat.canonical(minV + (maxV - minV) * fraction)
        }
    }

    private static func evenOnTicks(count: Int, ticks: [Double]) -> [Double] {
        guard !ticks.isEmpty else { return [] }
        if count >= ticks.count { return ticks }
        if count < 2 { return [ticks[0]] }
        var used = Set<Int>()
        var out: [Double] = []
        for index in 0..<count {
            var tickIndex = Int((Double(index) * Double(ticks.count - 1) / Double(count - 1)).rounded())
            while used.contains(tickIndex), tickIndex < ticks.count - 1 {
                tickIndex += 1
            }
            while used.contains(tickIndex), tickIndex > 0 {
                tickIndex -= 1
            }
            used.insert(tickIndex)
            out.append(ticks[tickIndex])
        }
        return out.sorted()
    }
}
