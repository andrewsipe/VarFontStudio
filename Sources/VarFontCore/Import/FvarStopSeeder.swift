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

    /// Per-coordinate disposition in Import Review. Stop and Combo are independent —
    /// both can be on (axis stop *and* Format 4 leg); Neither is both off.
    public struct StopDisposition: Equatable, Sendable {
        public var asStop: Bool
        public var asCombo: Bool

        public init(asStop: Bool = false, asCombo: Bool = false) {
            self.asStop = asStop
            self.asCombo = asCombo
        }

        public static let neither = StopDisposition(asStop: false, asCombo: false)
        public static let stop = StopDisposition(asStop: true, asCombo: false)
        public static let combo = StopDisposition(asStop: false, asCombo: true)
        public static let stopAndCombo = StopDisposition(asStop: true, asCombo: true)

        public var isNeither: Bool { !asStop && !asCombo }
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
        public var recommendedDisposition: StopDisposition
        public var sampleInstanceNames: [String]
        /// Peeled cluster name this stop belongs to, when clustering ran for its axis.
        public var clusterName: String?

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            axisTag: String,
            axisLabel: String,
            value: Double,
            proposedName: String,
            elidable: Bool,
            classification: StopClassification,
            recommendedDisposition: StopDisposition,
            sampleInstanceNames: [String] = [],
            clusterName: String? = nil
        ) {
            self.id = id
            self.fontID = fontID
            self.axisTag = axisTag
            self.axisLabel = axisLabel
            self.value = value
            self.proposedName = proposedName
            self.elidable = elidable
            self.classification = classification
            self.recommendedDisposition = recommendedDisposition
            self.sampleInstanceNames = sampleInstanceNames
            self.clusterName = clusterName
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
        /// Leading classification codes on fvar instance names (inform only — never writes stop.code).
        public var codedNaming: InstanceCodedNaming.Detection?
        public var orthogonality: OrthogonalityMetrics?
        /// Passive slope sibling (`ital`/`slnt`) for Import Review.
        public var slopeOwnership: SlopeAxisPolicy.ImportPrompt?
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
            codedNaming: InstanceCodedNaming.Detection? = nil,
            orthogonality: OrthogonalityMetrics? = nil,
            slopeOwnership: SlopeAxisPolicy.ImportPrompt? = nil,
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
            self.codedNaming = codedNaming
            self.orthogonality = orthogonality
            self.slopeOwnership = slopeOwnership
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
                && codedNaming == nil
                && slopeOwnership == nil
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
        /// True when the STAT stop’s raw name was blank — `existingName` is then the coordinate.
        public var existingNameWasEmpty: Bool
        /// True when the fvar-attributed name was blank — `fvarName` is then the coordinate.
        public var fvarNameWasEmpty: Bool
        public var sampleInstanceNames: [String]

        /// When true, another Format 1 stop on this axis already uses `existingName`.
        public var existingNameDuplicatedOnAxis: Bool

        public var recommendedResolution: Resolution {
            Self.recommendedResolution(
                axisTag: axisTag,
                existingName: existingName,
                fvarName: fvarName,
                existingNameWasEmpty: existingNameWasEmpty,
                fvarNameWasEmpty: fvarNameWasEmpty,
                existingNameDuplicatedOnAxis: existingNameDuplicatedOnAxis
            )
        }

        public static func recommendedResolution(
            axisTag: String,
            existingName: String,
            fvarName: String,
            existingNameWasEmpty: Bool,
            fvarNameWasEmpty: Bool,
            existingNameDuplicatedOnAxis: Bool = false
        ) -> Resolution {
            if existingNameWasEmpty && !fvarNameWasEmpty { return .takeFvar }
            if fvarNameWasEmpty && !existingNameWasEmpty { return .keepSTAT }

            let statBad = AxisStyleVocabulary.mismatchesAxis(existingName, tag: axisTag)
            let fvarOK = AxisStyleVocabulary.isCompatible(fvarName, withAxisTag: axisTag)
                && !AxisStyleVocabulary.mismatchesAxis(fvarName, tag: axisTag)
            if statBad && fvarOK { return .takeFvar }
            if statBad && !fvarNameWasEmpty { return .takeFvar }

            // Duplicate STAT labels (e.g. Condensed @ wdth 1 and 46) — prefer the fvar peel.
            if existingNameDuplicatedOnAxis && !fvarNameWasEmpty
                && !namesEqualStatic(existingName, fvarName) {
                return .takeFvar
            }

            return .keepSTAT
        }

        private static func namesEqualStatic(_ a: String, _ b: String) -> Bool {
            a.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(
                    b.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame
        }

        public init(
            id: String = UUID().uuidString,
            fontID: String,
            axisTag: String,
            axisLabel: String,
            value: Double,
            existingStopID: String,
            existingName: String,
            fvarName: String,
            existingNameWasEmpty: Bool = false,
            fvarNameWasEmpty: Bool = false,
            existingNameDuplicatedOnAxis: Bool = false,
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
            self.existingNameWasEmpty = existingNameWasEmpty
            self.fvarNameWasEmpty = fvarNameWasEmpty
            self.existingNameDuplicatedOnAxis = existingNameDuplicatedOnAxis
            self.sampleInstanceNames = sampleInstanceNames
        }
    }

    public enum Resolution: Equatable, Sendable {
        case keepSTAT
        case takeFvar
        case custom(String)
    }

    public struct ReviewDecisions: Equatable, Sendable {
        public var stopDispositions: [String: StopDisposition]
        public var conflictResolutions: [String: Resolution]
        public var acceptedCompoundIDs: Set<String>
        public var dismissedCompoundIDs: Set<String>
        /// Optional Format 1 names when promoting held stops (candidate id → name).
        public var promotedStopNames: [String: String]
        /// Optional Format 4 name overrides (suggestion id → name).
        public var compoundNames: [String: String]
        /// When true, export whitelist is seeded to plan keys matching original fvar.
        public var keepOriginalInstancesOnly: Bool
        /// Slope ownership choice when `report.slopeOwnership` is present.
        public var slopeOwnershipChoice: SlopeAxisPolicy.ImportChoice?

        public init(
            stopDispositions: [String: StopDisposition] = [:],
            conflictResolutions: [String: Resolution] = [:],
            acceptedCompoundIDs: Set<String> = [],
            dismissedCompoundIDs: Set<String> = [],
            promotedStopNames: [String: String] = [:],
            compoundNames: [String: String] = [:],
            keepOriginalInstancesOnly: Bool = false,
            slopeOwnershipChoice: SlopeAxisPolicy.ImportChoice? = nil
        ) {
            self.stopDispositions = stopDispositions
            self.conflictResolutions = conflictResolutions
            self.acceptedCompoundIDs = acceptedCompoundIDs
            self.dismissedCompoundIDs = dismissedCompoundIDs
            self.promotedStopNames = promotedStopNames
            self.compoundNames = compoundNames
            self.keepOriginalInstancesOnly = keepOriginalInstancesOnly
            self.slopeOwnershipChoice = slopeOwnershipChoice
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

        // Drop Format 1 STAT stops that aren't grounded in fvar — either outside the axis
        // range, or an entire ladder in a different coordinate space than the instances.
        // Import Review only decides *held* fvar candidates; without this, broken STAT
        // (e.g. Interchange's 37 wght stops named Poster/Title at design coords) stays on
        // the axis and explodes the orthogonal product regardless of review choices.
        pruneUngroundedFormat1Stops(on: &font, analysis: analysis)
        // Cross-axis vocabulary on a near-neighbor of a real stop (Wide@399 next to
        // Regular@398) — remove so the coord can be held as Neither instead of expanding
        // the orthogonal product.
        pruneMisattributedNearNeighborStops(on: &font)
        // Default-coordinate STAT labels that belong on another axis (slnt=0 "Condensed")
        // — rename to the axis neutral. These often have no fvar peel conflict because
        // upright instance names share no common residue.
        repairVocabularyMismatchedDefaultStops(on: &font)

        let codedNaming = InstanceCodedNaming.detect(instances: analysis.instancesExisting)
        let peelAnalysis = InstanceCodedNaming.peelAnalysis(analysis, detection: codedNaming)

        var conflicts: [NameConflict] = []
        var candidates: [StopCandidate] = []

        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard axis.role == .instance, axis.hasFvarScale else { continue }

            let analyzed = analysisByTag[axis.tag]
            let observed = observedValues(for: axis.tag, analyzed: analyzed, analysis: analysis)
            guard !observed.isEmpty else { continue }

            let duplicatedSTATNames = duplicatedStopNames(on: font.axes[axisIndex])

            for value in observed {
                let attributed = attributedName(
                    axisTag: axis.tag,
                    value: value,
                    instanceTags: instanceTags,
                    axes: font.axes,
                    analysis: peelAnalysis
                )

                if let existing = AxisCoordinate.matchingStop(in: font.axes[axisIndex].values, coordinate: value) {
                    if let fvarName = attributed?.name {
                        let existingTrimmed = existing.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let fvarTrimmed = fvarName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let existingEffective = effectiveConflictStopName(existing.name, value: value)
                        let fvarEffective = effectiveConflictStopName(fvarName, value: value)
                        if !namesEqual(existingEffective, fvarEffective) {
                            conflicts.append(
                                NameConflict(
                                    fontID: font.id,
                                    axisTag: axis.tag,
                                    axisLabel: axis.displayName ?? axis.tag,
                                    value: value,
                                    existingStopID: existing.id,
                                    existingName: existingEffective,
                                    fvarName: fvarEffective,
                                    existingNameWasEmpty: existingTrimmed.isEmpty,
                                    fvarNameWasEmpty: fvarTrimmed.isEmpty,
                                    existingNameDuplicatedOnAxis: duplicatedSTATNames.contains(
                                        existingTrimmed.lowercased()
                                    ),
                                    sampleInstanceNames: attributed?.samples ?? []
                                )
                            )
                        }
                    }
                    continue
                }

                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(value, $0) } ?? false
                var name: String
                if let attributedName = attributed?.name {
                    name = attributedName
                } else if atDefault, let elidableName = AxisStopNamingDefaults.defaultElidableName(for: axis.tag) {
                    name = elidableName
                } else {
                    name = AxisCoordinateFormat.format(value)
                }
                // Never seed a stop whose peeled name belongs on another axis.
                if AxisStyleVocabulary.mismatchesAxis(name, tag: axis.tag) {
                    name = AxisCoordinateFormat.format(value)
                }

                let nameIsNumeric = isNumericOnly(name, value: value)
                let preliminary: StopClassification
                if atDefault || (attributed != nil && !nameIsNumeric
                    && !AxisStyleVocabulary.mismatchesAxis(name, tag: axis.tag)) {
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
                        elidable: AxisStopNamingDefaults.inventedElidable(
                            for: axis.tag,
                            atDefault: atDefault
                        ),
                        classification: preliminary,
                        recommendedDisposition: .stop,
                        sampleInstanceNames: attributed?.samples ?? []
                    )
                )
            }
        }

        // Standalone axes (wght, opsz, ...) get named and classified by peeled style clusters
        // rather than per-coordinate: fixes both the "every ambiguous stop still recommends
        // Promote" gap and the "only the at-default slice gets a real name" limit of attributedName.
        let clusterResults = AxisStopClustering.classifyStandaloneAxes(
            instanceTags: instanceTags,
            analysis: peelAnalysis
        )
        let axisRangeByTag = Dictionary(uniqueKeysWithValues: font.axes.compactMap { axis -> (String, Double)? in
            guard let min = axis.min, let max = axis.max else { return nil }
            return (axis.tag, max - min)
        })
        if !clusterResults.isEmpty {
            candidates = candidates.map {
                applyClusterClassification($0, clusterResults: clusterResults, axisRanges: axisRangeByTag)
            }
        }
        candidates = candidates.map { sanitizeCandidateVocabulary($0) }

        // Temp font with all candidates applied — enables residue peeling + compound suggestions.
        var probeFont = font
        applyStopCandidates(candidates, to: &probeFont)
        var suggestions = suggestCompounds(
            font: probeFont,
            analysis: peelAnalysis,
            instanceTags: instanceTags
        ).filter { suggestion in
            !isUnreliableCompound(suggestion, analysis: peelAnalysis)
        }
        // Entangled standalone-axis coordinates (e.g. an opsz-compensated weight) don't fit the
        // generic residue-compound shape above — the "residue" IS the axis's own cluster name,
        // not leftover text — so they get named combinations directly from the cluster data.
        suggestions += entangledComboSuggestions(
            fontID: font.id,
            candidates: candidates,
            clusterResults: clusterResults,
            axisRanges: axisRangeByTag,
            instanceTags: instanceTags,
            axes: font.axes,
            analysis: peelAnalysis
        )

        // STAT Format 4 already in the file is settled — don't re-prompt Import Review.
        suggestions = suggestions.filter { suggestion in
            !font.compoundStatValues.contains(where: { coordsEqual($0.coords, suggestion.coords) })
        }
        // Dense Format 4 sets that recreate an orthogonal product are not entanglement —
        // drop them and demote related combo candidates to Neither (repair, don't expand).
        suggestions = suppressOrthogonalProductCompounds(
            suggestions: suggestions,
            candidates: &candidates,
            analysis: peelAnalysis
        )
        candidates = dropComboCandidatesCoveredByExistingCompounds(
            candidates,
            compounds: font.compoundStatValues
        )

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
                updated.recommendedDisposition = .combo
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
            analysis: analysis,
            compoundCoords: suggestions.map(\.coords)
        )
        let slopeOwnership = SlopeAxisPolicy.importPrompt(axes: font.axes)

        let reasons = reviewReasons(
            candidates: candidates,
            expansion: expansion,
            suggestions: suggestions,
            conflicts: conflicts,
            sparsity: sparsity,
            codedNaming: codedNaming,
            orthogonality: orthogonality,
            slopeOwnership: slopeOwnership
        )
        let needsReview = !reasons.isEmpty

        var seededStopCount = 0
        var held: [StopCandidate] = []

        if !needsReview {
            seededStopCount = applyStopCandidates(
                candidates.filter { $0.recommendedDisposition.asStop },
                to: &font
            )
            return Report(
                seededStopCount: seededStopCount,
                conflicts: conflicts,
                compoundSuggestions: suggestions,
                heldStopCandidates: [],
                expansionCallouts: [],
                expansionPreview: nil,
                namingSparsity: sparsity.isEmpty ? nil : sparsity,
                codedNaming: codedNaming,
                orthogonality: orthogonality,
                slopeOwnership: nil,
                needsReview: false,
                reviewReason: ""
            )
        }

        // Coord entanglement: apply safe only; hold combo-only + expansion-driving ambiguous.
        // Naming-sparsity / coded-naming alone: still promote all; sheet is awareness.
        let entanglement = reasons.contains { reason in
            reason.contains("combo-only")
                || reason.contains("expansion")
                || reason.contains("projected")
                || reason.contains("Format 4")
                || reason.contains("conflict")
        }

        if entanglement {
            // Only auto-apply coordinates that were already safe before clustering picks;
            // recommended stops that are still `.ambiguous` stay on the sheet.
            let toApply = candidates.filter {
                $0.classification == .safeUnivariate && $0.recommendedDisposition.asStop
            }
            let toHold = candidates.filter {
                !($0.classification == .safeUnivariate && $0.recommendedDisposition.asStop)
            }
            seededStopCount = applyStopCandidates(toApply, to: &font)
            held = toHold
        } else {
            seededStopCount = applyStopCandidates(
                candidates.filter { $0.recommendedDisposition.asStop },
                to: &font
            )
            held = candidates.filter { !$0.recommendedDisposition.asStop }
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
            codedNaming: codedNaming,
            orthogonality: orthogonality,
            slopeOwnership: slopeOwnership,
            needsReview: true,
            reviewReason: reasons.joined(separator: " · ")
        )
    }

    // MARK: - Standalone axis clustering (sheared ladders)

    /// Renames a candidate to its cluster's style name, and — only when that axis is actually
    /// entangled with a companion axis — rewrites its classification/disposition from the
    /// binary promote/combo-only cut. The cluster's nearest-to-median coordinate is the one
    /// that becomes a Format 1 stop; other members of a promotable cluster are recommended
    /// Neither (same style, accepted positional fuzz); members of a combo-only cluster stay
    /// Combo for Format 4.
    ///
    /// Near-neighbor twins (Bold@783 & Bold@810 on a 1…1000 axis) are forced onto the
    /// promote/Neither path even when the gap cut marked the cluster combo-only — that cut
    /// is meant for opsz shear, not off-by-a-few Regular/Bold drift.
    private static func applyClusterClassification(
        _ candidate: StopCandidate,
        clusterResults: [String: AxisStopClustering.AxisResult],
        axisRanges: [String: Double] = [:]
    ) -> StopCandidate {
        guard let axisResult = clusterResults[candidate.axisTag],
              let clusterName = axisResult.clusterName(for: candidate.value),
              !clusterName.isEmpty,
              let cluster = axisResult.cluster(named: clusterName)
        else {
            return candidate
        }

        var updated = candidate
        updated.clusterName = clusterName
        if !AxisStyleVocabulary.mismatchesAxis(clusterName, tag: candidate.axisTag) {
            updated.proposedName = clusterName
        }

        let canonical = clusterCanonicalValue(cluster)
        let isCanonical = AxisCoordinate.valuesEqual(candidate.value, canonical)
        let axisRange = axisRanges[candidate.axisTag] ?? 1000
        let positionalFuzz = cluster.values.count > 1
            && AxisStyleVocabulary.isPositionalFuzz(cluster, axisRange: axisRange)

        // Off-by-a-few twins share a peeled name (Regular@398/399). Always hold the
        // non-canonical coord as Neither — even when the axis has no opsz-style entanglement.
        if positionalFuzz {
            if isCanonical {
                updated.recommendedDisposition = .stop
            } else {
                updated.recommendedDisposition = .neither
                updated.classification = .ambiguous
            }
            return updated
        }

        guard axisResult.hasEntanglement else { return updated }

        let promoteCluster = axisResult.promoteNames.contains(clusterName)
        if promoteCluster {
            updated.recommendedDisposition = isCanonical ? .stop : .neither
        } else {
            updated.recommendedDisposition = .combo
        }
        // Held for review either way — this is a statistical pick, not a font-confirmed fact —
        // `.comboOnly` specifically marks the coordinates that still need a Format 4 combination.
        updated.classification = updated.recommendedDisposition.asCombo && !updated.recommendedDisposition.asStop
            ? .comboOnly
            : .ambiguous
        return updated
    }

    /// The cluster's own coordinate closest to its median — a real, observed value rather than
    /// an invented number, and more representative of the whole cluster than an axis-default
    /// anchor (which is often the single most-compensated member, not a typical one).
    private static func clusterCanonicalValue(_ cluster: AxisStopClustering.Cluster) -> Double {
        guard cluster.values.count > 1 else { return cluster.values.first ?? 0 }
        let sorted = cluster.values
        let mid = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return sorted.min(by: { abs($0 - median) < abs($1 - median) }) ?? median
    }

    /// Coordinates that already appear as a Format 4 leg in the source STAT are decided —
    /// keep them off the Format 1 stop list and out of Import Review.
    private static func dropComboCandidatesCoveredByExistingCompounds(
        _ candidates: [StopCandidate],
        compounds: [CompoundStatValue]
    ) -> [StopCandidate] {
        guard !compounds.isEmpty else { return candidates }
        return candidates.filter { candidate in
            let covered = compounds.contains { compound in
                guard let value = compound.coords[candidate.axisTag] else { return false }
                return AxisCoordinate.valuesEqual(value, candidate.value)
            }
            if covered, candidate.recommendedDisposition.asCombo || candidate.classification == .comboOnly {
                return false
            }
            return true
        }
    }

    /// One Format 4 suggestion per instance belonging to a combo-classified entangled cluster.
    /// Driven from cluster results (not only held candidates) so every opsz×weight pair for
    /// Extra Thin / Thin / Extra Light / Light lands in Styles — including coordinates that
    /// share a value with a differently-named Character-Set add-on.
    private static func entangledComboSuggestions(
        fontID: String,
        candidates: [StopCandidate],
        clusterResults: [String: AxisStopClustering.AxisResult],
        axisRanges: [String: Double] = [:],
        instanceTags: [String],
        axes: [AxisDefinition],
        analysis: FontAnalysis
    ) -> [CompoundSuggestion] {
        let axisByTag = Dictionary(uniqueKeysWithValues: axes.map { ($0.tag, $0) })
        // Cluster names whose gap cut wants Format 4 (not a Format 1 stop).
        // Positional-fuzz clusters are treated as promoted even when the gap cut held them —
        // otherwise Bold@783/810 drift emits a full orthogonal Format 4 product.
        var comboClustersByTag: [String: Set<String>] = [:]
        for (tag, result) in clusterResults where result.hasEntanglement {
            let range = axisRanges[tag] ?? 1000
            var promote = result.promoteNames
            for cluster in result.clusters where AxisStyleVocabulary.isPositionalFuzz(cluster, axisRange: range) {
                promote.insert(cluster.name)
            }
            let comboNames = Set(result.clusters.map(\.name)).subtracting(promote)
            if !comboNames.isEmpty {
                comboClustersByTag[tag] = comboNames
            }
        }
        // Also honor candidates explicitly marked combo (covers custom-axis refine path).
        for candidate in candidates where candidate.recommendedDisposition.asCombo {
            guard let name = candidate.clusterName, !name.isEmpty else { continue }
            if let result = clusterResults[candidate.axisTag],
               let cluster = result.cluster(named: name),
               AxisStyleVocabulary.isPositionalFuzz(
                   cluster,
                   axisRange: axisRanges[candidate.axisTag] ?? 1000
               ) {
                continue
            }
            comboClustersByTag[candidate.axisTag, default: []].insert(name)
        }

        guard !comboClustersByTag.isEmpty else { return [] }

        var suggestions: [CompoundSuggestion] = []
        var seenKeys = Set<String>()

        for instance in analysis.instancesExisting {
            for (tag, comboNames) in comboClustersByTag {
                guard let raw = instance.coords[tag] else { continue }
                let value = AxisCoordinateFormat.canonical(raw)
                guard let result = clusterResults[tag],
                      let clusterName = result.clusterName(for: value),
                      comboNames.contains(where: { $0.caseInsensitiveCompare(clusterName) == .orderedSame })
                else { continue }

                var coords: [String: Double] = [:]
                for axisTag in instanceTags {
                    guard let axisRaw = instance.coords[axisTag] else { continue }
                    coords[axisTag] = AxisCoordinateFormat.canonical(axisRaw)
                }
                guard coords.count >= 2 else { continue }

                let key = coords.keys.sorted().map { "\($0)=\(AxisCoordinateFormat.format(coords[$0]!))" }
                    .joined(separator: "&")
                guard !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)

                var legLabels: [String: String] = [:]
                for (axisTag, axisValue) in coords {
                    if axisTag == tag {
                        legLabels[axisTag] = clusterName
                    } else if let stop = AxisCoordinate.matchingStop(
                        in: axisByTag[axisTag]?.values ?? [],
                        coordinate: axisValue
                    ) {
                        let label = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        legLabels[axisTag] = label.isEmpty ? AxisCoordinateFormat.format(axisValue) : label
                    } else if let held = candidates.first(where: {
                        $0.axisTag == axisTag && AxisCoordinate.valuesEqual($0.value, axisValue)
                    }) {
                        legLabels[axisTag] = held.proposedName
                    } else {
                        legLabels[axisTag] = AxisCoordinateFormat.format(axisValue)
                    }
                }

                // Prefer the instance's own composed name when it carries companion-axis
                // vocabulary ("Poster Extra Thin"); fall back to the peeled cluster name.
                let composed = instance.composedName.trimmingCharacters(in: .whitespacesAndNewlines)
                let suggestionName = composed.isEmpty ? clusterName : composed

                suggestions.append(
                    CompoundSuggestion(
                        fontID: fontID,
                        name: suggestionName,
                        coords: coords,
                        legLabels: legLabels,
                        coveredInstanceCount: 1,
                        sampleInstanceNames: composed.isEmpty ? [] : [composed]
                    )
                )
            }
        }

        return CompoundStatNaming.sortedByAxisOrder(
            suggestions,
            coords: { $0.coords },
            name: { $0.name },
            axes: axes,
            namingOrder: analysis.inferred.namingOrderSuggested
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
            let trimmed = font.axes[axisIndex].values[stopIndex].name
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                font.axes[axisIndex].values[stopIndex].name = conflict.existingName
            }
        case .takeFvar:
            font.axes[axisIndex].values[stopIndex].name = conflict.fvarName
        case .custom(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            font.axes[axisIndex].values[stopIndex].name = trimmed
        }
    }

    /// Applies Import Review decisions: held stops, conflicts, accepted Format 4 compounds,
    /// and slope ownership.
    @discardableResult
    public static func apply(
        reviewDecisions decisions: ReviewDecisions,
        report: Report,
        to font: inout FontDocument,
        naming: inout NamingPolicy
    ) -> [CompoundSuggestion] {
        for conflict in report.conflicts {
            guard let resolution = decisions.conflictResolutions[conflict.id] else { continue }
            apply(resolution: resolution, conflict: conflict, to: &font)
        }

        // Honor Neither / Combo: pull matching Format 1 stops back off the axis when the
        // review decision says they should not be univariate stops (STAT may have already
        // placed them, or a prior safe-seed pass may have).
        for candidate in report.heldStopCandidates {
            let disposition = decisions.stopDispositions[candidate.id] ?? candidate.recommendedDisposition
            guard !disposition.asStop else { continue }
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == candidate.axisTag }) else {
                continue
            }
            font.axes[axisIndex].values.removeAll {
                AxisCoordinate.valuesEqual($0.value, candidate.value) && $0.statFormat == 1
            }
        }

        let toPromote = report.heldStopCandidates.compactMap { candidate -> StopCandidate? in
            let disposition = decisions.stopDispositions[candidate.id] ?? candidate.recommendedDisposition
            guard disposition.asStop else { return nil }
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
                    let override = decisions.compoundNames[suggestion.id]?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let name = override.isEmpty ? suggestion.name : override
                    var compound = CompoundStatValue(
                        id: "compound-\(UUID().uuidString.prefix(8))",
                        coords: suggestion.coords,
                        axisIndices: [],
                        axisValues: [],
                        name: name,
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
        font.compoundStatValues = CompoundStatNaming.sortedByAxisOrder(
            font.compoundStatValues,
            axes: font.axes,
            namingOrder: naming.order
        )

        if let prompt = report.slopeOwnership {
            let choice = decisions.slopeOwnershipChoice ?? prompt.recommended
            SlopeAxisPolicy.applyImportChoice(choice, prompt: prompt, to: &font, naming: &naming)
        }

        return report.compoundSuggestions.filter { !decisions.acceptedCompoundIDs.contains($0.id) }
    }

    /// Test / call-site convenience when naming policy is not available.
    @discardableResult
    public static func apply(
        reviewDecisions decisions: ReviewDecisions,
        report: Report,
        to font: inout FontDocument
    ) -> [CompoundSuggestion] {
        var naming = NamingPolicy(order: font.axes.map(\.tag))
        return apply(reviewDecisions: decisions, report: report, to: &font, naming: &naming)
    }

    // MARK: - Apply helpers

    /// Removes Format 1 stops that don't sit on any fvar-observed coordinate when they are
    /// either outside the fvar axis range or part of a STAT ladder that shares *no* values
    /// with fvar (wrong coordinate space). Leaves Format 2/3 and grounded Format 1 alone so
    /// STAT-first fonts that extend beyond shipped instances keep their extra stops.
    private static func pruneUngroundedFormat1Stops(
        on font: inout FontDocument,
        analysis: FontAnalysis
    ) {
        let analysisByTag = Dictionary(uniqueKeysWithValues: analysis.axes.map { ($0.tag, $0) })
        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard axis.role == .instance, axis.hasFvarScale else { continue }

            let observed = observedValues(
                for: axis.tag,
                analyzed: analysisByTag[axis.tag],
                analysis: analysis
            )
            guard !observed.isEmpty else { continue }

            func isGrounded(_ value: Double) -> Bool {
                observed.contains { AxisCoordinate.valuesEqual($0, value) }
            }

            let format1 = axis.values.filter { $0.statFormat == 1 }
            guard !format1.isEmpty else { continue }
            let anyGrounded = format1.contains { isGrounded($0.value) }

            font.axes[axisIndex].values.removeAll { stop in
                guard stop.statFormat == 1 else { return false }
                if isGrounded(stop.value) { return false }
                if let min = axis.min, stop.value < min, !AxisCoordinate.valuesEqual(stop.value, min) {
                    return true
                }
                if let max = axis.max, stop.value > max, !AxisCoordinate.valuesEqual(stop.value, max) {
                    return true
                }
                // No Format 1 stop on this axis matches fvar — treat the ladder as foreign.
                return !anyGrounded
            }
        }
    }

    /// Drops Format 1 stops whose name belongs on another axis when a near-neighbor stop
    /// already covers the same style (Rooftop `wght=399 "Wide"` next to Regular@398).
    private static func pruneMisattributedNearNeighborStops(on font: inout FontDocument) {
        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard axis.role == .instance, axis.hasFvarScale else { continue }
            guard CompoundStatNaming.standaloneNamingTags.contains(axis.tag) else { continue }
            let axisRange = (axis.max ?? 1000) - (axis.min ?? 0)

            var removeIDs = Set<String>()
            for stop in axis.values where stop.statFormat == 1 {
                guard AxisStyleVocabulary.mismatchesAxis(stop.name, tag: axis.tag) else { continue }
                let hasNeighbor = axis.values.contains { other in
                    guard other.id != stop.id else { return false }
                    guard !AxisStyleVocabulary.mismatchesAxis(other.name, tag: axis.tag) else {
                        return false
                    }
                    let span = abs(other.value - stop.value)
                    return AxisStyleVocabulary.isPositionalFuzz(
                        span: span,
                        nearestForeignDistance: nil,
                        axisRange: axisRange
                    )
                }
                if hasNeighbor {
                    removeIDs.insert(stop.id)
                }
            }
            if !removeIDs.isEmpty {
                font.axes[axisIndex].values.removeAll { removeIDs.contains($0.id) }
            }
        }
    }

    /// Renames default/elidable stops whose STAT name belongs on another axis
    /// (Rooftop `slnt=0 "Condensed"` → Upright).
    private static func repairVocabularyMismatchedDefaultStops(on font: inout FontDocument) {
        for axisIndex in font.axes.indices {
            let axis = font.axes[axisIndex]
            guard CompoundStatNaming.standaloneNamingTags.contains(axis.tag) else { continue }
            guard let neutral = AxisStopNamingDefaults.defaultElidableName(for: axis.tag) else {
                continue
            }
            var repairedDefaultIndex: Int?
            for stopIndex in font.axes[axisIndex].values.indices {
                let stop = font.axes[axisIndex].values[stopIndex]
                guard AxisStyleVocabulary.mismatchesAxis(stop.name, tag: axis.tag) else { continue }
                let atDefault = axis.default.map { AxisCoordinate.valuesEqual(stop.value, $0) } ?? false
                guard atDefault || stop.elidable else { continue }
                font.axes[axisIndex].values[stopIndex].name = neutral
                if atDefault, AxisStopNamingDefaults.inventsElidableAtDefault(for: axis.tag) {
                    font.axes[axisIndex].values[stopIndex].elidable = true
                    repairedDefaultIndex = stopIndex
                }
            }
            // Source often marks the non-default slope stop elidable (Rooftop Italic@10).
            // After promoting the default to the sole elidable, clear the rest.
            if let keep = repairedDefaultIndex {
                for stopIndex in font.axes[axisIndex].values.indices where stopIndex != keep {
                    font.axes[axisIndex].values[stopIndex].elidable = false
                }
            }
        }
    }

    private static func duplicatedStopNames(on axis: AxisDefinition) -> Set<String> {
        var counts: [String: Int] = [:]
        for stop in axis.values {
            let key = stop.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            counts[key, default: 0] += 1
        }
        return Set(counts.compactMap { $0.value > 1 ? $0.key : nil })
    }

    private static func sanitizeCandidateVocabulary(_ candidate: StopCandidate) -> StopCandidate {
        guard AxisStyleVocabulary.mismatchesAxis(candidate.proposedName, tag: candidate.axisTag) else {
            return candidate
        }
        var updated = candidate
        updated.proposedName = AxisCoordinateFormat.format(candidate.value)
        if updated.recommendedDisposition.asStop {
            updated.recommendedDisposition = .neither
            updated.classification = .ambiguous
        }
        return updated
    }

    /// When Format 4 suggestions cover most of the cartesian product of their axes, they are
    /// restating an orthogonal catalog — not opsz-style entanglement. Drop them and demote
    /// matching combo candidates to Neither so Apply won't invent duplicate instance names.
    private static func suppressOrthogonalProductCompounds(
        suggestions: [CompoundSuggestion],
        candidates: inout [StopCandidate],
        analysis: FontAnalysis
    ) -> [CompoundSuggestion] {
        guard suggestions.count >= 6 else { return suggestions }

        let tags = Array(Set(suggestions.flatMap(\.coords.keys))).sorted()
        guard tags.count >= 2 else { return suggestions }

        // Full source catalog on those axes — not just values already present in suggestions
        // (a sparse 2-cell compound set would otherwise look 100% dense).
        var distinctFromSource: [String: Set<Double>] = [:]
        for instance in analysis.instancesExisting {
            for tag in tags {
                guard let value = instance.coords[tag] else { continue }
                distinctFromSource[tag, default: []].insert(AxisCoordinateFormat.canonical(value))
            }
        }
        let fullProduct = distinctFromSource.values.reduce(1) { $0 * max($1.count, 1) }
        guard fullProduct >= 8 else { return suggestions }

        let density = Double(suggestions.count) / Double(fullProduct)
        guard density >= 0.5 else { return suggestions }

        let comboValuesByTag: [String: Set<Double>] = {
            var map: [String: Set<Double>] = [:]
            for suggestion in suggestions {
                for (tag, value) in suggestion.coords {
                    map[tag, default: []].insert(AxisCoordinateFormat.canonical(value))
                }
            }
            return map
        }()

        candidates = candidates.map { candidate in
            guard candidate.recommendedDisposition.asCombo,
                  let values = comboValuesByTag[candidate.axisTag],
                  values.contains(where: { AxisCoordinate.valuesEqual($0, candidate.value) })
            else {
                return candidate
            }
            var updated = candidate
            updated.recommendedDisposition = .neither
            updated.classification = .ambiguous
            return updated
        }
        return []
    }

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

            let residue = AxisStyleVocabulary.strippingFileSlopeTokens(
                tokens.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
                forAxisTag: axisTag
            )
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

    /// Conflict UI never offers a blank label — fall back to the stop coordinate.
    private static func effectiveConflictStopName(_ name: String, value: Double) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AxisCoordinateFormat.format(value)
        }
        return trimmed
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
        decisions: [String: StopDisposition],
        acceptedCompoundCoords: [[String: Double]] = []
    ) -> Int {
        var valuesByTag: [String: [Double]] = [:]
        var product = 1
        for axis in font.axes where axis.role == .instance {
            var values = axis.values.map(\.value)
            if axis.hasFvarScale {
                for candidate in heldCandidates where candidate.axisTag == axis.tag {
                    let disposition = decisions[candidate.id] ?? candidate.recommendedDisposition
                    if disposition.asStop {
                        values.append(candidate.value)
                    } else {
                        // Combo / Neither: drop even if STAT already placed this coordinate.
                        values.removeAll { AxisCoordinate.valuesEqual($0, candidate.value) }
                    }
                }
            }
            let unique = uniqueSorted(values)
            valuesByTag[axis.tag] = unique
            product *= max(unique.count, 1)
            if product > 10_000 {
                return 10_000
            }
        }

        guard !acceptedCompoundCoords.isEmpty else { return product }

        let gridAxes: [AxisDefinition] = font.axes.compactMap { axis in
            guard axis.role == .instance else { return nil }
            var copy = axis
            copy.values = (valuesByTag[axis.tag] ?? []).map { value in
                AxisValue(
                    id: "\(axis.tag)-proj-\(AxisCoordinateFormat.format(value))",
                    value: value,
                    name: AxisCoordinateFormat.format(value),
                    elidable: false
                )
            }
            return copy
        }
        let pinned = AxisPinPolicy.pinnedCoords(from: font.axes)
        var extras = 0
        var seenExtraKeys = Set<String>()
        for coords in acceptedCompoundCoords {
            let materializations = InstancePlanner.materializeCompoundInstanceCoords(
                compoundCoords: coords,
                gridAxes: gridAxes,
                pinned: pinned
            )
            for materialized in materializations {
                let onGrid = gridAxes.allSatisfy { axis in
                    guard let value = materialized[axis.tag] else { return false }
                    return (valuesByTag[axis.tag] ?? []).contains { AxisCoordinate.valuesEqual($0, value) }
                }
                guard !onGrid else { continue }
                let key = InstanceKeyBuilder.makeKey(coords: materialized)
                if seenExtraKeys.insert(key).inserted {
                    extras += 1
                }
            }
        }

        return min(product + extras, 10_000)
    }

    /// Live Import Review preview: invent count under the current promote set.
    public static func previewExpansion(
        context: ExpansionPreviewContext,
        decisions: [String: StopDisposition],
        recommended: [String: StopDisposition],
        promotedNames: [String: String] = [:]
    ) -> ExpansionCallout? {
        var valuesByTag = context.baseValuesByTag
        var nameEntries = context.stopNameEntries
        for held in context.heldValues {
            let disposition = decisions[held.candidateID] ?? recommended[held.candidateID] ?? .combo
            guard disposition.asStop else { continue }
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
                if candidate.recommendedDisposition.asStop {
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
        analysis: FontAnalysis,
        compoundCoords: [[String: Double]] = []
    ) -> OrthogonalityMetrics {
        let recommended = Dictionary(uniqueKeysWithValues: candidates.map {
            ($0.id, $0.recommendedDisposition)
        })
        let allPromote = Dictionary(uniqueKeysWithValues: candidates.map {
            ($0.id, StopDisposition.stop)
        })
        return OrthogonalityMetrics(
            originalInstanceCount: analysis.instancesExisting.count,
            projectedAnalyticCount: projectedStyleCount(
                font: font,
                heldCandidates: candidates,
                decisions: recommended,
                acceptedCompoundCoords: compoundCoords
            ),
            projectedIfAllPromoted: projectedStyleCount(
                font: font,
                heldCandidates: candidates,
                decisions: allPromote,
                acceptedCompoundCoords: compoundCoords
            )
        )
    }

    private static func reviewReasons(
        candidates: [StopCandidate],
        expansion: ExpansionCallout?,
        suggestions: [CompoundSuggestion],
        conflicts: [NameConflict],
        sparsity: NamingSparsityCallout,
        codedNaming: InstanceCodedNaming.Detection?,
        orthogonality: OrthogonalityMetrics,
        slopeOwnership: SlopeAxisPolicy.ImportPrompt?
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
        if codedNaming != nil {
            reasons.append("coded instance names")
        }
        if let slopeOwnership {
            reasons.append("slope ownership (\(slopeOwnership.passiveTag))")
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
