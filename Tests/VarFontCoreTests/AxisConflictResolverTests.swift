import XCTest
@testable import VarFontCore

final class AxisConflictResolverTests: XCTestCase {
    private func wdthAxis(
        values: [AxisValue],
        role: AxisRole = .instance
    ) -> AxisDefinition {
        AxisDefinition(
            tag: "wdth",
            displayName: "Width",
            min: 88,
            default: 100,
            max: 113,
            role: role,
            values: values
        )
    }

    private func font(axes: [AxisDefinition]) -> FontDocument {
        FontDocument(
            id: "test",
            sourcePath: "/tmp/test.ttf",
            outputPath: nil,
            analysisSnapshotID: nil,
            dirty: false,
            axes: axes,
            options: CommitOptions(),
            includedInstanceKeys: [],
            excludedInstanceKeys: [],
            overrides: InstanceOverrides()
        )
    }

    func testBundleDuplicateValueOnly() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
            AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
        ])
        let plan = InstancePlanner.plan(
            font: font(axes: [axis]),
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular")
        )

        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: [axis],
            namingOrder: ["wdth"]
        )

        XCTAssertEqual(bundles.count, 1)
        XCTAssertEqual(bundles[0].kind, .duplicateValue)
        XCTAssertEqual(Set(bundles[0].involvedStopIDs), ["a", "b"])
    }

    func testBundleDuplicateNameOnly() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let plan = InstancePlanner.plan(
            font: font(axes: [axis]),
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular")
        )

        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: [axis],
            namingOrder: ["wdth"]
        )

        XCTAssertEqual(bundles.count, 1)
        XCTAssertEqual(bundles[0].kind, .duplicateName)
    }

    func testBundleDuplicateValueAndName() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 100, name: "Normal", elidable: false),
        ])
        let plan = InstancePlanner.plan(
            font: font(axes: [axis]),
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular")
        )

        let bundles = AxisConflictBundler.bundles(
            warnings: plan.warnings,
            axes: [axis],
            namingOrder: ["wdth"]
        )

        XCTAssertEqual(bundles.count, 1)
        XCTAssertEqual(bundles[0].kind, .duplicateValueAndName)
    }

    func testProposalsForDuplicateValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
            AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let proposals = ConflictResolver.proposals(for: bundle, axis: axis)
        XCTAssertFalse(proposals.isEmpty)
        XCTAssertTrue(proposals.contains { proposal in
            if case .removeStop = proposal.action { return true }
            return false
        })
        XCTAssertTrue(proposals.contains { proposal in
            if case .revalueStop = proposal.action { return true }
            return false
        })
    }

    func testPreviewRemoveStopClearsDuplicateValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
            AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )
        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: .removeStop(stopID: "b")
        )

        XCTAssertTrue(preview.resolvesConflict)
        XCTAssertEqual(preview.remainingAxisConflicts, 0)
    }

    func testPreviewRenameClearsDuplicateName() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )
        let proposals = ConflictResolver.proposals(for: bundle, axis: axis)
        let rename = proposals.first { proposal in
            if case .renameStop = proposal.action { return true }
            return false
        }
        XCTAssertNotNil(rename)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: rename!.action
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testPreviewElisionClearsDuplicateName() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: .setElidable(stopID: "a", elidable: true)
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testSuggestedRenameUsesValueNotParenthetical() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )
        let stopB = axis.values.first { $0.id == "b" }!

        let suggested = ConflictResolver.suggestedRename(for: stopB, bundle: bundle, axis: axis)
        XCTAssertEqual(suggested, "101")
        XCTAssertFalse(suggested.contains("("))
    }

    func testResolvedActionTargetsSelectedStop() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
            AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )
        let keep = axis.values.first { $0.id == "a" }!

        let action = ConflictResolver.resolvedAction(
            strategy: .remove,
            stop: keep,
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: ""
        )
        XCTAssertEqual(action, .removeStop(stopID: "a"))
    }

    func testStrategiesForDuplicateNameIncludeElideOnInstanceAxis() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ], role: .instance)
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let strategies = ConflictResolver.strategies(for: bundle, axis: axis)
        XCTAssertTrue(strategies.contains(ConflictFixStrategy.setElidable))
    }

    func testPreviewInvolvedStopsRemoveTarget() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: true),
            AxisValue(id: "b", value: 100, name: "Nobody", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let outcomes = ConflictResolver.previewInvolvedStops(
            axis: axis,
            bundle: bundle,
            applying: .removeStop(stopID: "b")
        )

        XCTAssertEqual(outcomes.count, 2)
        XCTAssertEqual(outcomes.first { $0.stopID == "b" }?.isRemoved, true)
        XCTAssertEqual(outcomes.first { $0.stopID == "a" }?.isRemoved, false)
    }

    func testPreviewInvolvedStopsRenameTarget() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let outcomes = ConflictResolver.previewInvolvedStops(
            axis: axis,
            bundle: bundle,
            applying: .renameStop(stopID: "b", newName: "Wide")
        )

        XCTAssertEqual(outcomes.first { $0.stopID == "b" }?.nameAfter, "Wide")
        XCTAssertEqual(outcomes.first { $0.stopID == "a" }?.nameAfter, "Normal")
    }

    func testDuplicateValueAndNameStrategiesIncludeCompoundFixes() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Name", elidable: false),
            AxisValue(id: "b", value: 100, name: "Name", elidable: false),
        ], role: .instance)
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValueAndName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let strategies = ConflictResolver.strategies(for: bundle, axis: axis)
        XCTAssertTrue(strategies.contains(ConflictFixStrategy.revalueAndRename))
        XCTAssertTrue(strategies.contains(ConflictFixStrategy.revalueAndSetElidable))
        XCTAssertFalse(strategies.contains(ConflictFixStrategy.revalue))
        XCTAssertFalse(strategies.contains(ConflictFixStrategy.rename))
    }

    func testThreeStopRevalueAndRenameNeedsFollowUp() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Name", elidable: false),
            AxisValue(id: "b", value: 100, name: "Name", elidable: false),
            AxisValue(id: "c", value: 100, name: "Name", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValueAndName,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let action = ConflictResolver.resolvedAction(
            strategy: .revalueAndRename,
            stop: axis.values.first { $0.id == "c" }!,
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: ""
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertFalse(preview.resolvesConflict)
    }

    func testRevalueAndRenameClearsDuplicateValueAndName() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Name", elidable: false),
            AxisValue(id: "b", value: 100, name: "Name", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValueAndName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let action = ConflictResolver.resolvedAction(
            strategy: .revalueAndRename,
            stop: axis.values.first { $0.id == "b" }!,
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: ""
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testRevalueOnlyLeavesDuplicateValueAndNameConflict() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Name", elidable: false),
            AxisValue(id: "b", value: 100, name: "Name", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValueAndName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let action = ConflictResolver.resolvedAction(
            strategy: .revalue,
            stop: axis.values.first { $0.id == "b" }!,
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: ""
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertFalse(preview.resolvesConflict)
    }

    func testPreviewInvolvedStopsCompoundRevalueAndRename() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Name", elidable: false),
            AxisValue(id: "b", value: 100, name: "Name", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValueAndName,
            groups: [],
            involvedStopIDs: ["a", "b"]
        )

        let outcomes = ConflictResolver.previewInvolvedStops(
            axis: axis,
            bundle: bundle,
            applying: .compound([
                .revalueStop(stopID: "b", newValue: 94),
                .renameStop(stopID: "b", newName: "94"),
            ])
        )

        let target = outcomes.first { $0.stopID == "b" }
        XCTAssertEqual(target?.valueAfter, 94)
        XCTAssertEqual(target?.nameAfter, "94")
    }

    func testStrategiesForDuplicateNameIncludeRenameEach() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
            AxisValue(id: "c", value: 102, name: "Normal", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let strategies = ConflictResolver.strategies(for: bundle, axis: axis)
        XCTAssertTrue(strategies.contains(.renameEach))
    }

    func testSuggestedBulkRenamesUsesCoordinateValues() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
            AxisValue(id: "c", value: 102, name: "Normal", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let names = ConflictResolver.suggestedBulkRenames(for: bundle, axis: axis)
        XCTAssertEqual(names["a"], "100")
        XCTAssertEqual(names["b"], "101")
        XCTAssertEqual(names["c"], "102")
    }

    func testValidateBulkRenamesRejectsDuplicateNames() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
        ])
        let names = ["a": "Wide", "b": "Wide"]

        let error = ConflictResolver.validateBulkRenames(
            namesByStopID: names,
            axis: axis,
            involvedStopIDs: ["a", "b"]
        )
        XCTAssertNotNil(error)
    }

    func testBulkRenameActionClearsDuplicateName() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Normal", elidable: false),
            AxisValue(id: "b", value: 101, name: "Normal", elidable: false),
            AxisValue(id: "c", value: 102, name: "Normal", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateName,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )
        let names = ["a": "Condensed", "b": "Normal", "c": "Expanded"]

        let action = ConflictResolver.resolvedAction(
            strategy: .renameEach,
            stop: axis.values[0],
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: "",
            bulkRenameNames: names
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testStrategiesForDuplicateValueIncludeBulkOptions() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 100, name: "Black", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let strategies = ConflictResolver.strategies(for: bundle, axis: axis)
        XCTAssertTrue(strategies.contains(.keepOneStop))
        XCTAssertTrue(strategies.contains(.removeSelected))
        XCTAssertTrue(strategies.contains(.revalueEach))
    }

    func testKeepOneStopActionClearsDuplicateValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 100, name: "Black", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let action = ConflictResolver.resolvedAction(
            strategy: .keepOneStop,
            stop: axis.values.first { $0.id == "a" }!,
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: "",
            keepStopID: "a"
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testRemoveSelectedActionClearsDuplicateValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 100, name: "Black", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let action = ConflictResolver.resolvedAction(
            strategy: .removeSelected,
            stop: axis.values[0],
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: "",
            removalStopIDs: ["b", "c"]
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testBulkRevalueActionClearsDuplicateValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 100, name: "Black", elidable: false),
        ])
        let document = font(axes: [axis])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )
        let values = ConflictResolver.suggestedBulkRevalues(for: bundle, axis: axis)

        let action = ConflictResolver.resolvedAction(
            strategy: .revalueEach,
            stop: axis.values[0],
            bundle: bundle,
            axis: axis,
            renameText: "",
            revalueText: "",
            bulkRevalueTexts: values
        )
        XCTAssertNotNil(action)

        let preview = ConflictResolver.previewPlan(
            font: document,
            naming: NamingPolicy(order: ["wdth"], elidedFallback: "Regular"),
            bundle: bundle,
            applying: action!
        )
        XCTAssertTrue(preview.resolvesConflict)
    }

    func testSuggestedBulkRevaluesAreUnique() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 100, name: "Black", elidable: false),
        ])
        let bundle = AxisConflictBundle(
            axisTag: "wdth",
            axisLabel: "Width",
            kind: .duplicateValue,
            groups: [],
            involvedStopIDs: ["a", "b", "c"]
        )

        let values = ConflictResolver.suggestedBulkRevalues(for: bundle, axis: axis)
        let parsed = values.values.compactMap { ConflictResolver.parseValue($0) }
        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(Set(parsed.map { AxisCoordinateFormat.format($0) }).count, 3)
    }

    func testDuplicateValueWarningsSortedByValue() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
            AxisValue(id: "c", value: 50, name: "Condensed", elidable: false),
            AxisValue(id: "d", value: 50, name: "Narrow", elidable: false),
        ])
        let warnings = AxisStopValidator.validate(axes: [axis])
            .filter { $0.code == "duplicate_stop_value" }
        XCTAssertEqual(warnings.count, 2)
        XCTAssertEqual(warnings[0].name, "50")
        XCTAssertEqual(warnings[1].name, "100")
    }

    func testBundlerReadsDuplicateValueFromStopCoordinate() {
        let axis = wdthAxis(values: [
            AxisValue(id: "a", value: 100, name: "Regular", elidable: true),
            AxisValue(id: "b", value: 100, name: "Bold", elidable: false),
        ])
        let warning = PlanWarning(
            code: "duplicate_stop_value",
            axis: "wdth",
            name: "not-parseable",
            stopIDs: ["a", "b"],
            message: "test"
        )
        let bundles = AxisConflictBundler.bundles(
            warnings: [warning],
            axes: [axis],
            namingOrder: ["wdth"]
        )
        XCTAssertEqual(bundles.count, 1)
        XCTAssertEqual(bundles[0].groups[0].duplicateValue, 100)
    }
}
