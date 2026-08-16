import XCTest
@testable import VarFontCore

final class SourceFontFingerprintTests: XCTestCase {
    func testRoundTripSerialization() {
        let fingerprint = SourceFontFingerprint(
            modifiedMilliseconds: 1_700_000_000_123,
            fileSize: 2_048_576,
            fvarDesignSpace: "opsz:5:14:1200,wght:100:400:900"
        )
        let parsed = SourceFontFingerprint.parse(fingerprint.serialized)
        XCTAssertEqual(parsed, fingerprint)
    }

    func testParseRejectsGarbage() {
        XCTAssertNil(SourceFontFingerprint.parse(nil))
        XCTAssertNil(SourceFontFingerprint.parse(""))
        XCTAssertNil(SourceFontFingerprint.parse("not-a-fingerprint"))
        XCTAssertNil(SourceFontFingerprint.parse("v1;f=wght:100:400:900"))
    }

    func testFvarTokenFromAnalysisIgnoresDesignRecordOnly() {
        let analysis = makeAnalysis(
            axes: [
                .init(
                    tag: "wght",
                    displayName: "Weight",
                    min: 100,
                    default: 400,
                    max: 900,
                    roleInferred: .instance,
                    variesInExistingInstances: true,
                    valuesExisting: []
                ),
                .init(
                    tag: "ital",
                    displayName: "Italic",
                    min: 0,
                    default: 0,
                    max: 1,
                    roleInferred: .designRecordOnly,
                    variesInExistingInstances: false,
                    valuesExisting: []
                ),
            ]
        )
        XCTAssertEqual(
            SourceFontFingerprint.fvarToken(from: analysis),
            "wght:100:400:900"
        )
    }

    func testProbeMissingBaselineDoesNotWarn() {
        let analysis = makeAnalysis(axes: [
            .init(
                tag: "wght",
                displayName: "Weight",
                min: 100,
                default: 400,
                max: 900,
                roleInferred: .instance,
                variesInExistingInstances: true,
                valuesExisting: []
            ),
        ])
        let url = URL(fileURLWithPath: "/tmp/missing-baseline-probe.ttf")
        // capture may fail without a real font file — probe should still report missing baseline
        // when stored is nil, even if current is nil.
        let probe = SourceFontFingerprint.probe(stored: nil, url: url, analysis: analysis)
        XCTAssertTrue(probe.missingBaseline)
        XCTAssertFalse(probe.hasDrift)
        XCTAssertTrue(probe.warnings.isEmpty)
    }

    func testProbeDetectsIdentityAndDesignSpaceDrift() {
        let baseline = SourceFontFingerprint(
            modifiedMilliseconds: 1000,
            fileSize: 100,
            fvarDesignSpace: "wght:100:400:900"
        )
        let identityOnly = SourceFontFingerprint(
            modifiedMilliseconds: 2000,
            fileSize: 100,
            fvarDesignSpace: "wght:100:400:900"
        )
        let designChanged = SourceFontFingerprint(
            modifiedMilliseconds: 2000,
            fileSize: 120,
            fvarDesignSpace: "wght:200:400:800"
        )

        let identityProbe = SourceFontFingerprint.compare(
            stored: baseline.serialized,
            current: identityOnly
        )
        XCTAssertTrue(identityProbe.fileIdentityChanged)
        XCTAssertFalse(identityProbe.designSpaceChanged)
        XCTAssertEqual(identityProbe.warnings.map(\.code), ["source_file_changed"])

        let designProbe = SourceFontFingerprint.compare(
            stored: baseline.serialized,
            current: designChanged
        )
        XCTAssertTrue(designProbe.designSpaceChanged)
        XCTAssertEqual(designProbe.warnings.map(\.code), ["source_design_space_changed"])
    }

    func testMergeWarningsInsertsAtFrontWithoutDuplicates() {
        var result = CommitResult(
            schemaVersion: 1,
            requestID: "r1",
            ok: true,
            outputPath: nil,
            dryRun: true,
            summary: nil,
            diff: nil,
            validation: nil,
            warnings: [
                PlanWarning(code: "other", message: "existing"),
            ],
            errors: []
        )
        let probe = SourceFontFingerprint.ProbeResult(
            missingBaseline: false,
            fileIdentityChanged: true,
            designSpaceChanged: true,
            current: nil
        )
        SourceFontFingerprint.mergeWarnings(into: &result, probe: probe)
        SourceFontFingerprint.mergeWarnings(into: &result, probe: probe)
        XCTAssertEqual(result.warnings.map(\.code), ["source_design_space_changed", "other"])
    }

    // MARK: - Helpers

    private func makeAnalysis(axes: [FontAnalysis.AnalyzedAxis]) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(
                path: "/tmp/font.ttf",
                format: "ttf",
                familyName: "Test",
                fullName: "Test",
                isVariable: true
            ),
            readiness: .init(
                hasFvar: true,
                hasStat: true,
                hasDesignAxisRecord: true,
                writable: true,
                blockers: []
            ),
            axes: axes,
            statValues: [],
            compoundStatValues: [],
            instancesExisting: [],
            nameAudit: .init(freeStart: 256, used: []),
            inferred: .init(
                isItalicFont: false,
                gridAxisTags: axes.map(\.tag),
                namingOrderSuggested: axes.map(\.tag)
            )
        )
    }
}
