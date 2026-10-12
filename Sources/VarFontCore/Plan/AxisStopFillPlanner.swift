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
    /// Snap lattice that is not a uniform step — named width stops. Nil for step-based axes.
    public var snapLattice: [Double]?
    /// Caption phrase for the lattice, e.g. "named width steps".
    public var snapBasis: String?

    public init(
        axisTag: String,
        displayName: String,
        minValue: Double,
        maxValue: Double,
        defaultValue: Double?,
        countRange: ClosedRange<Int>,
        defaultCount: Int,
        typicalStep: Double?,
        snapLattice: [Double]? = nil,
        snapBasis: String? = nil
    ) {
        self.axisTag = axisTag
        self.displayName = displayName
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.countRange = countRange
        self.defaultCount = defaultCount
        self.typicalStep = typicalStep
        self.snapLattice = snapLattice
        self.snapBasis = snapBasis
    }
}

public struct AxisStopFillPlan: Sendable, Equatable {
    public var stops: [PlannedStop]
    public var step: Double
    public var snapping: Bool
    public var typicalStep: Double?
    public var snapBasis: String?
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
        let lattice = namedLattice(for: axis.tag, min: minV, max: maxV)
        let step = lattice == nil ? typicalStep(for: axis.tag) : nil
        let latticeTickCount = lattice.map { latticeTicks(min: minV, max: maxV, lattice: $0).count } ?? 0
        let defaultCount = lattice == nil
            ? suggestedCount(min: minV, max: maxV, typicalStep: step, within: countRange)
            : min(max(latticeTickCount, countRange.lowerBound), countRange.upperBound)

        return AxisStopFillOptions(
            axisTag: axis.tag,
            displayName: axis.displayName ?? axis.tag,
            minValue: minV,
            maxValue: maxV,
            defaultValue: axis.default,
            countRange: countRange,
            defaultCount: defaultCount,
            typicalStep: step,
            snapLattice: lattice,
            snapBasis: lattice == nil ? nil : "named width steps"
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
        let ticks = snapTicks(for: options)
        let snapFits = ticks.count >= max(minStopCount, clamped)
        // Width percentages are not an even scale. A width axis uses those positions
        // directly, so a count of 9 includes SemiExpanded instead of an unnamed
        // even step such as 787.5.
        let usesWidthScale = options.axisTag == "wdth" && options.snapLattice != nil && ticks.count >= clamped
        let snapping = (snap && snapFits) || usesWidthScale
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
        let stretchedNames = stretchedWidthNames(
            for: noms,
            axisTag: options.axisTag,
            min: options.minValue,
            max: options.maxValue
        )
        let stops = tiled.enumerated().map { index, row in
            AxisStopFillPlan.PlannedStop(
                value: row.nom,
                name: stretchedNames?[index] ?? fillName(
                    for: row.nom,
                    axisTag: options.axisTag,
                    axisDefault: options.defaultValue
                ),
                rangeMin: row.min,
                rangeMax: row.max,
                elidable: AxisStopNamingDefaults.inventedElidable(
                    for: options.axisTag,
                    atDefault: options.defaultValue.map { AxisCoordinate.valuesEqual(row.nom, $0) } ?? false
                ),
                statFormat: format
            )
        }
        return AxisStopFillPlan(
            stops: stops,
            step: step,
            snapping: snapping,
            typicalStep: options.typicalStep,
            snapBasis: options.snapBasis,
            onSuggestedCount: !snapping && clamped == options.defaultCount && (options.typicalStep != nil || options.snapLattice != nil),
            snapFits: snapFits,
            tickCount: ticks.count,
            statFormat: format
        )
    }

    public static func fillName(for value: Double, axisTag: String, axisDefault: Double?) -> String {
        if let named = namedStop(for: value, axisTag: axisTag) {
            return named
        }
        // Width's neutral name is the registered 100 stop, already in the width ladder.
        // A custom default (0 on a 0–900 axis) must not be labeled Normal.
        if axisTag != "wdth",
           let axisDefault, AxisCoordinate.valuesEqual(value, axisDefault),
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
        if plan.snapping, let basis = plan.snapBasis {
            return "Snapped to \(basis). \(count) noms."
        }
        if plan.snapping, let step = plan.typicalStep {
            return "Snapped to this axis’s \(AxisStopSuggestions.formatValue(step))-unit step. \(count) noms."
        }
        if plan.onSuggestedCount, let basis = plan.snapBasis {
            return "Suggested count \(count) from \(basis). \(count) noms."
        }
        if plan.onSuggestedCount, let step = plan.typicalStep {
            return "Suggested count \(count) from this axis’s \(AxisStopSuggestions.formatValue(step))-unit step. \(count) noms."
        }
        let stepText = AxisStopSuggestions.formatValue(plan.step)
        var text = "\(count) noms, evenly spaced (step \(stepText))."
        if !plan.snapFits, let basis = plan.snapBasis {
            let label = basis.prefix(1).uppercased() + basis.dropFirst()
            text += " \(label) only have \(plan.tickCount) ticks."
        } else if !plan.snapFits, let step = plan.typicalStep {
            text += " This axis’s \(AxisStopSuggestions.formatValue(step))-unit step only has \(plan.tickCount) ticks."
        }
        return text
    }

    // MARK: - Private

    private static let weightNames: [Int: String] = [
        100: "Thin",
        200: "Extralight",
        300: "Light",
        400: "Regular",
        500: "Medium",
        600: "Semibold",
        700: "Bold",
        800: "Extrabold",
        900: "Black",
    ]

    /// usWidthClass, as a percent of Normal. Compounds stay title case.
    /// Used as coordinates only when the axis range is already this percentage scale.
    private static let widthNames: [(percent: Double, name: String)] = [
        (50, "UltraCondensed"),
        (62.5, "ExtraCondensed"),
        (75, "Condensed"),
        (87.5, "SemiCondensed"),
        (100, "Normal"),
        (112.5, "SemiExpanded"),
        (125, "Expanded"),
        (150, "ExtraExpanded"),
        (200, "UltraExpanded"),
    ]

    /// True when min/max already sit on the usWidthClass percentage ladder.
    /// A 0–900 axis is a designer scale — Normal is the midpoint, and the other
    /// classes keep their percent-of-Normal spacing out to the ends.
    private static func usesRegisteredWidthScale(min minV: Double, max maxV: Double) -> Bool {
        minV + AxisCoordinate.tolerance >= 50 && maxV - AxisCoordinate.tolerance <= 200
    }

    private static func namedLattice(for tag: String, min minV: Double, max maxV: Double) -> [Double]? {
        guard tag == "wdth" else { return nil }
        if usesRegisteredWidthScale(min: minV, max: maxV) {
            return widthNames.map(\.percent)
        }
        return stretchedWidthSlots(min: minV, max: maxV).map(\.value)
    }

    /// usWidthClass percentages, with Normal at the axis midpoint.
    /// 50% of Normal maps to min, 200% of Normal maps to max, and the steps in
    /// between keep the spec's spacing on each side (even on the condensed side,
    /// widening on the expanded side).
    private static func stretchedWidthSlots(min minV: Double, max maxV: Double) -> [(value: Double, name: String)] {
        let normal = (minV + maxV) / 2
        let condensedSpan = normal - minV
        let expandedSpan = maxV - normal
        return widthNames.map { entry in
            let value: Double
            if entry.percent <= 100 {
                let fraction = (100 - entry.percent) / 50
                value = normal - fraction * condensedSpan
            } else {
                let fraction = (entry.percent - 100) / 100
                value = normal + fraction * expandedSpan
            }
            return (AxisCoordinateFormat.canonical(value), entry.name)
        }
    }

    /// Names for a width axis whose range is not the 25–200 percentage scale.
    /// Exact spectrum positions win; other stops take the nearest unused name.
    /// Nil when this axis should use registered coordinates instead.
    private static func stretchedWidthNames(
        for values: [Double],
        axisTag: String,
        min minV: Double,
        max maxV: Double
    ) -> [String]? {
        guard axisTag == "wdth", !usesRegisteredWidthScale(min: minV, max: maxV) else { return nil }
        let slots = stretchedWidthSlots(min: minV, max: maxV)
        var names = Array(repeating: "", count: values.count)
        var usedSlots = Set<Int>()

        for (valueIndex, value) in values.enumerated() {
            guard let slotIndex = slots.firstIndex(where: { AxisCoordinate.valuesEqual($0.value, value) }),
                  !usedSlots.contains(slotIndex) else { continue }
            names[valueIndex] = slots[slotIndex].name
            usedSlots.insert(slotIndex)
        }

        var pending: [(valueIndex: Int, slotIndex: Int, distance: Double)] = []
        for (valueIndex, value) in values.enumerated() where names[valueIndex].isEmpty {
            let slotIndex = slots.enumerated().min { lhs, rhs in
                abs(lhs.element.value - value) < abs(rhs.element.value - value)
            }?.offset ?? 0
            pending.append((valueIndex, slotIndex, abs(slots[slotIndex].value - value)))
        }
        pending.sort { $0.distance < $1.distance }
        for item in pending {
            if usedSlots.contains(item.slotIndex) {
                names[item.valueIndex] = AxisStopSuggestions.formatValue(values[item.valueIndex])
            } else {
                names[item.valueIndex] = slots[item.slotIndex].name
                usedSlots.insert(item.slotIndex)
            }
        }
        return names
    }

    private static func namedStop(for value: Double, axisTag: String) -> String? {
        switch axisTag {
        case "wght":
            let key = Int(value.rounded())
            guard abs(value - Double(key)) < AxisCoordinate.tolerance else { return nil }
            return weightNames[key]
        case "wdth":
            return widthNames.first { AxisCoordinate.valuesEqual($0.percent, value) }?.name
        default:
            return nil
        }
    }

    private static func snapTicks(for options: AxisStopFillOptions) -> [Double] {
        if let lattice = options.snapLattice {
            return latticeTicks(min: options.minValue, max: options.maxValue, lattice: lattice)
        }
        return typicalTicks(min: options.minValue, max: options.maxValue, step: options.typicalStep)
    }

    /// Named stops that fall inside the axis, with the axis ends kept so a fill still
    /// covers min and max when those ends are not themselves named widths.
    private static func latticeTicks(min minV: Double, max maxV: Double, lattice: [Double]) -> [Double] {
        var ticks = [AxisCoordinateFormat.canonical(minV)]
        for value in lattice {
            let canonical = AxisCoordinateFormat.canonical(value)
            guard canonical > minV + AxisCoordinate.tolerance,
                  canonical < maxV - AxisCoordinate.tolerance else { continue }
            if ticks.contains(where: { AxisCoordinate.valuesEqual($0, canonical) }) == false {
                ticks.append(canonical)
            }
        }
        let maxCanonical = AxisCoordinateFormat.canonical(maxV)
        if ticks.contains(where: { AxisCoordinate.valuesEqual($0, maxCanonical) }) == false {
            ticks.append(maxCanonical)
        }
        return ticks
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
        let ticks = snapTicks(for: options)
        let widthScale = options.axisTag == "wdth" && options.snapLattice != nil && ticks.count >= count
        if (snap || widthScale), ticks.count >= count {
            return evenOnTicks(count: count, ticks: ticks)
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
