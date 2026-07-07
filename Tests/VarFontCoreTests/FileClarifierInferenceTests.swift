import XCTest
@testable import VarFontCore

final class FileClarifierInferenceTests: XCTestCase {
    func testPlayfairInstanceAxesSkipWidthAndOptical() throws {
        let analysis = try FixtureLoader.decode(FontAnalysis.self, from: "playfair-roman-analysis.json")
        let axes = analysis.axes.map { ProjectImporter.axisDefinition(from: $0) }
        let font = FontDocument(
            id: "roman",
            sourcePath: "/tmp/Playfair-VariableFont-Micro-SemiCond-SemiBold.woff2",
            axes: axes,
            fileStatRegistration: ["ital": 0]
        )

        let skipped = FileClarifierInference.skippedCategories(font: font)
        XCTAssertTrue(skipped.contains(.width))
        XCTAssertTrue(skipped.contains(.optical))
        XCTAssertTrue(skipped.contains(.slope))

        let result = FileClarifierInference.infer(
            sourceURL: URL(fileURLWithPath: font.sourcePath),
            analysis: analysis,
            font: font
        )
        XCTAssertTrue(result.clarifiers.isEmpty)
    }

    func testWidthUsesStopNameNotExpansion() {
        let font = FontDocument(
            id: "condensed",
            sourcePath: "/tmp/Family-SemiCond-Italic.woff2",
            axes: [
                AxisDefinition(
                    tag: "wdth",
                    role: .designRecordOnly,
                    values: [
                        AxisValue(id: "w1", value: 87.5, name: "SemiCond", elidable: false),
                        AxisValue(id: "w2", value: 100, name: "Normal", elidable: true)
                    ]
                )
            ],
            fileStatRegistration: [:]
        )

        let result = FileClarifierInference.infer(
            sourceURL: URL(fileURLWithPath: font.sourcePath),
            analysis: nil,
            font: font
        )
        XCTAssertEqual(
            result.clarifiers.first { $0.category == .width }?.label,
            "SemiCond"
        )
    }

    func testSlopeFromFilenameWhenNoItalAxis() {
        let font = FontDocument(
            id: "italic",
            sourcePath: "/tmp/PlayfairItalicVF.woff2",
            axes: [
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [AxisValue(id: "w1", value: 400, name: "Regular", elidable: true)]
                )
            ]
        )

        let result = FileClarifierInference.infer(
            sourceURL: URL(fileURLWithPath: font.sourcePath),
            analysis: nil,
            font: font
        )
        XCTAssertEqual(
            result.clarifiers.first { $0.category == .slope }?.label,
            "Italic"
        )
    }

    func testVariantImportDoesNotAutoSeedClarifiers() throws {
        var project = try FixtureLoader.decode(ProjectDocument.self, from: "playfair-family-project.json")
        let analysis = try FixtureLoader.decode(FontAnalysis.self, from: "playfair-italic-analysis.json")
        let sourceURL = URL(fileURLWithPath: "/tmp/Playfair-VariableFont-Micro-SemiCond-Italic.woff2")

        ProjectImporter.addFont(analysis, sourceURL: sourceURL, to: &project)

        let added = project.fonts.last
        XCTAssertEqual(added?.fileRole?.kind, .variant)
        XCTAssertTrue(added?.fileRole?.clarifiers.isEmpty ?? false)
    }

    func testPlayfairSlotStatesPreferCoverageOverReadOnlyMaster() throws {
        let analysis = try FixtureLoader.decode(FontAnalysis.self, from: "playfair-roman-analysis.json")
        let axes = analysis.axes.map { ProjectImporter.axisDefinition(from: $0) }
        let font = FontDocument(
            id: "roman",
            sourcePath: "/tmp/PlayfairRomanVF.woff2",
            fileRole: .master(),
            axes: axes,
            fileStatRegistration: ["ital": 0]
        )

        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .slope, font: font, projectFontCount: 2),
            .coveredByRegistration(axisTag: "ital")
        )
        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .width, font: font, projectFontCount: 2),
            .coveredByInstanceAxis(axisTag: "wdth")
        )
        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .optical, font: font, projectFontCount: 2),
            .coveredByInstanceAxis(axisTag: "opsz")
        )
        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .custom, font: font, projectFontCount: 2),
            .readOnlyMaster
        )
    }

    func testReadOnlyMasterWhenNoAxisCoverage() {
        let font = FontDocument(
            id: "master",
            sourcePath: "/tmp/Master.woff2",
            fileRole: .master(),
            axes: [
                AxisDefinition(
                    tag: "wght",
                    role: .instance,
                    values: [AxisValue(id: "w1", value: 400, name: "Regular", elidable: true)]
                )
            ]
        )

        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .width, font: font, projectFontCount: 2),
            .readOnlyMaster
        )
        XCTAssertEqual(
            ClarifierSlotCoverage.slotState(category: .width, font: font, projectFontCount: 1),
            .editable
        )
    }
}
