import XCTest
@testable import VarFontCore

final class NamingComposerClarifierTests: XCTestCase {
    func testSlopeClarifierAppendsToWeightName() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                role: .instance,
                values: [
                    AxisValue(id: "w1", value: 500, name: "Medium", elidable: false),
                    AxisValue(id: "w2", value: 400, name: "Regular", elidable: true)
                ]
            )
        ]
        let naming = NamingPolicy(
            order: ["wght", NamingPolicy.clarifierTokenSlope],
            elidedFallback: "Regular"
        )
        let role = FileRole.variant(
            masterFontID: "master",
            clarifiers: [FileClarifier(category: .slope, label: "Italic")]
        )

        let medium = NamingComposer.compose(
            coords: ["wght": 500],
            axes: axes,
            naming: naming,
            fileRole: role
        )
        XCTAssertEqual(medium.name, "Medium Italic")

        let regular = NamingComposer.compose(
            coords: ["wght": 400],
            axes: axes,
            naming: naming,
            fileRole: role
        )
        XCTAssertEqual(regular.name, "Italic")
    }

    func testWidthAndSlopeCombined() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                role: .instance,
                values: [
                    AxisValue(id: "w1", value: 700, name: "Bold", elidable: false)
                ]
            )
        ]
        let naming = NamingPolicy(
            order: ["wght", NamingPolicy.clarifierTokenWidth, NamingPolicy.clarifierTokenSlope],
            elidedFallback: "Regular"
        )
        let role = FileRole.variant(
            masterFontID: "master",
            clarifiers: [
                FileClarifier(category: .width, label: "Condensed"),
                FileClarifier(category: .slope, label: "Italic")
            ]
        )

        let composed = NamingComposer.compose(
            coords: ["wght": 700],
            axes: axes,
            naming: naming,
            fileRole: role
        )
        XCTAssertEqual(composed.name, "Bold Condensed Italic")
    }

    func testWidthClarifierSkippedWhenWdthRegistrationPresent() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                role: .instance,
                values: [
                    AxisValue(id: "w1", value: 700, name: "Bold", elidable: false)
                ]
            ),
            AxisDefinition(
                tag: "wdth",
                role: .designRecordOnly,
                values: [
                    AxisValue(id: "n1", value: 75, name: "Condensed", elidable: false)
                ]
            ),
        ]
        let naming = NamingPolicy(
            order: ["wght", "wdth", NamingPolicy.clarifierTokenWidth],
            elidedFallback: "Regular"
        )
        let role = FileRole.variant(
            masterFontID: "master",
            clarifiers: [FileClarifier(category: .width, label: "Narrow")]
        )

        let composed = NamingComposer.compose(
            coords: ["wght": 700],
            axes: axes,
            naming: naming,
            fileRole: role,
            fileStatRegistration: ["wdth": 75]
        )
        XCTAssertEqual(composed.name, "Bold Condensed")
        XCTAssertFalse(composed.chain.contains { $0.kind == .clarifier })
    }
}
