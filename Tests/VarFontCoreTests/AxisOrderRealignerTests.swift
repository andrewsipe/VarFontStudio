import XCTest
@testable import VarFontCore

final class AxisOrderRealignerTests: XCTestCase {
    private func axis(_ tag: String, role: AxisRole = .instance) -> AxisDefinition {
        AxisDefinition(
            tag: tag,
            displayName: tag,
            min: 0,
            default: 0,
            max: 100,
            role: role,
            values: [
                AxisValue(id: "\(tag)-0", value: 0, name: tag, elidable: false),
            ]
        )
    }

    func testCanonicalAxisTagOrderPrefersNamingThenTail() {
        let order = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: ["@pshyphen", "wdth", "wght", "@width"],
            fontAxisTags: ["wght", "wdth", "slnt", "ital"]
        )
        XCTAssertEqual(order, ["wdth", "wght", "slnt", "ital"])
    }

    func testPermuteAxesMatchesTagOrder() {
        let axes = [axis("wght"), axis("wdth"), axis("slnt")]
        let permuted = AxisOrderRealigner.permuteAxes(axes, toTagOrder: ["wdth", "wght", "slnt"])
        XCTAssertEqual(permuted.map(\.tag), ["wdth", "wght", "slnt"])
    }

    func testPermuteNamingAxisTagsPreservesClarifiers() {
        let naming = ["@pshyphen", "wght", "wdth", "@width", "slnt"]
        let axisTags: Set<String> = ["wght", "wdth", "slnt"]
        let updated = AxisOrderRealigner.permuteNamingAxisTags(
            naming,
            axisTags: axisTags,
            toAxisTagOrder: ["wdth", "wght", "slnt"]
        )
        XCTAssertEqual(updated, ["@pshyphen", "wdth", "wght", "@width", "slnt"])
    }

    func testSyncStatDesignAxisTagsFollowsCanonicalOrder() {
        let axes = [
            axis("wght"),
            axis("wdth"),
            axis("slnt"),
            axis("ital", role: .designRecordOnly),
        ]
        let synced = AxisOrderRealigner.syncStatDesignAxisTags(
            canonicalOrder: ["wdth", "wght", "slnt", "ital"],
            currentDesignTags: ["wght", "wdth", "slnt", "ital"],
            axes: axes
        )
        XCTAssertEqual(synced, ["wdth", "wght", "slnt", "ital"])
    }

    func testFvarTagOrderSkipsDesignOnlyAxes() {
        var ital = axis("ital", role: .designRecordOnly)
        ital.min = nil
        let axes = [
            axis("wght"),
            axis("wdth"),
            ital,
        ]
        let fvarOrder = AxisOrderRealigner.fvarTagOrder(
            from: ["wdth", "wght", "ital"],
            axes: axes
        )
        XCTAssertEqual(fvarOrder, ["wdth", "wght"])
    }

    func testResortIncludedInstanceKeysPreservesWhitelist() {
        let planKeys = ["wdth:25|wght:100", "wdth:25|wght:200", "wdth:50|wght:100"]
        let current = ["wdth:50|wght:100", "wdth:25|wght:100"]
        let resorted = AxisOrderRealigner.resortIncludedInstanceKeys(
            currentKeys: current,
            planInstanceKeys: planKeys
        )
        XCTAssertEqual(resorted, ["wdth:25|wght:100", "wdth:50|wght:100"])
    }

    func testApplyCanonicalOrderRemapsCompoundIndices() {
        var font = FontDocument(
            id: "f1",
            sourcePath: "/tmp/font.ttf",
            axes: [axis("wght"), axis("wdth")],
            compoundStatValues: [
                CompoundStatValue(
                    id: "c1",
                    coords: ["wght": 400, "wdth": 100],
                    axisIndices: [0, 1],
                    axisValues: [400, 100],
                    name: "Combo",
                    elidable: false
                ),
            ],
            statDesignAxisTags: ["wght", "wdth"]
        )
        AxisOrderRealigner.applyCanonicalOrder(to: &font, canonicalOrder: ["wdth", "wght"])
        XCTAssertEqual(font.axes.map(\.tag), ["wdth", "wght"])
        XCTAssertEqual(font.statDesignAxisTags, ["wdth", "wght"])
        XCTAssertEqual(font.compoundStatValues[0].axisIndices, [0, 1])
        XCTAssertEqual(font.compoundStatValues[0].axisValues, [100, 400])
    }

    func testBidirectionalNamingAndTreeOrderRoundTrip() {
        let axisTags: Set<String> = ["wght", "wdth", "slnt"]
        var naming = ["@pshyphen", "wght", "wdth", "slnt"]

        naming = AxisOrderRealigner.permuteNamingAxisTags(
            naming,
            axisTags: axisTags,
            toAxisTagOrder: ["wdth", "wght", "slnt"]
        )
        XCTAssertEqual(naming, ["@pshyphen", "wdth", "wght", "slnt"])

        let afterNaming = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: naming,
            fontAxisTags: ["wght", "wdth", "slnt"]
        )
        XCTAssertEqual(afterNaming, ["wdth", "wght", "slnt"])

        naming = AxisOrderRealigner.permuteNamingAxisTags(
            naming,
            axisTags: axisTags,
            toAxisTagOrder: ["wght", "wdth", "slnt"]
        )
        let afterTree = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: naming,
            fontAxisTags: ["wght", "wdth", "slnt"]
        )
        XCTAssertEqual(afterTree, ["wght", "wdth", "slnt"])
    }

    func testLoadReconcilePrefersAxisTreeOverNamingSuggestion() {
        // Font axis order (tree) is wght→wdth; naming suggested wdth→wght.
        let treeOrder = ["wght", "wdth", "slnt"]
        let namingSuggested = ["@pshyphen", "wdth", "wght", "slnt", "@width"]
        let projectAxisTags: Set<String> = ["wght", "wdth", "slnt"]
        let target = AxisOrderRealigner.canonicalAxisTagOrder(
            namingOrder: treeOrder + axisTagSubsequence(namingSuggested, projectAxisTags),
            fontAxisTags: Array(projectAxisTags)
        )
        XCTAssertEqual(target, ["wght", "wdth", "slnt"])
        let reconciled = AxisOrderRealigner.permuteNamingAxisTags(
            namingSuggested,
            axisTags: projectAxisTags,
            toAxisTagOrder: target
        )
        XCTAssertEqual(reconciled, ["@pshyphen", "wght", "wdth", "slnt", "@width"])
    }

    private func axisTagSubsequence(_ namingOrder: [String], _ axisTags: Set<String>) -> [String] {
        namingOrder.filter { axisTags.contains($0) }
    }

    func testMultiFontCanonicalOrderRespectsPerFontAxes() {
        let naming = ["@pshyphen", "wdth", "wght", "slnt"]
        let fontA = ["wght", "wdth", "slnt"]
        let fontB = ["wght", "wdth"]
        XCTAssertEqual(
            AxisOrderRealigner.canonicalAxisTagOrder(namingOrder: naming, fontAxisTags: fontA),
            ["wdth", "wght", "slnt"]
        )
        XCTAssertEqual(
            AxisOrderRealigner.canonicalAxisTagOrder(namingOrder: naming, fontAxisTags: fontB),
            ["wdth", "wght"]
        )
    }

    func testPlannerCartesianIsWidthMajorAfterReorder() {
        let wght = AxisDefinition(
            tag: "wght",
            min: 100,
            default: 400,
            max: 900,
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 100, name: "Thin", elidable: false),
                AxisValue(id: "w2", value: 700, name: "Bold", elidable: false),
            ]
        )
        let wdth = AxisDefinition(
            tag: "wdth",
            min: 25,
            default: 100,
            max: 200,
            role: .instance,
            values: [
                AxisValue(id: "d1", value: 25, name: "Compressed", elidable: false),
                AxisValue(id: "d2", value: 100, name: "Normal", elidable: true),
            ]
        )
        var font = FontDocument(
            id: "f1",
            sourcePath: "/tmp/font.ttf",
            axes: [wght, wdth],
            statDesignAxisTags: ["wght", "wdth"]
        )
        AxisOrderRealigner.applyCanonicalOrder(to: &font, canonicalOrder: ["wdth", "wght"])
        let plan = InstancePlanner.plan(
            font: font,
            naming: NamingPolicy(order: ["@pshyphen", "wdth", "wght"])
        )
        let keys = plan.instances.map(\.key)
        XCTAssertEqual(keys.first, "wdth:25|wght:100")
        XCTAssertEqual(keys[1], "wdth:25|wght:700")
        XCTAssertEqual(keys[2], "wdth:100|wght:100")
    }
}
