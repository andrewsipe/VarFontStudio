import Foundation

/// OpenType-aligned slope ownership for `ital` / `slnt`.
///
/// Common path: one axis owns slope (usually fvar `slnt`); the sibling is passive
/// (STAT-only / pinned neutrals) — kept for STAT fidelity, out of naming, no nag.
/// Rare path: both meaningfully active → dual-owner.
/// Non-binary `ital` (angle on the wrong tag) is guided separately, not forbidden.
public enum SlopeAxisPolicy {
    public enum Participation: Equatable, Sendable {
        case absent
        /// STAT-only or pinned with only neutral / elided slope names.
        case passive
        /// Instance-role with more than one meaningful coordinate (or binary ital 0↔1 range).
        case active
        /// `ital` carrying degree-like values (e.g. pinned −12) — uncommon, not illegal.
        case nonBinaryItal
    }

    public enum Ownership: Equatable, Sendable {
        case none
        case slntOwns
        case italOwns
        case dual
        /// Non-binary ital acting as a slope naming axis (no active slnt).
        case italAsSlope
    }

    /// Import Review choice when one slope axis owns naming and the sibling is passive.
    public enum ImportChoice: String, Equatable, Sendable, CaseIterable {
        /// Keep passive axis in STAT; exclude from composed names (recommended).
        case keepSTATOutOfNaming
        /// Remove the passive axis from the project (omitted on export).
        case omitFromExport
        /// Force the passive axis into the naming order despite ownership.
        case includeInNaming
    }

    public struct ImportPrompt: Equatable, Sendable {
        public var ownership: Ownership
        public var ownerTag: String
        public var passiveTag: String
        public var recommended: ImportChoice
        public var title: String
        public var detail: String

        public init(
            ownership: Ownership,
            ownerTag: String,
            passiveTag: String,
            recommended: ImportChoice = .keepSTATOutOfNaming,
            title: String,
            detail: String
        ) {
            self.ownership = ownership
            self.ownerTag = ownerTag
            self.passiveTag = passiveTag
            self.recommended = recommended
            self.title = title
            self.detail = detail
        }
    }

    public struct Decision: Equatable, Sendable {
        public var ownership: Ownership
        public var slnt: Participation
        public var ital: Participation

        public init(ownership: Ownership, slnt: Participation, ital: Participation) {
            self.ownership = ownership
            self.slnt = slnt
            self.ital = ital
        }

        /// Tags that should not participate in composed names under this decision.
        public var namingTagsToExclude: Set<String> {
            switch ownership {
            case .slntOwns:
                return ital == .absent ? [] : ["ital"]
            case .italOwns:
                return slnt == .passive ? ["slnt"] : []
            case .italAsSlope:
                return slnt == .passive ? ["slnt"] : []
            case .dual, .none:
                return []
            }
        }

        /// Registration / Format 3 ital chores are noise when slnt already owns slope.
        public var suppressItalRegistrationIssues: Bool {
            ownership == .slntOwns && (ital == .passive || ital == .nonBinaryItal)
        }

        public var emitDualOwnerNotice: Bool {
            ownership == .dual
        }
    }

    public static func decide(axes: [AxisDefinition]) -> Decision {
        let slnt = participation(forTag: "slnt", axes: axes)
        let ital = participation(forTag: "ital", axes: axes)
        let ownership = ownership(slnt: slnt, ital: ital)
        return Decision(ownership: ownership, slnt: slnt, ital: ital)
    }

    public static func decide(font: FontDocument) -> Decision {
        decide(axes: font.axes)
    }

    /// True when this tag is kept on the font (STAT / registration) but excluded from composed names.
    public static func isExcludedFromNaming(
        tag: String,
        axes: [AxisDefinition],
        forceInclude: Set<String> = []
    ) -> Bool {
        guard !forceInclude.contains(tag) else { return false }
        return decide(axes: axes).namingTagsToExclude.contains(tag)
    }

    /// Short Axis Tree caption for a passive slope sibling (nil when the tag still names).
    public static func outOfNamingCaption(
        tag: String,
        axes: [AxisDefinition],
        forceInclude: Set<String> = []
    ) -> String? {
        guard !forceInclude.contains(tag) else { return nil }
        let decision = decide(axes: axes)
        guard decision.namingTagsToExclude.contains(tag) else { return nil }
        switch decision.ownership {
        case .slntOwns where tag == "ital":
            return "file label · naming uses slnt"
        case .italOwns where tag == "slnt", .italAsSlope where tag == "slnt":
            return "kept in file · naming uses ital"
        default:
            return "kept in file · out of naming"
        }
    }

    /// Import Review prompt when a passive slope sibling should be decided explicitly.
    public static func importPrompt(axes: [AxisDefinition]) -> ImportPrompt? {
        let decision = decide(axes: axes)
        switch decision.ownership {
        case .slntOwns where decision.ital == .passive || decision.ital == .nonBinaryItal:
            return ImportPrompt(
                ownership: .slntOwns,
                ownerTag: "slnt",
                passiveTag: "ital",
                recommended: .keepSTATOutOfNaming,
                title: "Slope naming",
                detail: "Choose how style names treat slant/italic when this file has both `slnt` (the slant you interpolate) and `ital` (a whole-file Roman/Italic label)."
            )
        case .italOwns where decision.slnt == .passive:
            return ImportPrompt(
                ownership: .italOwns,
                ownerTag: "ital",
                passiveTag: "slnt",
                recommended: .keepSTATOutOfNaming,
                title: "Slope naming",
                detail: "Choose how style names treat slant/italic when this file has both `ital` and an extra `slnt` axis."
            )
        default:
            return nil
        }
    }

    public static func effectiveNamingOrder(
        _ order: [String],
        axes: [AxisDefinition],
        forceInclude: Set<String> = []
    ) -> [String] {
        let excluded = decide(axes: axes).namingTagsToExclude.subtracting(forceInclude)
        guard !excluded.isEmpty else { return order }
        return order.filter { !excluded.contains($0) }
    }

    /// Merge project order with live axis tags, then drop passive slope siblings.
    public static func namingOrder(
        projectOrder: [String],
        axes: [AxisDefinition],
        forceInclude: Set<String> = []
    ) -> [String] {
        effectiveNamingOrder(
            NamingPolicy.mergedOrder(projectOrder: projectOrder, axisTags: axes.map(\.tag)),
            axes: axes,
            forceInclude: forceInclude
        )
    }

    /// Apply an Import Review slope choice to the font and naming policy.
    public static func applyImportChoice(
        _ choice: ImportChoice,
        prompt: ImportPrompt,
        to font: inout FontDocument,
        naming: inout NamingPolicy
    ) {
        let passive = prompt.passiveTag
        switch choice {
        case .keepSTATOutOfNaming:
            naming.slopeNamingIncludeTags.removeAll { $0 == passive }
            _ = applyPassiveItalElision(to: &font)
            naming.order = effectiveNamingOrder(
                naming.order,
                axes: font.axes,
                forceInclude: Set(naming.slopeNamingIncludeTags)
            )
            if var inferred = naming.inferredOrder {
                inferred = effectiveNamingOrder(
                    inferred,
                    axes: font.axes,
                    forceInclude: Set(naming.slopeNamingIncludeTags)
                )
                naming.inferredOrder = inferred
            }

        case .omitFromExport:
            naming.slopeNamingIncludeTags.removeAll { $0 == passive }
            font.axes.removeAll { $0.tag == passive }
            font.fileStatRegistration.removeValue(forKey: passive)
            font.statDesignAxisTags.removeAll { $0 == passive }
            naming.order.removeAll { $0 == passive }
            naming.inferredOrder = naming.inferredOrder?.filter { $0 != passive }

        case .includeInNaming:
            if !naming.slopeNamingIncludeTags.contains(passive) {
                naming.slopeNamingIncludeTags.append(passive)
            }
            if let axisIndex = font.axes.firstIndex(where: { $0.tag == passive }) {
                for stopIndex in font.axes[axisIndex].values.indices {
                    // Registration ital at Italic should participate when forced into names.
                    if RegistrationAxisSupport.isItalicLikeStopName(font.axes[axisIndex].values[stopIndex].name) {
                        font.axes[axisIndex].values[stopIndex].elidable = false
                    }
                }
            }
            if !naming.order.contains(passive) {
                naming.order.append(passive)
            }
            naming.order = namingOrder(
                projectOrder: naming.order,
                axes: font.axes,
                forceInclude: Set(naming.slopeNamingIncludeTags)
            )
        }
    }

    /// When `slnt` owns slope, mark registration `ital` stops elidable so they cannot
    /// silently re-enter names if a path re-merges axis tags into the chain.
    @discardableResult
    public static func applyPassiveItalElision(to font: inout FontDocument) -> Bool {
        let decision = decide(font: font)
        guard decision.ownership == .slntOwns,
              let axisIndex = font.axes.firstIndex(where: { $0.tag == "ital" }),
              font.axes[axisIndex].isDesignRecordOnly || font.axes[axisIndex].role == .statOnly
        else { return false }

        var changed = false
        for stopIndex in font.axes[axisIndex].values.indices {
            guard !font.axes[axisIndex].values[stopIndex].elidable else { continue }
            font.axes[axisIndex].values[stopIndex].elidable = true
            changed = true
        }
        return changed
    }

    public static func shouldEmitItalRegistrationWarning(
        code: String,
        axis: String?,
        decision: Decision
    ) -> Bool {
        guard decision.suppressItalRegistrationIssues else { return true }
        guard axis == "ital" || axis == nil else { return true }
        switch code {
        case "registration_mismatch",
             "registration_value_missing",
             "ital_value_name_mismatch",
             "ital_format1_upgrade":
            return false
        default:
            return true
        }
    }

    // MARK: - Classification

    public static func participation(forTag tag: String, axes: [AxisDefinition]) -> Participation {
        guard let axis = axes.first(where: { $0.tag == tag }) else { return .absent }

        if tag == "ital", RegistrationAxisSupport.isNonBinaryItalAxis(axis) {
            return .nonBinaryItal
        }

        if axis.isDesignRecordOnly {
            return .passive
        }

        if hasMeaningfulVariation(axis) {
            return .active
        }

        // Pinned / single-value fvar: passive when names are neutrals or elided.
        if isPassivePinnedSlope(axis) {
            return .passive
        }

        // Single named non-neutral stop on a non-instance role still counts passive for ownership.
        if axis.role != .instance {
            return .passive
        }

        return .passive
    }

    private static func ownership(slnt: Participation, ital: Participation) -> Ownership {
        // C2: non-binary ital beside active slnt → slnt owns; ital ignored for naming.
        if ital == .nonBinaryItal {
            if slnt == .active { return .slntOwns }
            return .italAsSlope
        }

        let slntActive = slnt == .active
        let italActive = ital == .active

        if slntActive && italActive { return .dual }
        if slntActive { return .slntOwns }
        if italActive { return .italOwns }
        if ital == .nonBinaryItal { return .italAsSlope }
        return .none
    }

    private static func hasMeaningfulVariation(_ axis: AxisDefinition) -> Bool {
        guard axis.role == .instance else { return false }
        let distinct = distinctStopValues(axis)
        guard distinct.count > 1 else { return false }

        if axis.tag == "ital" {
            // Binary 0↔1 (or near) is the expected active ital model.
            let has0 = distinct.contains { AxisCoordinate.valuesEqual($0, 0) }
            let has1 = distinct.contains { AxisCoordinate.valuesEqual($0, 1) }
            if has0 && has1 { return true }
            // Other multi-value ital on instance role still counts active (rare).
            return true
        }

        return true
    }

    private static func isPassivePinnedSlope(_ axis: AxisDefinition) -> Bool {
        let distinct = distinctStopValues(axis)
        if distinct.count > 1 { return false }
        let stops = axis.values
        guard !stops.isEmpty else { return true }
        return stops.allSatisfy { stop in
            stop.elidable || isSlopeNeutralName(stop.name, tag: axis.tag)
        }
    }

    private static func isSlopeNeutralName(_ name: String, tag: String) -> Bool {
        let lowered = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.isEmpty { return true }
        switch tag {
        case "ital":
            return RegistrationAxisSupport.isUprightLikeStopName(name)
                || RegistrationAxisSupport.isItalicLikeStopName(name)
        case "slnt":
            return lowered.contains("upright")
                || lowered.contains("oblique")
                || lowered.contains("slant")
                || RegistrationAxisSupport.isItalicLikeStopName(name)
                || RegistrationAxisSupport.isUprightLikeStopName(name)
        default:
            return false
        }
    }

    private static func distinctStopValues(_ axis: AxisDefinition) -> [Double] {
        var values: [Double] = []
        for stop in axis.values {
            let value = AxisCoordinateFormat.canonical(stop.value)
            if values.contains(where: { AxisCoordinate.valuesEqual($0, value) }) { continue }
            values.append(value)
        }
        if values.isEmpty, let min = axis.min, let max = axis.max,
           !AxisCoordinate.valuesEqual(min, max) {
            return [min, max]
        }
        return values
    }
}
