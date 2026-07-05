import Foundation

public enum PlanIssueCodes {
    public static let resolvable: Set<String> = [
        "registration_value_missing",
        "registration_mismatch",
        "orphan_stat_link",
        "ital_value_name_mismatch",
        "default_token_names",
        "axis_neutral_mismatch",
        "duplicate_composed_name",
        "multiple_elidable",
    ]

    public static func issueKey(for warning: PlanWarning) -> String {
        let axis = warning.axis ?? ""
        let stops = (warning.stopIDs ?? []).sorted().joined(separator: ",")
        return "\(warning.code):\(axis):\(stops)"
    }
}

public enum PlanIssueAction: Equatable, Sendable {
    case setFileRegistration(tag: String, value: Double)
    case revalueStop(axisTag: String, stopID: String, newValue: Double)
    case convertStopToFormat1(axisTag: String, stopID: String)
    case renameStop(axisTag: String, stopID: String, newName: String)
    case applyAxisDefaults
    case applyAxisNeutrals
    case normalizeElidable(axisTag: String)
    case clearAllElidable(axisTag: String)
    case acknowledgeIssue(issueKey: String)
    case compound([PlanIssueAction])
}

public struct PlanIssueProposal: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var action: PlanIssueAction
    public var isRecommended: Bool

    public init(
        id: String,
        title: String,
        detail: String,
        action: PlanIssueAction,
        isRecommended: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.action = action
        self.isRecommended = isRecommended
    }
}

public enum PlanIssueResolver {
    // MARK: - Proposals

    public static func proposals(for warning: PlanWarning, font: FontDocument) -> [PlanIssueProposal] {
        guard PlanIssueCodes.resolvable.contains(warning.code) else { return [] }
        switch warning.code {
        case "registration_value_missing":
            return registrationValueMissingProposals(for: warning, font: font)
        case "registration_mismatch":
            return registrationMismatchProposals(for: warning, font: font)
        case "orphan_stat_link":
            return orphanStatLinkProposals(for: warning, font: font)
        case "ital_value_name_mismatch":
            return italConventionProposals(for: warning, font: font)
        case "default_token_names", "axis_neutral_mismatch":
            return defaultTokenNamesProposals(for: warning, font: font)
        case "duplicate_composed_name":
            return duplicateComposedNameProposals(for: warning, font: font)
        case "multiple_elidable":
            return multipleElidableProposals(for: warning, font: font)
        default:
            return []
        }
    }

    public static func recommendedProposal(for warning: PlanWarning, font: FontDocument) -> PlanIssueProposal? {
        guard let proposal = proposals(for: warning, font: font).first(where: \.isRecommended) else {
            return nil
        }
        guard wouldApply(proposal.action, to: font) else { return nil }
        return proposal
    }

    public static func wouldApply(_ action: PlanIssueAction, to font: FontDocument) -> Bool {
        switch action {
        case .applyAxisNeutrals:
            return AxisStopNamingDefaults.wouldChangeFromApplyAxisNeutrals(font)
        case .applyAxisDefaults:
            return AxisStopNamingDefaults.wouldChangeFromApplyAxisDefaults(font)
        case .normalizeElidable(let axisTag):
            guard let axis = font.axes.first(where: { $0.tag == axisTag }) else { return false }
            return axis.values.filter(\.elidable).count > 1
        case .clearAllElidable(let axisTag):
            guard let axis = font.axes.first(where: { $0.tag == axisTag }) else { return false }
            return axis.values.contains(where: \.elidable)
        case .setFileRegistration, .revalueStop, .convertStopToFormat1, .renameStop:
            return true
        case .acknowledgeIssue:
            return false
        case .compound(let actions):
            return actions.contains { wouldApply($0, to: font) }
        }
    }

    public static func canApplyWithoutSheet(for warning: PlanWarning, font: FontDocument) -> Bool {
        let proposals = proposals(for: warning, font: font)
        guard proposals.count == 1, let only = proposals.first, only.isRecommended else { return false }
        if case .acknowledgeIssue = only.action { return false }
        return true
    }

    public static func canChainApply(for warning: PlanWarning, font: FontDocument) -> Bool {
        guard let proposal = recommendedProposal(for: warning, font: font), proposal.isRecommended else {
            return false
        }
        return isChainableAction(proposal.action)
    }

    // MARK: - Apply

    public static func apply(_ action: PlanIssueAction, to font: inout FontDocument) {
        switch action {
        case let .compound(actions):
            for step in actions {
                apply(step, to: &font)
            }
        case .applyAxisDefaults:
            AxisStopNamingDefaults.applyAxisDefaultsToAllInstanceAxes(font: &font)
        case .applyAxisNeutrals:
            AxisStopNamingDefaults.applyAxisNeutralsToAllInstanceAxes(font: &font)
        case let .normalizeElidable(axisTag):
            normalizeElidable(on: axisTag, font: &font)
        case let .clearAllElidable(axisTag):
            clearAllElidable(on: axisTag, font: &font)
        case let .setFileRegistration(tag, value):
            font.fileStatRegistration[tag] = value
        case let .revalueStop(axisTag, stopID, newValue):
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }),
                  let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else { return }
            let previousValue = font.axes[axisIndex].values[stopIndex].value
            let wasRegistered = font.fileStatRegistration[axisTag]
                .map { AxisCoordinate.valuesEqual($0, previousValue) } ?? false
            font.axes[axisIndex].values[stopIndex].value = newValue
            font.axes[axisIndex].values.sort { $0.value < $1.value }
            if wasRegistered {
                font.fileStatRegistration[axisTag] = newValue
            }
        case let .convertStopToFormat1(axisTag, stopID):
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }),
                  let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else { return }
            font.axes[axisIndex].values[stopIndex].statFormat = 1
            font.axes[axisIndex].values[stopIndex].linkedValue = nil
        case let .renameStop(axisTag, stopID, newName):
            guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }),
                  let stopIndex = font.axes[axisIndex].values.firstIndex(where: { $0.id == stopID }) else { return }
            font.axes[axisIndex].values[stopIndex].name = newName
        case let .acknowledgeIssue(issueKey):
            if !font.dismissedPlanIssues.contains(issueKey) {
                font.dismissedPlanIssues.append(issueKey)
            }
        }
    }

    // MARK: - Auto-fix (import only)

    @discardableResult
    public static func applySafeAutoFixes(to font: inout FontDocument, analysis: FontAnalysis? = nil) -> Int {
        var applied = 0
        for _ in 0..<8 {
            let warnings = visibleWarnings(for: font, analysis: analysis)
            guard let warning = warnings.first(where: { warning in
                guard let proposal = recommendedProposal(for: warning, font: font),
                      proposal.isRecommended,
                      isSafeAutoFixAction(proposal.action) else {
                    return false
                }
                return true
            }),
            let proposal = recommendedProposal(for: warning, font: font) else { break }
            apply(proposal.action, to: &font)
            applied += 1
        }
        return applied
    }

    public static func visibleWarnings(for font: FontDocument, analysis: FontAnalysis? = nil) -> [PlanWarning] {
        let all = RegistrationAxisSupport.allRegistrationPlanWarnings(font: font, analysis: analysis)
            + StatFormat3Pairing.orphanLinkWarnings(axes: font.axes)
        return all.filter { !font.dismissedPlanIssues.contains(PlanIssueCodes.issueKey(for: $0)) }
    }

    // MARK: - Private

    private static func isSafeAutoFixAction(_ action: PlanIssueAction) -> Bool {
        switch action {
        case .setFileRegistration, .revalueStop:
            return true
        case .convertStopToFormat1, .renameStop, .acknowledgeIssue, .applyAxisDefaults, .applyAxisNeutrals,
             .normalizeElidable, .clearAllElidable:
            return false
        case .compound(let actions):
            return actions.allSatisfy(isSafeAutoFixAction)
        }
    }

    private static func isChainableAction(_ action: PlanIssueAction) -> Bool {
        switch action {
        case .setFileRegistration, .revalueStop, .convertStopToFormat1, .applyAxisDefaults, .applyAxisNeutrals,
             .normalizeElidable, .clearAllElidable:
            return true
        case .renameStop, .acknowledgeIssue:
            return false
        case .compound(let actions):
            return actions.allSatisfy(isChainableAction)
        }
    }

    private static func registrationValueMissingProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        guard let tag = warning.axis,
              let axis = font.axes.first(where: { $0.tag == tag }),
              axis.isDesignRecordOnly else { return [] }
        guard !axis.values.isEmpty else { return [] }

        if let inferred = RegistrationAxisSupport.inferRegistrationValue(
            forTag: tag,
            axes: font.axes,
            sourcePath: font.sourcePath,
            inferredIsItalicFile: font.inferredIsItalicFile
        ) {
            return [
                PlanIssueProposal(
                    id: "reg-missing-infer",
                    title: "Use inferred registration",
                    detail: "Set registration to \(AxisCoordinateFormat.format(inferred)) on axis '\(tag)'.",
                    action: .setFileRegistration(tag: tag, value: inferred),
                    isRecommended: true
                ),
            ]
        }
        return []
    }

    private static func registrationMismatchProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        guard let tag = warning.axis,
              let axis = font.axes.first(where: { $0.tag == tag }) else { return [] }

        var proposals: [PlanIssueProposal] = []

        if let upright = RegistrationAxisSupport.uprightStop(on: axis) {
            proposals.append(
                PlanIssueProposal(
                    id: "reg-mismatch-upright",
                    title: "Use Roman registration",
                    detail: "Register this file as “\(upright.name)” on axis '\(tag)'.",
                    action: .setFileRegistration(tag: tag, value: upright.value),
                    isRecommended: true
                )
            )
        }

        if proposals.isEmpty,
           let regValue = font.fileStatRegistration[tag],
           let stop = AxisCoordinate.matchingStop(in: axis.values, coordinate: regValue) {
            proposals.append(
                PlanIssueProposal(
                    id: "reg-mismatch-rename",
                    title: "Rename stop to Roman",
                    detail: "Rename “\(stop.name)” to Roman so registration matches an upright file.",
                    action: .renameStop(axisTag: tag, stopID: stop.id, newName: "Roman"),
                    isRecommended: true
                )
            )
        }

        for stop in axis.values where !proposals.contains(where: {
            if case let .setFileRegistration(t, v) = $0.action { return t == tag && AxisCoordinate.valuesEqual(v, stop.value) }
            return false
        }) {
            proposals.append(
                PlanIssueProposal(
                    id: "reg-pick-\(stop.id)",
                    title: "Use “\(stop.name)”",
                    detail: "Register this file as “\(stop.name)” on axis '\(tag)'.",
                    action: .setFileRegistration(tag: tag, value: stop.value)
                )
            )
        }

        proposals.append(
            PlanIssueProposal(
                id: "reg-mismatch-keep",
                title: "Keep current registration",
                detail: "Leave registration as-is.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            )
        )
        return proposals
    }

    private static func orphanStatLinkProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        guard let tag = warning.axis,
              let stopID = warning.stopIDs?.first,
              let axis = font.axes.first(where: { $0.tag == tag }),
              let stop = axis.values.first(where: { $0.id == stopID }) else { return [] }

        if let compound = compoundOrphanItalProposal(
            axisTag: tag,
            stopID: stopID,
            stop: stop,
            font: font,
            warning: warning
        ) {
            return [compound]
        }

        return [
            PlanIssueProposal(
                id: "orphan-convert-f1",
                title: "Convert to Format 1",
                detail: "Remove the broken Format 3 link on “\(stop.name)” and keep it as a standalone stop.",
                action: .convertStopToFormat1(axisTag: tag, stopID: stopID),
                isRecommended: true
            ),
            PlanIssueProposal(
                id: "orphan-keep-f3",
                title: "Keep Format 3 link",
                detail: "Accept the source font’s link as-is.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            ),
        ]
    }

    private static func italConventionProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        guard let tag = warning.axis,
              let stopID = warning.stopIDs?.first,
              let axis = font.axes.first(where: { $0.tag == tag }),
              let stop = axis.values.first(where: { $0.id == stopID }),
              let corrected = RegistrationAxisSupport.correctedItalConventionValue(for: stop) else { return [] }

        if let compound = compoundOrphanItalProposal(
            axisTag: tag,
            stopID: stopID,
            stop: stop,
            font: font,
            warning: warning
        ) {
            return [compound]
        }

        let label = corrected == 0 ? "0 (Roman/upright)" : "1 (Italic)"
        return [
            PlanIssueProposal(
                id: "ital-convention-fix",
                title: "Set value to \(label)",
                detail: "Align “\(stop.name)” with the usual \(tag) convention (\(label)).",
                action: .revalueStop(axisTag: tag, stopID: stopID, newValue: corrected),
                isRecommended: true
            ),
            PlanIssueProposal(
                id: "ital-convention-keep",
                title: "Keep current value",
                detail: "Leave “\(stop.name)” at \(AxisCoordinateFormat.format(stop.value)).",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            ),
        ]
    }

    private static func defaultTokenNamesProposals(for warning: PlanWarning, font: FontDocument) -> [PlanIssueProposal] {
        applyAxisNeutralsProposals(
            for: warning,
            detail: AxisStopNamingDefaults.applyAxisNeutralsDetail(for: font)
        )
    }

    private static func duplicateComposedNameProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        if AxisStopNamingDefaults.hasInstanceAxisValueConflicts(font) {
            return conflictBlocksNamingFixProposals(for: warning)
        }
        if AxisStopNamingDefaults.hasUniformStopNamesOnInstanceAxes(font),
           AxisStopNamingDefaults.wouldChangeFromApplyAxisDefaults(font) {
            return applyAxisDefaultsProposals(
                for: warning,
                title: "Rename stops from values",
                detail: AxisStopNamingDefaults.applyAxisDefaultsDetail(for: font)
            )
        }
        if AxisStopNamingDefaults.hasAxisNeutralMismatch(font),
           AxisStopNamingDefaults.wouldChangeFromApplyAxisNeutrals(font) {
            return applyAxisNeutralsProposals(
                for: warning,
                detail: AxisStopNamingDefaults.applyAxisNeutralsDetail(for: font)
            )
        }
        if AxisStopNamingDefaults.wouldChangeFromApplyAxisDefaults(font) {
            return applyAxisDefaultsProposals(
                for: warning,
                title: "Rename stops from values",
                detail: AxisStopNamingDefaults.applyAxisDefaultsDetail(for: font)
            )
        }
        return noAutomaticNamingFixProposals(for: warning)
    }

    private static func conflictBlocksNamingFixProposals(for warning: PlanWarning) -> [PlanIssueProposal] {
        [
            PlanIssueProposal(
                id: "resolve-value-conflicts",
                title: "Resolve axis value conflicts first",
                detail: "Duplicate instance names come from multiple stops sharing the same coordinate. Use Resolve on the affected axis, then revisit naming.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning)),
                isRecommended: false
            ),
        ]
    }

    private static func noAutomaticNamingFixProposals(for warning: PlanWarning) -> [PlanIssueProposal] {
        [
            PlanIssueProposal(
                id: "no-auto-naming-fix",
                title: "Adjust stops manually",
                detail: "No safe one-click rename remains. Rename or elide stops in the axis tree, or use Resolve for axis conflicts.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning)),
                isRecommended: false
            ),
        ]
    }

    private static func applyAxisNeutralsProposals(
        for warning: PlanWarning,
        detail: String
    ) -> [PlanIssueProposal] {
        [
            PlanIssueProposal(
                id: "apply-axis-neutrals",
                title: "Align baseline labels",
                detail: detail,
                action: .applyAxisNeutrals,
                isRecommended: true
            ),
            PlanIssueProposal(
                id: "keep-names",
                title: "Keep names",
                detail: "Leave instance names as they are.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            ),
        ]
    }

    private static func applyAxisDefaultsProposals(
        for warning: PlanWarning,
        title: String = "Apply axis defaults",
        detail: String
    ) -> [PlanIssueProposal] {
        [
            PlanIssueProposal(
                id: "apply-axis-defaults",
                title: title,
                detail: detail,
                action: .applyAxisDefaults,
                isRecommended: true
            ),
            PlanIssueProposal(
                id: "keep-names",
                title: "Keep names",
                detail: "Leave instance names as they are.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            ),
        ]
    }

    private static func multipleElidableProposals(
        for warning: PlanWarning,
        font: FontDocument
    ) -> [PlanIssueProposal] {
        guard let tag = warning.axis else { return [] }
        let label = font.axes.first(where: { $0.tag == tag })?.displayName ?? tag
        return [
            PlanIssueProposal(
                id: "normalize-elidable-\(tag)",
                title: "Keep one elidable stop",
                detail: "Clear elision on all but the lowest-value stop on \(label).",
                action: .normalizeElidable(axisTag: tag),
                isRecommended: true
            ),
            PlanIssueProposal(
                id: "clear-all-elidable-\(tag)",
                title: "Clear all elision",
                detail: "Turn off elision on every stop on \(label). No stop will be omitted from composed names.",
                action: .clearAllElidable(axisTag: tag)
            ),
            PlanIssueProposal(
                id: "keep-elidable-\(tag)",
                title: "Keep as-is",
                detail: "Leave elidable flags unchanged.",
                action: .acknowledgeIssue(issueKey: PlanIssueCodes.issueKey(for: warning))
            ),
        ]
    }

    private static func clearAllElidable(on axisTag: String, font: inout FontDocument) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }) else { return }
        for index in font.axes[axisIndex].values.indices {
            font.axes[axisIndex].values[index].elidable = false
        }
    }

    private static func normalizeElidable(on axisTag: String, font: inout FontDocument) {
        guard let axisIndex = font.axes.firstIndex(where: { $0.tag == axisTag }) else { return }
        let elidableStops = font.axes[axisIndex].values.filter(\.elidable)
        guard elidableStops.count > 1,
              let keep = elidableStops.min(by: { $0.value < $1.value }) else { return }
        for index in font.axes[axisIndex].values.indices {
            font.axes[axisIndex].values[index].elidable =
                font.axes[axisIndex].values[index].id == keep.id
        }
    }

    private static func compoundOrphanItalProposal(
        axisTag: String,
        stopID: String,
        stop: AxisValue,
        font: FontDocument,
        warning: PlanWarning
    ) -> PlanIssueProposal? {
        guard stop.statFormat == 3,
              let axis = font.axes.first(where: { $0.tag == axisTag }),
              let corrected = RegistrationAxisSupport.correctedItalConventionValue(for: stop) else {
            return nil
        }

        let hasOrphan = StatFormat3Pairing.orphanLinkWarnings(for: axis)
            .contains { $0.stopIDs?.contains(stopID) == true }
        let hasItalMismatch = RegistrationAxisSupport.italConventionWarnings(font: font)
            .contains { $0.stopIDs?.contains(stopID) == true }
        guard hasOrphan && hasItalMismatch else { return nil }

        let romanLabel = corrected == 0 ? "0 (Roman)" : "1 (Italic)"
        var actions: [PlanIssueAction] = [
            .convertStopToFormat1(axisTag: axisTag, stopID: stopID),
            .revalueStop(axisTag: axisTag, stopID: stopID, newValue: corrected),
        ]
        if font.fileStatRegistration[axisTag].map({ AxisCoordinate.valuesEqual($0, stop.value) }) == true {
            actions.append(.setFileRegistration(tag: axisTag, value: corrected))
        }

        return PlanIssueProposal(
            id: "compound-orphan-ital-\(stopID)",
            title: "Convert to Format 1 and set value to \(romanLabel)",
            detail: "Fix the broken Format 3 link on “\(stop.name)” and align with the usual \(axisTag) convention.",
            action: .compound(actions),
            isRecommended: true
        )
    }
}

extension StatFormat3Pairing {
    public static func orphanLinkWarnings(axes: [AxisDefinition]) -> [PlanWarning] {
        axes.flatMap { orphanLinkWarnings(for: $0) }
    }
}
