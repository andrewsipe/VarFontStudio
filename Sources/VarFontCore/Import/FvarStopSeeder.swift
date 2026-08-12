import Foundation

/// Seeds missing Format 1 STAT stops from fvar instance coordinates on import.
///
/// Quiet path: orthogonal, well-named catalogs apply Format 1 immediately.
/// Review path: hold combo-only / expansion-ambiguous stops and surface an Import Review.
public enum FvarStopSeeder {
    public enum StopClassification: String, Equatable, Sendable {
        case safeUnivariate
        case comboOnly
        case ambiguous
    }

    public enum StopDecision: Equatable, Sendable {
        case promote
        case comboOnly
        case ignore
    }

    public struct StopCandidate: Equatable, Sendable, Identifiable {
        public var id: String
        public var fontID: String
        public var axisTag: String
        public var axisLabel: String
        public var value: Double
        public var proposedName: String
        public var elidable: Bool
        public var classification: StopClassification
        public var recommendedDecision: StopDecision
        public var sampleInstanceNames: [String]

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            axisTag: String,
            axisLabel: String,
            value: Double,
            proposedName: String,
            elidable: Bool,
            classification: StopClassification,
            recommendedDecision: StopDecision,
            sampleInstanceNames: [String] = []
        ) {
            self.id = id
            self.fontID = fontID
            self.axisTag = axisTag
            self.axisLabel = axisLabel
            self.value = value
            self.proposedName = proposedName
            self.elidable = elidable
            self.classification = classification
            self.recommendedDecision = recommendedDecision
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public struct ExpansionCallout: Equatable, Sendable, Identifiable {
        public var id: String
        public var axisTags: [String]
        public var inventedCombinationCount: Int
        public var originalCustomLocationCount: Int
        /// Invented product cells with projected orthogonal STAT names.
        public var samples: [InventedSample]

        public init(
            id: String = UUID().uuidString,
            axisTags: [String],
            inventedCombinationCount: Int,
            originalCustomLocationCount: Int,
            samples: [InventedSample] = []
        ) {
            self.id = id
            self.axisTags = axisTags
            self.inventedCombinationCount = inventedCombinationCount
            self.originalCustomLocationCount = originalCustomLocationCount
            self.samples = samples
        }

        /// Flat labels for tests / legacy call sites: `"coords → Composed Name"`.
        public var sampleMissingLabels: [String] {
            samples.map { sample in
                if sample.composedName.isEmpty {
                    return sample.coordLabel
                }
                return "\(sample.coordLabel) → \(sample.composedName)"
            }
        }
    }

    public struct InventedSample: Equatable, Sendable {
        public var coordLabel: String
        public var composedName: String

        public init(coordLabel: String, composedName: String) {
            self.coordLabel = coordLabel
            self.composedName = composedName
        }
    }

    /// Enough grid state for the Import Review sheet to recompute expansion as stop
    /// decisions change (promote / combo-only / ignore).
    public struct ExpansionPreviewContext: Equatable, Sendable {
        public var axisTags: [String]
        public var axisLabels: [String: String]
        /// STAT / already-promoted values per custom axis (recommendation baseline).
        public var baseValuesByTag: [String: [Double]]
        public var heldValues: [HeldValue]
        public var originalCustomLocationKeys: [String]
        public var originalCustomLocationCount: Int
        /// Format 1 stop names available for NamingComposer (base + safe seeds).
        public var stopNameEntries: [StopNameEntry]
        public var namingOrder: [String]
        public var elidedFallback: String
        /// Defaults for non-custom instance axes (e.g. weight) so compose is stable.
        public var pinDefaults: [String: Double]

        public struct HeldValue: Equatable, Sendable {
            public var candidateID: String
            public var axisTag: String
            public var value: Double
            public var proposedName: String
            public var elidable: Bool

            public init(
                candidateID: String,
                axisTag: String,
                value: Double,
                proposedName: String,
                elidable: Bool = false
            ) {
                self.candidateID = candidateID
                self.axisTag = axisTag
                self.value = value
                self.proposedName = proposedName
                self.elidable = elidable
            }
        }

        public struct StopNameEntry: Equatable, Sendable {
            public var tag: String
            public var value: Double
            public var name: String
            public var elidable: Bool

            public init(tag: String, value: Double, name: String, elidable: Bool) {
                self.tag = tag
                self.value = value
                self.name = name
                self.elidable = elidable
            }
        }

        public init(
            axisTags: [String],
            axisLabels: [String: String],
            baseValuesByTag: [String: [Double]],
            heldValues: [HeldValue],
            originalCustomLocationKeys: [String],
            originalCustomLocationCount: Int,
            stopNameEntries: [StopNameEntry] = [],
            namingOrder: [String] = [],
            elidedFallback: String = "Regular",
            pinDefaults: [String: Double] = [:]
        ) {
            self.axisTags = axisTags
            self.axisLabels = axisLabels
            self.baseValuesByTag = baseValuesByTag
            self.heldValues = heldValues
            self.originalCustomLocationKeys = originalCustomLocationKeys
            self.originalCustomLocationCount = originalCustomLocationCount
            self.stopNameEntries = stopNameEntries
            self.namingOrder = namingOrder
            self.elidedFallback = elidedFallback
            self.pinDefaults = pinDefaults
        }
    }

    public struct NamingSparsityCallout: Equatable, Sendable {
        public var missingSubfamilyCount: Int
        public var sharedNameCollapseSize: Int
        public var sharedNameSamples: [String]
        public var message: String

        public init(
            missingSubfamilyCount: Int,
            sharedNameCollapseSize: Int,
            sharedNameSamples: [String],
            message: String
        ) {
            self.missingSubfamilyCount = missingSubfamilyCount
            self.sharedNameCollapseSize = sharedNameCollapseSize
            self.sharedNameSamples = sharedNameSamples
            self.message = message
        }

        public var isEmpty: Bool {
            missingSubfamilyCount == 0 && sharedNameCollapseSize < 2
        }
    }

    public struct OrthogonalityMetrics: Equatable, Sendable {
        public var originalInstanceCount: Int
        /// Grid size if recommendations are followed (combo-only held out of Format 1).
        public var projectedAnalyticCount: Int
        /// Grid size if every held candidate is promoted as Format 1.
        public var projectedIfAllPromoted: Int
        public var ratio: Double
        public var absoluteDelta: Int

        public init(
            originalInstanceCount: Int,
            projectedAnalyticCount: Int,
            projectedIfAllPromoted: Int? = nil
        ) {
            self.originalInstanceCount = originalInstanceCount
            self.projectedAnalyticCount = projectedAnalyticCount
            self.projectedIfAllPromoted = projectedIfAllPromoted ?? projectedAnalyticCount
            if originalInstanceCount > 0 {
                self.ratio = Double(projectedAnalyticCount) / Double(originalInstanceCount)
            } else {
                self.ratio = projectedAnalyticCount > 0 ? Double.infinity : 1
            }
            self.absoluteDelta = projectedAnalyticCount - originalInstanceCount
        }
    }

    public struct Report: Equatable, Sendable {
        public var seededStopCount: Int
        public var conflicts: [NameConflict]
        public var compoundSuggestions: [CompoundSuggestion]
        public var heldStopCandidates: [StopCandidate]
        public var expansionCallouts: [ExpansionCallout]
        public var expansionPreview: ExpansionPreviewContext?
        public var namingSparsity: NamingSparsityCallout?
        public var orthogonality: OrthogonalityMetrics?
        public var needsReview: Bool
        public var reviewReason: String

        public init(
            seededStopCount: Int = 0,
            conflicts: [NameConflict] = [],
            compoundSuggestions: [CompoundSuggestion] = [],
            heldStopCandidates: [StopCandidate] = [],
            expansionCallouts: [ExpansionCallout] = [],
            expansionPreview: ExpansionPreviewContext? = nil,
            namingSparsity: NamingSparsityCallout? = nil,
            orthogonality: OrthogonalityMetrics? = nil,
            needsReview: Bool = false,
            reviewReason: String = ""
        ) {
            self.seededStopCount = seededStopCount
            self.conflicts = conflicts
            self.compoundSuggestions = compoundSuggestions
            self.heldStopCandidates = heldStopCandidates
            self.expansionCallouts = expansionCallouts
            self.expansionPreview = expansionPreview
            self.namingSparsity = namingSparsity
            self.orthogonality = orthogonality
            self.needsReview = needsReview
            self.reviewReason = reviewReason
        }

        public var isEmpty: Bool {
            seededStopCount == 0
                && conflicts.isEmpty
                && compoundSuggestions.isEmpty
                && heldStopCandidates.isEmpty
                && expansionCallouts.isEmpty
                && (namingSparsity?.isEmpty ?? true)
                && !needsReview
        }
    }

    public struct CompoundSuggestion: Equatable, Sendable, Identifiable {
        public var id: String
        public var fontID: String
        public var name: String
        public var coords: [String: Double]
        /// Display labels per axis tag (stop name at that coordinate).
        public var legLabels: [String: String]
        public var coveredInstanceCount: Int
        public var sampleInstanceNames: [String]

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            name: String,
            coords: [String: Double],
            legLabels: [String: String],
            coveredInstanceCount: Int,
            sampleInstanceNames: [String] = []
        ) {
            self.id = id
            self.fontID = fontID
            self.name = name
            self.coords = coords
            self.legLabels = legLabels
            self.coveredInstanceCount = coveredInstanceCount
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public struct NameConflict: Equatable, Sendable, Identifiable {
        public var id: String
        public var fontID: String
        public var axisTag: String
        public var axisLabel: String
        public var value: Double
        public var existingStopID: String
        public var existingName: String
        public var fvarName: String
        public var sampleInstanceNames: [String]

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            axisTag: String,
            axisLabel: String,
            value: Double,
            existingStopID: String,
            existingName: String,
            fvarName: String,
            sampleInstanceNames: [String] = []
        ) {
            self.id = id
            self.fontID = fontID
            self.axisTag = axisTag
            self.axisLabel = axisLabel
            self.value = value
            self.existingStopID = existingStopID
            self.existingName = existingName
            self.fvarName = fvarName
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public enum Resolution: Equatable, Sendable {
        case keepSTAT
        case takeFvar
        case custom(String)
    }

    public struct ReviewDecisions: Equatable, Sendable {
        public var stopDecisions: [String: StopDecision]
        public var conflictResolutions: [String: Resolution]
        public var acceptedCompoundIDs: Set<String>
        public var dismissedCompoundIDs: Set<String>
        /// Optional Format 1 names when promoting held stops (candidate id → name).
        public var promotedStopNames: [String: String]
        /// When true, export whitelist is seeded to plan keys matching original fvar.
        public var keepOriginalInstancesOnly: Bool

        public init(
            stopDecisions: [String: StopDecision] = [:],
            conflictResolutions: [String: Resolution] = [:],
            acceptedCompoundIDs: Set<String> = [],
            dismissedCompoundIDs: Set<String> = [],
            promotedStopNames: [String: String] = [:],
            keepOriginalInstancesOnly: Bool = false
        ) {
            self.stopDecisions = stopDecisions
            self.conflictResolutions = conflictResolutions
            self.acceptedCompoundIDs = acceptedCompoundIDs
            self.dismissedCompoundIDs = dismissedCompoundIDs
            self.promotedStopNames = promotedStopNames
            self.keepOriginalInstancesOnly = keepOriginalInstancesOnly
        }
    }

    private static let expansionRatioThreshold = 1.35
    private static let expansionAbsoluteThreshold = 8

    /// Mutates `font.axes` in place. Returns seed counts, held candidates, and review gate.
    @discardableResult
    public static func seed(
        into font: inout FontDocument,
        analysis: FontAnalysis
    ) -> Report {
        let analysisByTag = Dictionary(uniqueKeysWithValues: analysis.axes.map { ($0.tag, $0) })
        let instanceAxes = font.axes.filter { $0.role == .instance && $0.hasFvarScale }
        let instanceTags = instanceAxes.map(\.tag)
        let customTags = instanceTags.filter { !CompoundStatNaming.standaloneNamingTags.contains($0) }

        var conflicts: [NameConflict] = []
        var candidates: [StopCandidate] = []

        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard axis.role == .instance, axis.hasFvarScale else { continue }

            let analyzed = analysisByTag[axis.tag]
            let observed = observedValues(for: axis.tag, analyzed: analyzed, analysis: analysis)
            guard !observed.isEmpty else { continue }

            for value in observed {
                let attributed = attributedName(
                    axisTag: axis.tag,
                    value: value,
                    instanceTags: instanceTags,
                    axes: font.axes,
                    analysis: analysis
                )

                if let existing = AxisCoordinate.matchingStop(in: font.axes[axisIndex].values, coordinate: value) {
                    if let fvarName = attributed?.name,
                       !namesEqual(existing.name, fvarName) {
                        conflicts.append(
                            NameConflict(
                                fontID: font.id,
                                axisTag: axis.tag,
                                axisLabel: axis.displayName ?? axis.tag,
                                value: value,
                                existingStopID: existing.id,
                                existingName: existing.name,
                                fvarName: fvarName,
                                sampleInstanceNames: attributed?.samples ?? []
                            )
                        )
                    }
                    continue
                }

                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(value, $0) } ?? false
                let name: String
                if let attributedName = attributed?.name {
                    name = attributedName
                } else if atDefault, let elidableName = AxisStopNamingDefaults.defaultElidableName(for: axis.tag) {
                    name = elidableName
                } else {
                    name = AxisCoordinateFormat.format(value)
                }

                let preliminary: StopClassification
                if atDefault || (attributed != nil && !isNumericOnly(name, value: value)) {
                    preliminary = .safeUnivariate
                } else {
                    preliminary = .ambiguous
                }

                candidates.append(
                    StopCandidate(
                        fontID: font.id,
                        axisTag: axis.tag,
                        axisLabel: axis.displayName ?? axis.tag,
                        value: AxisCoordinateFormat.canonical(value),
                        proposedName: name,
                        elidable: atDefault,
                        classification: preliminary,
                        recommendedDecision: preliminary == .safeUnivariate ? .promote : .promote,
                        sampleInstanceNames: attributed?.samples ?? []
                    )
                )
            }
        }

        // Temp font with all candidates applied — enables residue peeling + compound suggestions.
        var probeFont = font
        applyStopCandidates(candidates, to: &probeFont)
        let suggestions = suggestCompounds(
            font: probeFont,
            analysis: analysis,
            instanceTags: instanceTags
        ).filter { suggestion in
            !isUnreliableCompound(suggestion, analysis: analysis)
        }

        // Refine combo-only: value only with ≥2 custom axes off-default and in a Format 4 group.
        let compoundCoordKeys = Set(suggestions.flatMap { suggestion in
            suggestion.coords.map { coordKey(tag: $0.key, value: $0.value) }
        })
        candidates = candidates.map { candidate in
            var updated = candidate
            if candidate.classification != .safeUnivariate,
               isComboOnlyCoordinate(
                   tag: candidate.axisTag,
                   value: candidate.value,
                   customTags: customTags,
                   instanceTags: instanceTags,
                   axes: font.axes,
                   analysis: analysis
               ),
               compoundCoordKeys.contains(coordKey(tag: candidate.axisTag, value: candidate.value)) {
                updated.classification = .comboOnly
                updated.recommendedDecision = .comboOnly
            }
            return updated
        }

        let expansionBuilt = buildExpansionPreview(
            font: font,
            candidates: candidates,
            customTags: customTags,
            analysis: analysis
        )
        let expansion = expansionBuilt?.callout
        let expansionPreview = expansionBuilt?.context
        let sparsity = buildNamingSparsity(analysis: analysis)
        let orthogonality = buildOrthogonalityMetrics(
            font: font,
            candidates: candidates,
            instanceTags: instanceTags,
            analysis: analysis
        )

        let reasons = reviewReasons(
            candidates: candidates,
            expansion: expansion,
            suggestions: suggestions,
            conflicts: conflicts,
            sparsity: sparsity,
            orthogonality: orthogonality
        )
        let needsReview = !reasons.isEmpty

        var seededStopCount = 0
        var held: [StopCandidate] = []

        if !needsReview {
            seededStopCount = applyStopCandidates(candidates, to: &font)
            return Report(
                seededStopCount: seededStopCount,
                conflicts: conflicts,
                compoundSuggestions: suggestions,
                heldStopCandidates: [],
                expansionCallouts: [],
                expansionPreview: nil,
                namingSparsity: sparsity.isEmpty ? nil : sparsity,
                orthogonality: orthogonality,
                needsReview: false,
                reviewReason: ""
            )
        }

        // Coord entanglement: apply safe only; hold combo-only + expansion-driving ambiguous.
        // Naming-sparsity-alone: still promote all (value-as-name), sheet is awareness.
        let entanglement = reasons.contains { reason in
            reason.contains("combo-only")
                || reason.contains("expansion")
                || reason.contains("projected")
                || reason.contains("Format 4")
                || reason.contains("conflict")
        }

        if entanglement {
            let toApply = candidates.filter { $0.classification == .safeUnivariate }
            let toHold = candidates.filter { $0.classification != .safeUnivariate }
            seededStopCount = applyStopCandidates(toApply, to: &font)
            held = toHold
        } else {
            seededStopCount = applyStopCandidates(candidates, to: &font)
            held = []
        }

        // Preview context should only expose held values (safe already on font / in base).
        let previewForSheet: ExpansionPreviewContext? = {
            guard var context = expansionPreview else { return nil }
            let heldIDs = Set(held.map(\.id))
            context.heldValues = context.heldValues.filter { heldIDs.contains($0.candidateID) }
            return context
        }()

        return Report(
            seededStopCount: seededStopCount,
            conflicts: conflicts,
            compoundSuggestions: suggestions,
            heldStopCandidates: held,
            expansionCallouts: expansion.map { [$0] } ?? [],
            expansionPreview: previewForSheet,
            namingSparsity: sparsity.isEmpty ? nil : sparsity,
            orthogonality: orthogonality,
            needsReview: true,
            reviewReason: reasons.joined(separator: " · ")
        )
    }

    public static func apply(
        resolution: Resolution,
        conflict: NameConflict,
        to font: inout FontDocument
    ) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == conflict.axisTag }),
              let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == conflict.existingStopID })
        else { return }

        switch resolution {
        case .keepSTAT:
            break
        case .takeFvar:
            font.axes[axisIndex].values[stopIndex].name = conflict.fvarName
        case .custom(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            font.axes[axisIndex].values[stopIndex].name = trimmed
        }
    }

    /// Applies Import Review decisions: held stops, conflicts, and accepted Format 4 compounds.
    @discardableResult
    public static func apply(
        reviewDecisions decisions: ReviewDecisions,
        report: Report,
        to font: inout FontDocument
    ) -> [CompoundSuggestion] {
        for conflict in report.conflicts {
            guard let resolution = decisions.conflictResolutions[conflict.id] else { continue }
            apply(resolution: resolution, conflict: conflict, to: &font)
        }

        let toPromote = report.heldStopCandidates.compactMap { candidate -> StopCandidate? in
            let decision = decisions.stopDecisions[candidate.id] ?? candidate.recommendedDecision
            guard decision == .promote else { return nil }
            var updated = candidate
            if let override = decisions.promotedStopNames[candidate.id] {
                let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    updated.proposedName = trimmed
                }
            }
            return updated
        }
        _ = applyStopCandidates(toPromote, to: &font)

        var accepted: [CompoundSuggestion] = []
        for suggestion in report.compoundSuggestions {
            if decisions.acceptedCompoundIDs.contains(suggestion.id) {
                if !font.compoundStatValues.contains(where: { coordsEqual($0.coords, suggestion.coords) }) {
                    var compound = CompoundStatValue(
                        id: "compound-\(UUID().uuidString.prefix(8))",
                        coords: suggestion.coords,
                        axisIndices: [],
                        axisValues: [],
                        name: suggestion.name,
                        elidable: false
                    )
                    CompoundStatCoordinateSync.syncIndicesAndValues(
                        compound: &compound,
                        designAxisOrder: font.axes
                    )
                    font.compoundStatValues.append(compound)
                }
                accepted.append(suggestion)
            }
        }

        return report.compoundSuggestions.filter { suggestion in
            !decisions.acceptedCompoundIDs.contains(suggestion.id)
                && !decisions.dismissedCompoundIDs.contains(suggestion.id)
        }
    }

    // MARK: - Apply helpers

    @discardableResult
    private static func applyStopCandidates(
        _ candidates: [StopCandidate],
        to font: inout FontDocument
    ) -> Int {
        var seeded = 0
        for candidate in candidates {
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == candidate.axisTag }) else {
                continue
            }
            if AxisCoordinate.matchingStop(in: font.axes[axisIndex].values, coordinate: candidate.value) != nil {
                continue
            }
            let stop = AxisValue(
                id: "\(candidate.axisTag)-fvar-\(UUID().uuidString.prefix(8))",
                value: candidate.value,
                name: candidate.proposedName,
                elidable: candidate.elidable,
                statFormat: 1
            )
            font.axes[axisIndex].values.append(stop)
            font.axes[axisIndex].values.sort { $0.value < $1.value }
            seeded += 1
        }
        return seeded
    }

    // MARK: - Observed values

    private static func observedValues(
        for tag: String,
        analyzed: FontAnalysis.AnalyzedAxis?,
        analysis: FontAnalysis
    ) -> [Double] {
        if let observed = analyzed?.fvarValuesObserved, !observed.isEmpty {
            return uniqueSorted(observed)
        }
        var values: [Double] = []
        for instance in analysis.instancesExisting {
            if let value = instance.coords[tag] {
                values.append(value)
            }
        }
        return uniqueSorted(values)
    }

    private static func uniqueSorted(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        for value in values.map(AxisCoordinateFormat.canonical).sorted() {
            if let last = result.last, AxisCoordinate.valuesEqual(last, value) { continue }
            result.append(value)
        }
        return result
    }

    // MARK: - Name attribution (univariate slice)

    private struct Attribution {
        var name: String
        var samples: [String]
    }

    /// Prefer instance names where every other instance-role axis sits at its fvar default.
    /// Peels known STAT stop tokens for those other axes; requires a single shared residue.
    private static func attributedName(
        axisTag: String,
        value: Double,
        instanceTags: [String],
        axes: [AxisDefinition],
        analysis: FontAnalysis
    ) -> Attribution? {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        let otherTags = instanceTags.filter { $0 != axisTag }

        let candidates = analysis.instancesExisting.filter { instance in
            guard let coord = instance.coords[axisTag],
                  AxisCoordinate.valuesEqual(coord, value) else { return false }
            for tag in otherTags {
                guard let other = axisByTag[tag], let defaultValue = other.default else { return false }
                let actual = instance.coords[tag] ?? defaultValue
                guard AxisCoordinate.valuesEqual(actual, defaultValue) else { return false }
            }
            return true
        }

        guard !candidates.isEmpty else { return nil }

        var residues: [String] = []
        var samples: [String] = []
        for instance in candidates {
            let composed = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !composed.isEmpty else { continue }
            if samples.count < 3 { samples.append(composed) }

            var tokens = composed.split(separator: " ").map(String.init)
            for tag in otherTags {
                guard let other = axisByTag[tag] else { continue }
                let actual = instance.coords[tag] ?? other.default ?? 0
                guard let stop = AxisCoordinate.matchingStop(in: other.values, coordinate: actual) else {
                    continue
                }
                let stopName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !stopName.isEmpty else { continue }
                tokens.removeAll { namesEqual($0, stopName) }
            }

            let residue = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !residue.isEmpty else { return nil }
            // Numeric-only residue is not a strong attribution.
            if residue == AxisCoordinateFormat.format(value) { return nil }
            residues.append(residue)
        }

        guard let first = residues.first else { return nil }
        guard residues.allSatisfy({ namesEqual($0, first) }) else { return nil }
        return Attribution(name: first, samples: samples)
    }

    private static func namesEqual(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private static func isNumericOnly(_ name: String, value: Double) -> Bool {
        namesEqual(name, AxisCoordinateFormat.format(value))
    }

    private static func coordKey(tag: String, value: Double) -> String {
        "\(tag)=\(AxisCoordinateFormat.format(AxisCoordinateFormat.canonical(value)))"
    }

    // MARK: - Classification helpers

    private static func isComboOnlyCoordinate(
        tag: String,
        value: Double,
        customTags: [String],
        instanceTags: [String],
        axes: [AxisDefinition],
        analysis: FontAnalysis
    ) -> Bool {
        guard customTags.contains(tag) else { return false }
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        let appearances = analysis.instancesExisting.filter { instance in
            guard let coord = instance.coords[tag],
                  AxisCoordinate.valuesEqual(coord, value) else { return false }
            return true
        }
        guard !appearances.isEmpty else { return false }

        return appearances.allSatisfy { instance in
            var offCustom = 0
            for customTag in customTags {
                guard let axis = axisByTag[customTag] else { continue }
                let actual = instance.coords[customTag] ?? axis.default ?? 0
                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(actual, $0) } ?? false
                if !atDefault { offCustom += 1 }
            }
            return offCustom >= 2
        }
    }

    private static func isUnreliableCompound(
        _ suggestion: CompoundSuggestion,
        analysis: FontAnalysis
    ) -> Bool {
        // Shared blank/collapsed names: if every covered sample shares one identical
        // composedName string across many distinct custom locations, skip.
        let samples = suggestion.sampleInstanceNames
        guard let head = samples.first, !head.isEmpty else { return false }
        let matching = analysis.instancesExisting.filter {
            namesEqual($0.composedName, head)
        }
        guard matching.count >= 3 else { return false }
        let customKeys = Set(matching.map { instance -> String in
            let filtered = instance.coords.filter { !CompoundStatNaming.standaloneNamingTags.contains($0.key) }
            return InstanceKeyBuilder.makeKey(coords: filtered)
        })
        return customKeys.count >= 3
    }

    /// Live Import Review preview: projected style-grid size under the current promote set.
    ///
    /// Mirrors `buildOrthogonalityMetrics`, but reads the font as it stands once safe stops
    /// have been seeded, so only still-held candidates need folding in. With every candidate
    /// left on its recommendation this reproduces `OrthogonalityMetrics.projectedAnalyticCount`.
    public static func projectedStyleCount(
        font: FontDocument,
        heldCandidates: [StopCandidate],
        decisions: [String: StopDecision]
    ) -> Int {
        var product = 1
        for axis in font.axes where axis.role == .instance && axis.hasFvarScale {
            var values = axis.values.map(\.value)
            for candidate in heldCandidates where candidate.axisTag == axis.tag {
                let decision = decisions[candidate.id] ?? candidate.recommendedDecision
                guard decision == .promote else { continue }
                values.append(candidate.value)
            }
            product *= max(uniqueSorted(values).count, 1)
            if product > 10_000 {
                return 10_000
            }
        }
        return product
    }

    /// Live Import Review preview: invent count under the current promote set.
    public static func previewExpansion(
        context: ExpansionPreviewContext,
        decisions: [String: StopDecision],
        recommended: [String: StopDecision],
        promotedNames: [String: String] = [:]
    ) -> ExpansionCallout? {
        var valuesByTag = context.baseValuesByTag
        var nameEntries = context.stopNameEntries
        for held in context.heldValues {
            let decision = decisions[held.candidateID] ?? recommended[held.candidateID] ?? .comboOnly
            guard decision == .promote else { continue }
            valuesByTag[held.axisTag, default: []].append(held.value)
            let override = promotedNames[held.candidateID]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = override.isEmpty ? held.proposedName : override
            nameEntries.append(
                .init(tag: held.axisTag, value: held.value, name: name, elidable: held.elidable)
            )
        }
        for tag in valuesByTag.keys {
            valuesByTag[tag] = uniqueSorted(valuesByTag[tag] ?? [])
        }
        return makeExpansionCallout(
            axisTags: context.axisTags,
            axisLabels: context.axisLabels,
            valuesByTag: valuesByTag,
            originalKeys: Set(context.originalCustomLocationKeys),
            originalCount: context.originalCustomLocationCount,
            stopNameEntries: nameEntries,
            namingOrder: context.namingOrder,
            elidedFallback: context.elidedFallback,
            pinDefaults: context.pinDefaults
        )
    }

    private static func buildExpansionPreview(
        font: FontDocument,
        candidates: [StopCandidate],
        customTags: [String],
        analysis: FontAnalysis
    ) -> (callout: ExpansionCallout, context: ExpansionPreviewContext)? {
        guard customTags.count >= 2 else { return nil }
        let instanceAxes = font.axes.filter { $0.role == .instance && $0.hasFvarScale }
        let instanceTags = instanceAxes.map(\.tag)
        let axisByTag = Dictionary(uniqueKeysWithValues: font.axes.map { ($0.tag, $0) })
        let axisLabels = Dictionary(uniqueKeysWithValues: customTags.map { tag in
            (tag, axisByTag[tag]?.displayName ?? tag)
        })

        // Recommendation gate projection: existing STAT + candidates recommended to promote.
        var recommendationValues: [String: [Double]] = [:]
        var heldValues: [ExpansionPreviewContext.HeldValue] = []
        var recommendationNames: [ExpansionPreviewContext.StopNameEntry] = []
        for axis in instanceAxes {
            for stop in axis.values {
                recommendationNames.append(
                    .init(tag: axis.tag, value: stop.value, name: stop.name, elidable: stop.elidable)
                )
            }
        }
        for tag in customTags {
            var values = axisByTag[tag]?.values.map(\.value) ?? []
            for candidate in candidates where candidate.axisTag == tag {
                if candidate.recommendedDecision == .promote {
                    values.append(candidate.value)
                    recommendationNames.append(
                        .init(
                            tag: tag,
                            value: candidate.value,
                            name: candidate.proposedName,
                            elidable: candidate.elidable
                        )
                    )
                }
                if candidate.classification != .safeUnivariate {
                    heldValues.append(
                        .init(
                            candidateID: candidate.id,
                            axisTag: tag,
                            value: candidate.value,
                            proposedName: candidate.proposedName,
                            elidable: candidate.elidable
                        )
                    )
                }
            }
            recommendationValues[tag] = uniqueSorted(values)
        }

        let originalKeys: [String] = analysis.instancesExisting.map { instance in
            var coords: [String: Double] = [:]
            for tag in customTags {
                if let value = instance.coords[tag] {
                    coords[tag] = AxisCoordinateFormat.canonical(value)
                }
            }
            return InstanceKeyBuilder.makeKey(coords: coords)
        }
        let originalSet = Set(originalKeys)

        var pinDefaults: [String: Double] = [:]
        for axis in instanceAxes where !customTags.contains(axis.tag) {
            if let def = axis.default {
                pinDefaults[axis.tag] = def
            } else if let elidable = axis.values.first(where: \.elidable) {
                pinDefaults[axis.tag] = elidable.value
            } else if let first = axis.values.first {
                pinDefaults[axis.tag] = first.value
            }
        }

        let namingOrder = instanceTags
        let callout = makeExpansionCallout(
            axisTags: customTags,
            axisLabels: axisLabels,
            valuesByTag: recommendationValues,
            originalKeys: originalSet,
            originalCount: originalSet.count,
            stopNameEntries: recommendationNames,
            namingOrder: namingOrder,
            elidedFallback: "Regular",
            pinDefaults: pinDefaults
        )

        // Live sheet base: existing STAT + safe univariate (applied before the sheet).
        var liveBase: [String: [Double]] = [:]
        var liveNames: [ExpansionPreviewContext.StopNameEntry] = []
        for axis in instanceAxes {
            for stop in axis.values {
                liveNames.append(
                    .init(tag: axis.tag, value: stop.value, name: stop.name, elidable: stop.elidable)
                )
            }
        }
        for tag in customTags {
            liveBase[tag] = axisByTag[tag]?.values.map(\.value) ?? []
        }
        for candidate in candidates where candidate.classification == .safeUnivariate {
            liveBase[candidate.axisTag, default: []].append(candidate.value)
            liveNames.append(
                .init(
                    tag: candidate.axisTag,
                    value: candidate.value,
                    name: candidate.proposedName,
                    elidable: candidate.elidable
                )
            )
        }
        for tag in liveBase.keys {
            liveBase[tag] = uniqueSorted(liveBase[tag] ?? [])
        }

        let context = ExpansionPreviewContext(
            axisTags: customTags,
            axisLabels: axisLabels,
            baseValuesByTag: liveBase,
            heldValues: heldValues,
            originalCustomLocationKeys: Array(originalSet),
            originalCustomLocationCount: originalSet.count,
            stopNameEntries: liveNames,
            namingOrder: namingOrder,
            elidedFallback: "Regular",
            pinDefaults: pinDefaults
        )

        if let callout {
            return (callout, context)
        }
        if let promoted = makeExpansionCallout(
            axisTags: customTags,
            axisLabels: axisLabels,
            valuesByTag: {
                var all = liveBase
                for held in heldValues {
                    all[held.axisTag, default: []].append(held.value)
                }
                for tag in all.keys { all[tag] = uniqueSorted(all[tag] ?? []) }
                return all
            }(),
            originalKeys: originalSet,
            originalCount: originalSet.count,
            stopNameEntries: liveNames + heldValues.map {
                .init(tag: $0.axisTag, value: $0.value, name: $0.proposedName, elidable: $0.elidable)
            },
            namingOrder: namingOrder,
            elidedFallback: "Regular",
            pinDefaults: pinDefaults
        ) {
            return (promoted, context)
        }
        return nil
    }

    private static func makeExpansionCallout(
        axisTags: [String],
        axisLabels: [String: String],
        valuesByTag: [String: [Double]],
        originalKeys: Set<String>,
        originalCount: Int,
        stopNameEntries: [ExpansionPreviewContext.StopNameEntry] = [],
        namingOrder: [String] = [],
        elidedFallback: String = "Regular",
        pinDefaults: [String: Double] = [:]
    ) -> ExpansionCallout? {
        guard axisTags.count >= 2,
              axisTags.allSatisfy({ !(valuesByTag[$0] ?? []).isEmpty }) else { return nil }

        let orderedTags = axisTags.filter { valuesByTag[$0] != nil }
        var products: [[String: Double]] = [[:]]
        for tag in orderedTags {
            let values = valuesByTag[tag] ?? []
            var next: [[String: Double]] = []
            for prefix in products {
                for value in values {
                    var copy = prefix
                    copy[tag] = value
                    next.append(copy)
                }
            }
            products = next
            if products.count > 500 { break }
        }

        let composeAxes = composeAxesForPreview(
            tags: Set(orderedTags).union(pinDefaults.keys),
            stopNameEntries: stopNameEntries,
            axisLabels: axisLabels
        )
        let naming = NamingPolicy(
            order: namingOrder.isEmpty ? orderedTags : namingOrder,
            elidedFallback: elidedFallback
        )

        var samples: [InventedSample] = []
        var invented = 0
        for product in products {
            let key = InstanceKeyBuilder.makeKey(coords: product)
            if originalKeys.contains(key) { continue }
            invented += 1
            let coordLabel = orderedTags.compactMap { tag -> String? in
                guard let value = product[tag] else { return nil }
                let name = axisLabels[tag] ?? tag
                return "\(name) \(AxisCoordinateFormat.format(value))"
            }.joined(separator: " × ")
            var coords = pinDefaults
            for (tag, value) in product {
                coords[tag] = value
            }
            let composed = NamingComposer.compose(
                coords: coords,
                axes: composeAxes,
                naming: naming
            ).name
            samples.append(InventedSample(coordLabel: coordLabel, composedName: composed))
        }

        guard invented > 0 else { return nil }
        return ExpansionCallout(
            axisTags: orderedTags,
            inventedCombinationCount: invented,
            originalCustomLocationCount: originalCount,
            samples: samples
        )
    }

    private static func composeAxesForPreview(
        tags: Set<String>,
        stopNameEntries: [ExpansionPreviewContext.StopNameEntry],
        axisLabels: [String: String]
    ) -> [AxisDefinition] {
        var byTag: [String: [AxisValue]] = [:]
        for entry in stopNameEntries where tags.contains(entry.tag) {
            let already = byTag[entry.tag]?.contains {
                AxisCoordinate.valuesEqual($0.value, entry.value)
            } ?? false
            if already { continue }
            byTag[entry.tag, default: []].append(
                AxisValue(
                    id: "\(entry.tag)-preview-\(byTag[entry.tag]?.count ?? 0)",
                    value: entry.value,
                    name: entry.name,
                    elidable: entry.elidable,
                    statFormat: 1
                )
            )
        }
        return tags.sorted().map { tag in
            let values = byTag[tag] ?? []
            let nums = values.map(\.value)
            return AxisDefinition(
                tag: tag,
                displayName: axisLabels[tag] ?? tag,
                min: nums.min() ?? 0,
                default: values.first(where: \.elidable)?.value ?? nums.first,
                max: nums.max() ?? 0,
                role: .instance,
                values: values
            )
        }
    }

    private static func buildNamingSparsity(
        analysis: FontAnalysis
    ) -> NamingSparsityCallout {
        let instances = analysis.instancesExisting
        let missing = instances.filter {
            $0.composedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count

        var byNameID: [Int: [String]] = [:]
        var byString: [String: [String]] = [:]
        for instance in instances {
            let name = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            if instance.subfamilyNameID > 0 {
                byNameID[instance.subfamilyNameID, default: []].append(instance.key)
            }
            if !name.isEmpty {
                byString[name.lowercased(), default: []].append(instance.key)
            }
        }

        let collapseByID = byNameID.values.map { Set($0).count }.max() ?? 0
        let collapseByString = byString.values.map { Set($0).count }.max() ?? 0
        let collapse = max(collapseByID, collapseByString)

        var samples: [String] = []
        if let shared = byString.first(where: { Set($0.value).count >= 2 }) {
            samples.append("“\(shared.key)” on \(Set(shared.value).count) locations")
        }

        let message: String
        if missing > 0 || collapse >= 2 {
            message = "Instance names are sparse or shared — stops may use values as names. Rename in the Axis Tree where needed."
        } else {
            message = ""
        }

        return NamingSparsityCallout(
            missingSubfamilyCount: missing,
            sharedNameCollapseSize: collapse,
            sharedNameSamples: samples,
            message: message
        )
    }

    private static func buildOrthogonalityMetrics(
        font: FontDocument,
        candidates: [StopCandidate],
        instanceTags: [String],
        analysis: FontAnalysis
    ) -> OrthogonalityMetrics {
        let axisByTag = Dictionary(uniqueKeysWithValues: font.axes.map { ($0.tag, $0) })

        func projected(includingAllHeld: Bool) -> Int {
            var product = 1
            for tag in instanceTags {
                var values = axisByTag[tag]?.values.map(\.value) ?? []
                for candidate in candidates where candidate.axisTag == tag {
                    if includingAllHeld {
                        values.append(candidate.value)
                    } else if candidate.recommendedDecision == .promote {
                        values.append(candidate.value)
                    }
                }
                let unique = uniqueSorted(values)
                product *= max(unique.count, 1)
                if product > 10_000 {
                    return 10_000
                }
            }
            return product
        }

        return OrthogonalityMetrics(
            originalInstanceCount: analysis.instancesExisting.count,
            projectedAnalyticCount: projected(includingAllHeld: false),
            projectedIfAllPromoted: projected(includingAllHeld: true)
        )
    }

    private static func reviewReasons(
        candidates: [StopCandidate],
        expansion: ExpansionCallout?,
        suggestions: [CompoundSuggestion],
        conflicts: [NameConflict],
        sparsity: NamingSparsityCallout,
        orthogonality: OrthogonalityMetrics
    ) -> [String] {
        var reasons: [String] = []
        if candidates.contains(where: { $0.classification == .comboOnly }) {
            reasons.append("combo-only coordinates")
        }
        if let expansion, expansion.inventedCombinationCount > 0 {
            reasons.append("expansion (\(expansion.inventedCombinationCount) new combinations)")
        }
        if !suggestions.isEmpty {
            reasons.append("Format 4 suggestions")
        }
        if !conflicts.isEmpty {
            reasons.append("name conflicts")
        }
        if orthogonality.ratio >= expansionRatioThreshold
            || orthogonality.absoluteDelta >= expansionAbsoluteThreshold {
            reasons.append(
                "projected grid \(orthogonality.projectedAnalyticCount) vs \(orthogonality.originalInstanceCount) original"
            )
        }
        if sparsity.missingSubfamilyCount > 0 || sparsity.sharedNameCollapseSize >= 2 {
            reasons.append("sparse or shared instance names")
        }
        return reasons
    }

    // MARK: - Format 4 suggestions

    /// After Format 1 seeding: find fvar names that only make sense as multi-axis combinations.
    /// Groups by residual name; compound legs are axes whose off-default values stay constant
    /// across that group (so weight drops out of DoubleRounded / FullRounded).
    private static func suggestCompounds(
        font: FontDocument,
        analysis: FontAnalysis,
        instanceTags: [String]
    ) -> [CompoundSuggestion] {
        let axisByTag = Dictionary(uniqueKeysWithValues: font.axes.map { ($0.tag, $0) })

        struct Candidate {
            var residue: String
            var offDefault: [String: Double]
            var sample: String
        }

        var candidates: [Candidate] = []
        for instance in analysis.instancesExisting {
            let composed = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !composed.isEmpty else { continue }

            var tokens = composed.split(separator: " ").map(String.init)
            var offDefault: [String: Double] = [:]

            for tag in instanceTags {
                guard let axis = axisByTag[tag] else { continue }
                let actual = instance.coords[tag] ?? axis.default ?? 0
                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(actual, $0) } ?? false
                if !atDefault {
                    offDefault[tag] = AxisCoordinateFormat.canonical(actual)
                }
                if let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: actual) {
                    let stopName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !stopName.isEmpty {
                        tokens.removeAll { namesEqual($0, stopName) }
                    }
                }
            }

            let residue = tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !residue.isEmpty, offDefault.count >= 2 else { continue }
            candidates.append(Candidate(residue: residue, offDefault: offDefault, sample: composed))
        }

        var groups: [String: [Candidate]] = [:]
        for candidate in candidates {
            groups[candidate.residue.lowercased(), default: []].append(candidate)
        }

        var suggestions: [CompoundSuggestion] = []
        for group in groups.values {
            guard let head = group.first else { continue }
            // Drop axes that name themselves via Format 1 (esp. weight). Weight often
            // looks "constant" when a residual name only exists at one weight class.
            let constantCoords = constantOffDefaultCoords(across: group.map(\.offDefault))
                .filter { !CompoundStatNaming.standaloneNamingTags.contains($0.key) }
            guard constantCoords.count >= 2 else { continue }
            if font.compoundStatValues.contains(where: { coordsEqual($0.coords, constantCoords) }) {
                continue
            }
            if suggestions.contains(where: { coordsEqual($0.coords, constantCoords) }) {
                continue
            }

            var legLabels: [String: String] = [:]
            for (tag, value) in constantCoords {
                if let axis = axisByTag[tag],
                   let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: value) {
                    let label = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    legLabels[tag] = label.isEmpty ? AxisCoordinateFormat.format(value) : label
                } else {
                    legLabels[tag] = AxisCoordinateFormat.format(value)
                }
            }

            var samples: [String] = []
            for candidate in group {
                if samples.count >= 3 { break }
                if !samples.contains(where: { namesEqual($0, candidate.sample) }) {
                    samples.append(candidate.sample)
                }
            }

            suggestions.append(
                CompoundSuggestion(
                    fontID: font.id,
                    name: head.residue,
                    coords: constantCoords,
                    legLabels: legLabels,
                    coveredInstanceCount: group.count,
                    sampleInstanceNames: samples
                )
            )
        }

        return suggestions.sorted {
            if $0.coveredInstanceCount != $1.coveredInstanceCount {
                return $0.coveredInstanceCount > $1.coveredInstanceCount
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func constantOffDefaultCoords(across locations: [[String: Double]]) -> [String: Double] {
        guard let first = locations.first else { return [:] }
        let tags = Set(locations.flatMap(\.keys))
        var constant: [String: Double] = [:]
        for tag in tags {
            let values = locations.compactMap { $0[tag] }
            guard values.count == locations.count,
                  let head = values.first,
                  values.allSatisfy({ AxisCoordinate.valuesEqual($0, head) })
            else { continue }
            constant[tag] = head
        }
        // Preserve axis-tree-ish order: first location's key order, then leftovers.
        let preferred = first.keys.filter { constant[$0] != nil }
        let leftovers = constant.keys.filter { !preferred.contains($0) }.sorted()
        var ordered: [String: Double] = [:]
        for tag in preferred + leftovers {
            ordered[tag] = constant[tag]
        }
        return ordered
    }

    private static func coordsEqual(_ lhs: [String: Double], _ rhs: [String: Double]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (tag, value) in lhs {
            guard let other = rhs[tag], AxisCoordinate.valuesEqual(value, other) else { return false }
        }
        return true
    }
}
