import XCTest
@testable import VarFontCore

final class SlopeAxisPolicyTests: XCTestCase {
    func testOutOfNamingCaptionForPassiveItal() {
        let axes = [
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            registrationAxis(tag: "ital", value: 1, name: "Italic"),
        ]
        XCTAssertEqual(
            SlopeAxisPolicy.outOfNamingCaption(tag: "ital", axes: axes),
            "file label · naming uses slnt"
        )
        XCTAssertNil(SlopeAxisPolicy.outOfNamingCaption(tag: "slnt", axes: axes))
        XCTAssertTrue(SlopeAxisPolicy.isExcludedFromNaming(tag: "ital", axes: axes))
    }

    func testImportPromptForPassiveItal() {
        let axes = [
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            registrationAxis(tag: "ital", value: 1, name: "Italic"),
        ]
        let prompt = try! XCTUnwrap(SlopeAxisPolicy.importPrompt(axes: axes))
        XCTAssertEqual(prompt.ownerTag, "slnt")
        XCTAssertEqual(prompt.passiveTag, "ital")
        XCTAssertEqual(prompt.recommended, .keepSTATOutOfNaming)
    }

    func testApplyOmitFromExportRemovesPassiveItal() {
        var font = FontDocument(
            id: "rt",
            sourcePath: "/tmp/Rooftop.ttf",
            axes: [
                instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
                AxisDefinition(
                    tag: "ital",
                    role: .designRecordOnly,
                    values: [AxisValue(id: "i", value: 1, name: "Italic", elidable: false)]
                ),
            ],
            fileStatRegistration: ["ital": 1],
            statDesignAxisTags: ["slnt", "ital"]
        )
        var naming = NamingPolicy(order: ["@pshyphen", "slnt", "ital"])
        let prompt = try! XCTUnwrap(SlopeAxisPolicy.importPrompt(axes: font.axes))
        SlopeAxisPolicy.applyImportChoice(.omitFromExport, prompt: prompt, to: &font, naming: &naming)
        XCTAssertNil(font.axes.first { $0.tag == "ital" })
        XCTAssertNil(font.fileStatRegistration["ital"])
        XCTAssertFalse(font.statDesignAxisTags.contains("ital"))
        XCTAssertFalse(naming.order.contains("ital"))
    }

    func testApplyIncludeInNamingForcesPassiveItal() {
        var font = FontDocument(
            id: "rt",
            sourcePath: "/tmp/Rooftop.ttf",
            axes: [
                instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
                AxisDefinition(
                    tag: "ital",
                    role: .designRecordOnly,
                    values: [AxisValue(id: "i", value: 1, name: "Italic", elidable: true)]
                ),
            ]
        )
        var naming = NamingPolicy(order: ["@pshyphen", "slnt"])
        let prompt = try! XCTUnwrap(SlopeAxisPolicy.importPrompt(axes: font.axes))
        SlopeAxisPolicy.applyImportChoice(.includeInNaming, prompt: prompt, to: &font, naming: &naming)
        XCTAssertTrue(naming.slopeNamingIncludeTags.contains("ital"))
        XCTAssertTrue(naming.order.contains("ital"))
        XCTAssertNil(SlopeAxisPolicy.outOfNamingCaption(
            tag: "ital",
            axes: font.axes,
            forceInclude: Set(naming.slopeNamingIncludeTags)
        ))
    }

    func testSlntOwnsWhenItalIsRegistrationOnly() {
        let axes = [
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            registrationAxis(tag: "ital", value: 0, name: "Roman"),
        ]
        let decision = SlopeAxisPolicy.decide(axes: axes)
        XCTAssertEqual(decision.ownership, .slntOwns)
        XCTAssertEqual(decision.slnt, .active)
        XCTAssertEqual(decision.ital, .passive)
        XCTAssertEqual(decision.namingTagsToExclude, ["ital"])
        XCTAssertTrue(decision.suppressItalRegistrationIssues)
    }

    func testItalOwnsWhenSlntAbsent() {
        let axes = [
            instanceAxis(tag: "ital", values: [0, 1], names: ["Roman", "Italic"]),
        ]
        let decision = SlopeAxisPolicy.decide(axes: axes)
        XCTAssertEqual(decision.ownership, .italOwns)
        XCTAssertEqual(decision.namingTagsToExclude, [])
        XCTAssertFalse(decision.suppressItalRegistrationIssues)
    }

    func testDualWhenBothVary() {
        let axes = [
            instanceAxis(tag: "slnt", values: [-12, 0, 12], names: ["Reverse", "Upright", "Oblique"]),
            instanceAxis(tag: "ital", values: [0, 1], names: ["Roman", "Italic"]),
        ]
        let decision = SlopeAxisPolicy.decide(axes: axes)
        XCTAssertEqual(decision.ownership, .dual)
        XCTAssertTrue(decision.namingTagsToExclude.isEmpty)
        XCTAssertTrue(decision.emitDualOwnerNotice)
    }

    func testNonBinaryItalBesideActiveSlntDefersToSlnt() {
        let ital = AxisDefinition(
            tag: "ital",
            displayName: "Italic",
            min: -12,
            default: -12,
            max: -12,
            role: .statOnly,
            values: [AxisValue(id: "i", value: -12, name: "Italic", elidable: false)]
        )
        let axes = [
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            ital,
        ]
        XCTAssertTrue(RegistrationAxisSupport.isNonBinaryItalAxis(ital))
        let decision = SlopeAxisPolicy.decide(axes: axes)
        XCTAssertEqual(decision.ownership, .slntOwns)
        XCTAssertEqual(decision.ital, .nonBinaryItal)
        XCTAssertEqual(decision.namingTagsToExclude, ["ital"])
    }

    func testNonBinaryItalAloneIsItalAsSlope() {
        let ital = AxisDefinition(
            tag: "ital",
            displayName: "Italic",
            min: -12,
            default: -12,
            max: -12,
            role: .statOnly,
            values: [AxisValue(id: "i", value: -12, name: "Italic", elidable: false)]
        )
        let decision = SlopeAxisPolicy.decide(axes: [ital])
        XCTAssertEqual(decision.ownership, .italAsSlope)
        XCTAssertEqual(decision.ital, .nonBinaryItal)
    }

    func testEffectiveNamingOrderDropsPassiveItal() {
        let axes = [
            instanceAxis(tag: "wght", values: [400, 700], names: ["Regular", "Bold"]),
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            registrationAxis(tag: "ital", value: 0, name: "Roman"),
        ]
        let order = SlopeAxisPolicy.effectiveNamingOrder(
            ["wght", "slnt", "ital"],
            axes: axes
        )
        XCTAssertEqual(order, ["wght", "slnt"])
    }

    func testNamingOrderMergeDoesNotReintroducePassiveItal() {
        let axes = [
            instanceAxis(tag: "wght", values: [400, 700], names: ["Regular", "Bold"]),
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            registrationAxis(tag: "ital", value: 1, name: "Italic"),
        ]
        // Project order omitted ital, but mergedOrder would append every axis tag.
        let order = SlopeAxisPolicy.namingOrder(projectOrder: ["wght", "slnt"], axes: axes)
        XCTAssertEqual(order, ["@pshyphen", "wght", "slnt"])
        XCTAssertFalse(order.contains("ital"))
    }

    func testApplyPassiveItalElisionWhenSlntOwns() {
        var font = FontDocument(
            id: "rt",
            sourcePath: "/tmp/Rooftop.ttf",
            axes: [
                instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
                AxisDefinition(
                    tag: "ital",
                    role: .designRecordOnly,
                    values: [
                        AxisValue(id: "ital-0", value: 1, name: "Italic", elidable: false),
                    ]
                ),
            ]
        )
        XCTAssertTrue(SlopeAxisPolicy.applyPassiveItalElision(to: &font))
        XCTAssertEqual(font.axes.first { $0.tag == "ital" }?.values.first?.elidable, true)
        XCTAssertFalse(SlopeAxisPolicy.applyPassiveItalElision(to: &font))
    }

    func testPostScriptOmitsPassiveItalWhenSlntOwns() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                min: 1,
                default: 400,
                max: 400,
                role: .instance,
                values: [
                    AxisValue(id: "t", value: 1, name: "Thin", elidable: false),
                    AxisValue(id: "r", value: 400, name: "Regular", elidable: true),
                ]
            ),
            instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
            AxisDefinition(
                tag: "ital",
                role: .designRecordOnly,
                values: [
                    AxisValue(id: "ital-0", value: 1, name: "Italic", elidable: false),
                ]
            ),
        ]
        let naming = NamingPolicy(order: ["@pshyphen", "wght", "slnt", "ital"])
        let upright = PostScriptNaming.composeInstanceName(
            familyPrefix: "RooftopVariable",
            coords: ["wght": 1, "slnt": 0],
            axes: axes,
            naming: naming,
            fileStatRegistration: ["ital": 1]
        )
        XCTAssertEqual(upright, "RooftopVariable-Thin")
        XCTAssertFalse(upright.localizedCaseInsensitiveContains("Italic"))

        let italic = PostScriptNaming.composeInstanceName(
            familyPrefix: "RooftopVariable",
            coords: ["wght": 1, "slnt": 10],
            axes: axes,
            naming: naming,
            fileStatRegistration: ["ital": 1]
        )
        XCTAssertEqual(italic, "RooftopVariable-ThinItalic")
    }

    func testPlannerSuppressesItalRegistrationWarningsWhenSlntOwns() {
        var font = FontDocument(
            id: "f1",
            sourcePath: "/tmp/Rooftop-Variable.ttf",
            dirty: false,
            axes: [
                instanceAxis(tag: "wght", values: [400], names: ["Regular"]),
                instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
                registrationAxis(tag: "ital", value: 0, name: "Italic"), // mismatch on upright file
            ],
            fileStatRegistration: ["ital": 0]
        )
        font.inferredIsItalicFile = false

        let warnings = RegistrationAxisSupport.allRegistrationPlanWarnings(font: font)
        XCTAssertFalse(warnings.contains { $0.code == "registration_mismatch" })
        XCTAssertFalse(warnings.contains { $0.code == "ital_format1_upgrade" })
    }

    func testCoexistenceWarningOnlyForDual() {
        let dualFont = FontDocument(
            id: "dual",
            sourcePath: "/tmp/Dual.ttf",
            axes: [
                instanceAxis(tag: "slnt", values: [-12, 0], names: ["Reverse", "Upright"]),
                instanceAxis(tag: "ital", values: [0, 1], names: ["Roman", "Italic"]),
            ]
        )
        let dualWarnings = OpenTypeAxisAudit.italSlntCoexistenceWarnings(
            font: dualFont,
            namingOrder: ["slnt", "ital"]
        )
        XCTAssertEqual(dualWarnings.count, 1)

        let rooftop = FontDocument(
            id: "rt",
            sourcePath: "/tmp/Rooftop.ttf",
            axes: [
                instanceAxis(tag: "slnt", values: [0, 10], names: ["Upright", "Italic"]),
                registrationAxis(tag: "ital", value: 0, name: "Roman"),
            ]
        )
        let rooftopWarnings = OpenTypeAxisAudit.italSlntCoexistenceWarnings(
            font: rooftop,
            namingOrder: ["slnt", "ital"]
        )
        XCTAssertTrue(rooftopWarnings.isEmpty)
    }

    func testNamingOrderInferenceOmitsStatOnlyItalWhenSlntOnGrid() {
        let order = NamingOrderInference.suggest(
            designAxes: [
                StatDesignAxis(tag: "wght", nameID: 256, ordering: 0),
                StatDesignAxis(tag: "slnt", nameID: 257, ordering: 1),
                StatDesignAxis(tag: "ital", nameID: 258, ordering: 2),
            ],
            fvarAxisTags: ["wght", "slnt"],
            gridAxisTags: ["wght", "slnt"]
        )
        XCTAssertEqual(order, ["wght", "slnt"])
        XCTAssertFalse(order.contains("ital"))
    }

    // MARK: - Fixtures

    private func instanceAxis(tag: String, values: [Double], names: [String]) -> AxisDefinition {
        AxisDefinition(
            tag: tag,
            displayName: tag,
            min: values.min(),
            default: values.first,
            max: values.max(),
            role: .instance,
            values: zip(values, names).enumerated().map { index, pair in
                AxisValue(
                    id: "\(tag)-\(index)",
                    value: pair.0,
                    name: pair.1,
                    elidable: index == 0
                )
            }
        )
    }

    private func registrationAxis(tag: String, value: Double, name: String) -> AxisDefinition {
        AxisDefinition(
            tag: tag,
            displayName: tag,
            min: nil,
            default: nil,
            max: nil,
            role: .designRecordOnly,
            values: [
                AxisValue(id: "\(tag)-0", value: value, name: name, elidable: true, statFormat: 1),
            ]
        )
    }
}
