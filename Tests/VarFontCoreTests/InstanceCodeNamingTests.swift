import XCTest
@testable import VarFontCore

final class InstanceCodeBuilderTests: XCTestCase {
    func testSanitizeKeepsTwoAlphanumeric() {
        XCTAssertEqual(InstanceCodeBuilder.sanitize("341"), "34")
        XCTAssertEqual(InstanceCodeBuilder.sanitize("W1!"), "W1")
        XCTAssertEqual(InstanceCodeBuilder.sanitize("  a  "), "a")
        XCTAssertNil(InstanceCodeBuilder.sanitize(""))
        XCTAssertNil(InstanceCodeBuilder.sanitize("!!"))
        XCTAssertNil(InstanceCodeBuilder.sanitize(nil))
    }

    func testComposeUniversStyleIgnoresElision() {
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 100, name: "Normal", elidable: true, code: "4"),
            ]
        )
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 700, name: "Bold", elidable: false, code: "3"),
            ]
        )
        let ital = AxisDefinition(
            tag: "ital",
            role: .designRecordOnly,
            values: [
                AxisValue(id: "i1", value: 1, name: "Italic", elidable: false, code: "1"),
            ]
        )

        // Axis tree order: width → weight → italic → "431" for this stop set;
        // Univers example 341 uses weight/width/slope digit mapping on those stops.
        let code = InstanceCodeBuilder.compose(
            axes: [wght, wdth, ital],
            coords: ["wdth": 100, "wght": 700],
            fileStatRegistration: ["ital": 1]
        )
        XCTAssertEqual(code, "341")
    }

    func testComposeFileSplitSlopeViaRegistrationItal() {
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 80, name: "Condensed", elidable: false, code: "1"),
            ]
        )
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 300, name: "Light", elidable: false, code: "1"),
            ]
        )
        let ital = AxisDefinition(
            tag: "ital",
            role: .designRecordOnly,
            values: [
                AxisValue(id: "i0", value: 0, name: "Roman", elidable: true, code: "0"),
                AxisValue(id: "i1", value: 1, name: "Italic", elidable: false, code: "1"),
            ]
        )

        XCTAssertEqual(
            InstanceCodeBuilder.compose(
                axes: [wdth, wght, ital],
                coords: ["wdth": 80, "wght": 300],
                fileStatRegistration: ["ital": 0]
            ),
            "110"
        )
        XCTAssertEqual(
            InstanceCodeBuilder.compose(
                axes: [wdth, wght, ital],
                coords: ["wdth": 80, "wght": 300],
                fileStatRegistration: ["ital": 1]
            ),
            "111"
        )
    }

    func testComposeIgnoresLegacyClarifierCodes() {
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 100, name: "Normal", elidable: false, code: "3"),
            ]
        )
        let role = FileRole.variant(
            masterFontID: "m",
            clarifiers: [FileClarifier(category: .width, label: "Wide", code: "9")]
        )
        XCTAssertEqual(
            InstanceCodeBuilder.compose(
                axes: [wdth],
                coords: ["wdth": 100],
                fileRole: role,
                namingOrder: ["@code", "wdth", "@width"]
            ),
            "3"
        )
    }

    func testComposeSkipsEmptyAndStatOnly() {
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .statOnly,
            values: [
                AxisValue(id: "w1", value: 100, name: "Normal", elidable: false, code: "9"),
            ]
        )
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 400, name: "Regular", elidable: false, code: "2"),
                AxisValue(id: "g2", value: 700, name: "Bold", elidable: false),
            ]
        )
        XCTAssertEqual(
            InstanceCodeBuilder.compose(axes: [wdth, wght], coords: ["wght": 400]),
            "2"
        )
        XCTAssertNil(
            InstanceCodeBuilder.compose(axes: [wdth, wght], coords: ["wght": 700])
        )
    }
}

final class CodeNamingComposerTests: XCTestCase {
    func testCodeChipEmitsConcatenatedCodeBeforeWords() {
        let wdth = AxisDefinition(
            tag: "wdth",
            role: .instance,
            values: [
                AxisValue(id: "w1", value: 100, name: "Normal", elidable: true, code: "4"),
            ]
        )
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 700, name: "Bold", elidable: false, code: "3"),
            ]
        )
        let ital = AxisDefinition(
            tag: "ital",
            role: .designRecordOnly,
            values: [
                AxisValue(id: "i1", value: 1, name: "Italic", elidable: false, code: "1"),
            ]
        )
        let naming = NamingPolicy(
            order: ["@pshyphen", "@code", "wght", "wdth", "ital"],
            elidedFallback: "Regular"
        )

        let result = NamingComposer.compose(
            coords: ["wdth": 100, "wght": 700],
            axes: [wght, wdth, ital],
            naming: naming,
            fileStatRegistration: ["ital": 1]
        )

        XCTAssertEqual(result.name, "341 Bold Italic")
        XCTAssertEqual(result.chain.first?.kind, .code)
        XCTAssertEqual(result.chain.first?.name, "341")
        XCTAssertTrue(result.chain.contains { $0.tag == "wdth" && $0.elided })
    }

    func testCodeTokenIsNotClarifier() {
        XCTAssertTrue(NamingToken.isCode("@code"))
        XCTAssertFalse(NamingToken.isClarifier("@code"))
        XCTAssertTrue(NamingToken.isSpecialToken("@code"))
        XCTAssertNil(NamingToken.clarifierCategory(for: "@code"))
    }

    func testMergedOrderPreservesCodeWithoutAutoAppend() {
        let withCode = NamingPolicy.mergedOrder(
            projectOrder: ["@pshyphen", "@code", "wght", "@width"],
            axisTags: ["wght", "wdth"]
        )
        XCTAssertTrue(withCode.contains("@code"))
        XCTAssertFalse(withCode.contains("@width"))
        XCTAssertTrue(withCode.contains("wdth"))
        XCTAssertEqual(withCode.firstIndex(of: "@code"), withCode.firstIndex(of: "@pshyphen").map { $0 + 1 })

        let without = NamingPolicy.mergedOrder(
            projectOrder: ["@pshyphen", "wght"],
            axisTags: ["wght"]
        )
        XCTAssertFalse(without.contains("@code"))
    }

    func testAxisValueCodeDecodesOptional() throws {
        let json = """
        {"id":"a","value":400,"name":"Regular","elidable":true}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AxisValue.self, from: json)
        XCTAssertNil(decoded.code)

        let withCode = """
        {"id":"a","value":400,"name":"Regular","elidable":false,"code":"2"}
        """.data(using: .utf8)!
        let decodedCode = try JSONDecoder().decode(AxisValue.self, from: withCode)
        XCTAssertEqual(decodedCode.code, "2")
    }

    func testPostScriptStyleIncludesCodeRelativeToHyphen() {
        let wght = AxisDefinition(
            tag: "wght",
            role: .instance,
            values: [
                AxisValue(id: "g1", value: 700, name: "Bold", elidable: false, code: "3"),
            ]
        )
        let naming = NamingPolicy(
            order: ["@code", "@pshyphen", "wght"],
            elidedFallback: "Regular"
        )
        let style = PostScriptNaming.composeStyleSegment(
            coords: ["wght": 700],
            axes: [wght],
            naming: naming
        )
        XCTAssertEqual(style, "3-Bold")
    }
}
