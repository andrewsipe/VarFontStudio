import XCTest
@testable import VarFontCore

final class AxisStopNamingDefaultsTests: XCTestCase {
    func testApplyAxisNeutralsOnlyRenamesWrongDefaultTokens() {
        var font = FontDocument(
            id: "nouveau",
            sourcePath: "/tmp/Nouveau-Variable.ttf",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 50, name: "Condensed", elidable: false),
                        AxisValue(id: "w2", value: 100, name: "Regular", elidable: true),
                        AxisValue(id: "w3", value: 150, name: "Expanded", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [
                        AxisValue(id: "g1", value: 400, name: "Regular", elidable: true),
                        AxisValue(id: "g2", value: 700, name: "Bold", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "ital",
                    role: .instance,
                    values: [
                        AxisValue(id: "i1", value: 0, name: "Regular", elidable: true),
                        AxisValue(id: "i2", value: 9, name: "Italic", elidable: false),
                    ]
                ),
            ]
        )

        AxisStopNamingDefaults.applyAxisNeutralsToAllInstanceAxes(font: &font)

        XCTAssertEqual(font.axes[0].values[1].name, "Normal")
        XCTAssertEqual(font.axes[0].values[0].name, "Condensed")
        XCTAssertEqual(font.axes[1].values[0].name, "Regular")
        XCTAssertEqual(font.axes[2].values[0].name, "Roman")
        XCTAssertEqual(font.axes[2].values[1].name, "Italic")
    }

    func testUniformStopNamesDetectedForNouveauLED() {
        let font = FontDocument(
            id: "led",
            sourcePath: "/tmp/NouveauLED-Variable.ttf",
            axes: [
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 0, name: "Regular", elidable: true),
                        AxisValue(id: "w2", value: 250, name: "Regular", elidable: true),
                    ]
                ),
            ]
        )
        XCTAssertTrue(AxisStopNamingDefaults.hasUniformStopNamesOnInstanceAxes(font))
    }

    func testNouveauIsNotUniformStopNames() {
        let font = FontDocument(
            id: "nouveau",
            sourcePath: "/tmp/Nouveau-Variable.ttf",
            axes: [
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [
                        AxisValue(id: "g1", value: 400, name: "Regular", elidable: true),
                        AxisValue(id: "g2", value: 700, name: "Bold", elidable: false),
                    ]
                ),
            ]
        )
        XCTAssertFalse(AxisStopNamingDefaults.hasUniformStopNamesOnInstanceAxes(font))
    }

    func testHasAxisNeutralMismatchDetectsCrossAxisRegular() {
        let font = FontDocument(
            id: "reflex",
            sourcePath: "/tmp/ReflexProVariable-Condensed.ttf",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 50, name: "Condensed", elidable: true),
                        AxisValue(id: "w2", value: 100, name: "Regular", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "ital",
                    role: .instance,
                    values: [
                        AxisValue(id: "i1", value: 0, name: "Regular", elidable: true),
                    ]
                ),
            ]
        )
        XCTAssertTrue(AxisStopNamingDefaults.hasAxisNeutralMismatch(font))
    }

    func testHasAxisNeutralMismatchFalseWhenNeutralsCorrect() {
        let font = FontDocument(
            id: "ok",
            sourcePath: "/tmp/ok.ttf",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [AxisValue(id: "w1", value: 100, name: "Normal", elidable: true)]
                ),
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [AxisValue(id: "g1", value: 400, name: "Regular", elidable: true)]
                ),
            ]
        )
        XCTAssertFalse(AxisStopNamingDefaults.hasAxisNeutralMismatch(font))
    }

    func testApplyAxisDefaultsSkipsAxesWithDescriptiveNames() {
        var font = FontDocument(
            id: "reflex",
            sourcePath: "/tmp/Reflex.ttf",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [
                        AxisValue(id: "w1", value: 50, name: "Condensed", elidable: false),
                        AxisValue(id: "w2", value: 100, name: "Normal", elidable: true),
                        AxisValue(id: "w3", value: 150, name: "Expanded", elidable: false),
                    ]
                ),
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [
                        AxisValue(id: "g1", value: 400, name: "Regular", elidable: true),
                        AxisValue(id: "g2", value: 700, name: "700", elidable: false),
                    ]
                ),
            ]
        )

        AxisStopNamingDefaults.applyAxisDefaultsToAllInstanceAxes(font: &font)

        XCTAssertEqual(font.axes[0].values[0].name, "Condensed")
        XCTAssertEqual(font.axes[0].values[1].name, "Normal")
        XCTAssertEqual(font.axes[0].values[2].name, "Expanded")
    }

    func testAxisNeutralMismatchDescriptionUsesActualLabels() {
        let font = FontDocument(
            id: "playfair",
            sourcePath: "/tmp/Playfair.ttf",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .instance,
                    values: [AxisValue(id: "w1", value: 100, name: "Normal", elidable: true)]
                ),
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [AxisValue(id: "g1", value: 400, name: "Normal", elidable: true)]
                ),
            ]
        )
        let details = AxisStopNamingDefaults.axisNeutralMismatchDescriptions(in: font)
        XCTAssertTrue(details.contains { $0.contains("wght") && $0.contains("Normal") && $0.contains("Regular") })
    }
}
