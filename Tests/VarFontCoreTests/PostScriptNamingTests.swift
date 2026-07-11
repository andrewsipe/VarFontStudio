import XCTest
@testable import VarFontCore

final class PostScriptNamingTests: XCTestCase {
    private func opszAxis() -> AxisDefinition {
        AxisDefinition(
            tag: "opsz",
            min: 5,
            default: 12,
            max: 1200,
            role: .instance,
            values: [
                AxisValue(id: "o1", value: 5, name: "Micro", elidable: false),
                AxisValue(id: "o2", value: 100, name: "Normal", elidable: true),
            ]
        )
    }

    private func wdthAxis() -> AxisDefinition {
        AxisDefinition(
            tag: "wdth",
            min: 88,
            default: 100,
            max: 113,
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 88, name: "SemiCondensed", elidable: false),
                AxisValue(id: "w2", value: 100, name: "Normal", elidable: true),
            ]
        )
    }

    private func wghtAxis() -> AxisDefinition {
        AxisDefinition(
            tag: "wght",
            min: 360,
            default: 400,
            max: 900,
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 360, name: "Semilight", elidable: false),
                AxisValue(id: "g2", value: 400, name: "Regular", elidable: true),
            ]
        )
    }

    private func playfairNaming(hyphenAfterOpsz: Bool) -> NamingPolicy {
        var order = NamingPolicy.orderWithDefaultClarifiers(axisOrder: ["opsz", "wdth", "wght"])
        if hyphenAfterOpsz {
            order.removeAll { NamingToken.isPostscriptHyphen($0) }
            if let opszIndex = order.firstIndex(of: "opsz") {
                order.insert(NamingPolicy.postscriptHyphenToken, at: opszIndex + 1)
            }
        }
        return NamingPolicy(order: order, elidedFallback: "Regular")
    }

    func testDefaultHyphenFirstMatchesLegacyConcatenatedStyle() {
        let naming = playfairNaming(hyphenAfterOpsz: false)
        let style = PostScriptNaming.composeStyleSegment(
            coords: ["opsz": 5, "wdth": 88, "wght": 360],
            axes: [opszAxis(), wdthAxis(), wghtAxis()],
            naming: naming
        )
        XCTAssertEqual(style, "MicroSemiCondensedSemilight")
        XCTAssertEqual(
            PostScriptNaming.composeFullName(familyPrefix: "Playfair", styleSegment: style),
            "Playfair-MicroSemiCondensedSemilight"
        )
    }

    func testHyphenAfterOpszInsertsStyleBreak() {
        let naming = playfairNaming(hyphenAfterOpsz: true)
        let style = PostScriptNaming.composeStyleSegment(
            coords: ["opsz": 5, "wdth": 88, "wght": 360],
            axes: [opszAxis(), wdthAxis(), wghtAxis()],
            naming: naming
        )
        XCTAssertEqual(style, "Micro-SemiCondensedSemilight")
        XCTAssertEqual(
            PostScriptNaming.composeFullName(familyPrefix: "Playfair", styleSegment: style),
            "PlayfairMicro-SemiCondensedSemilight"
        )
    }

    func testMergedOrderInsertsHyphenWhenMissing() {
        let order = NamingPolicy.mergedOrder(projectOrder: ["wght", "opsz"], axisTags: ["opsz", "wght"])
        XCTAssertEqual(order.first, NamingPolicy.postscriptHyphenToken)
        XCTAssertEqual(order.filter { $0 == NamingPolicy.postscriptHyphenToken }.count, 1)
    }
}
