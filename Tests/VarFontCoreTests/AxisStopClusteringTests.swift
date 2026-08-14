import XCTest
@testable import VarFontCore

/// Fixture mirrors Interchange-Variable.ttf's real coordinates: a 2-axis (wght, opsz) font
/// where wght is opsz-compensated — the same named weight sits at different wght coordinates
/// per optical size, with the spread shrinking from Thin to Black. Numbers are the font's own,
/// captured from a live fontTools read, not invented.
final class AxisStopClusteringTests: XCTestCase {
    // opsz: Micro 1.0, unlabeled 19.73, Title 54.51, Poster 100.0
    private static let opszByRole = ["Micro": 1.0, "": 19.73, "Title": 54.51, "Poster": 100.0]

    // wght per weight name, in [Micro, unlabeled, Title, Poster] order.
    private static let weightLadder: [String: [Double]] = [
        "Extra Thin": [15.01, 10.36, 5.66, 1.00],
        "Thin": [20.26, 15.24, 10.18, 5.16],
        "Extra Light": [28.08, 23.02, 17.91, 12.80],
        "Light": [37.55, 32.73, 27.99, 23.24],
        "Regular": [48.12, 44.02, 39.91, 35.80],
        "Medium": [59.25, 55.92, 52.55, 49.18],
        "Bold": [69.95, 67.65, 65.38, 63.08],
        "Extra Bold": [80.80, 79.37, 77.94, 76.51],
        "Black": [90.45, 89.94, 89.43, 88.92],
        "Extra Black": [100.00, 100.00, 100.00, 100.00],
    ]

    private func interchangeInstances() -> [FontAnalysis.ExistingInstance] {
        let roles = ["Micro", "", "Title", "Poster"]
        var instances: [FontAnalysis.ExistingInstance] = []
        for (weightName, values) in Self.weightLadder {
            for (index, role) in roles.enumerated() {
                let wght = values[index]
                let opsz = Self.opszByRole[role]!
                let name = role.isEmpty ? weightName : "\(role) \(weightName)"
                instances.append(
                    FontAnalysis.ExistingInstance(
                        key: InstanceKeyBuilder.makeKey(coords: ["wght": wght, "opsz": opsz]),
                        composedName: name,
                        coords: ["wght": wght, "opsz": opsz],
                        subfamilyNameID: 0,
                        postscriptNameID: 0
                    )
                )
            }
        }
        return instances
    }

    private func makeAnalysis(instances: [FontAnalysis.ExistingInstance]) -> FontAnalysis {
        FontAnalysis(
            schemaVersion: 1,
            source: .init(path: "/tmp/Interchange.ttf", format: "ttf", familyName: "Interchange", fullName: "Interchange", isVariable: true),
            readiness: .init(hasFvar: true, hasStat: true, hasDesignAxisRecord: true, writable: true, blockers: []),
            axes: [],
            statValues: [],
            instancesExisting: instances,
            nameAudit: .init(freeStart: 256, used: []),
            inferred: .init(isItalicFont: false, gridAxisTags: ["wght", "opsz"], namingOrderSuggested: ["opsz", "wght"])
        )
    }

    func testWeightClustersMergeOpszCompensatedCoordinates() {
        let analysis = makeAnalysis(instances: interchangeInstances())
        let result = try! XCTUnwrap(
            AxisStopClustering.classify(axisTag: "wght", instanceTags: ["wght", "opsz"], analysis: analysis)
        )

        XCTAssertEqual(result.clusters.count, 10, "expected one cluster per named weight, not per coordinate")
        let black = try! XCTUnwrap(result.cluster(named: "Black"))
        XCTAssertEqual(black.values.count, 4)
        XCTAssertEqual(black.span, 90.45 - 88.92, accuracy: 0.01)

        let extraThin = try! XCTUnwrap(result.cluster(named: "Extra Thin"))
        XCTAssertEqual(extraThin.values.count, 4)
        XCTAssertEqual(extraThin.span, 15.01 - 1.00, accuracy: 0.01)
    }

    func testOpszClustersStayUnivariateWithNoEntanglement() {
        let analysis = makeAnalysis(instances: interchangeInstances())
        let result = try! XCTUnwrap(
            AxisStopClustering.classify(axisTag: "opsz", instanceTags: ["wght", "opsz"], analysis: analysis)
        )

        XCTAssertFalse(result.hasEntanglement, "opsz repeats cleanly across weights — nothing should be held back")
        XCTAssertEqual(Set(result.clusters.map(\.name)), result.promoteNames)

        // Direct-labeling should recover the font's real optical names, not numeric fallbacks.
        XCTAssertNotNil(result.clusterName(for: 1.0))
        XCTAssertEqual(result.clusterName(for: 1.0), "Micro")
        XCTAssertEqual(result.clusterName(for: 54.51), "Title")
        XCTAssertEqual(result.clusterName(for: 100.0), "Poster")
    }

    func testCleanWeightsPromoteAndLightWeightsStayComboOnly() {
        let analysis = makeAnalysis(instances: interchangeInstances())
        let result = try! XCTUnwrap(
            AxisStopClustering.classify(axisTag: "wght", instanceTags: ["wght", "opsz"], analysis: analysis)
        )

        XCTAssertTrue(result.hasEntanglement, "the light end should hold something back")

        // Tight heavies + gray band: one Format 1 stop each is honest enough.
        for name in ["Extra Black", "Black", "Extra Bold", "Bold", "Medium", "Regular"] {
            XCTAssertTrue(result.promoteNames.contains(name), "\(name) should promote")
        }

        // Extra Thin's range (1.00–15.01) overlaps Thin's (5.16–20.26) — collapsing either to one
        // Format 1 stop would land on top of a real, differently-named instance.
        for name in ["Extra Thin", "Thin", "Extra Light", "Light"] {
            XCTAssertFalse(result.promoteNames.contains(name), "\(name) overlaps a neighbor — must not promote")
        }
    }

    func testSingleClusterAlwaysPromotes() {
        let instances = [
            FontAnalysis.ExistingInstance(
                key: "a", composedName: "Regular", coords: ["wght": 400], subfamilyNameID: 0, postscriptNameID: 0
            ),
        ]
        let analysis = makeAnalysis(instances: instances)
        let result = try! XCTUnwrap(
            AxisStopClustering.classify(axisTag: "wght", instanceTags: ["wght"], analysis: analysis)
        )
        XCTAssertFalse(result.hasEntanglement)
        XCTAssertEqual(result.promoteNames, Set(result.clusters.map(\.name)))
    }
}
