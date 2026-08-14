import XCTest
@testable import VarFontCore

final class ElidedFallbackResolverTests: XCTestCase {
    func testRomanResolvesToRegularWhenAllElidable() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                role: .instance,
                values: [
                    AxisValue(id: "w1", value: 400, name: "Regular", elidable: true),
                    AxisValue(id: "w2", value: 700, name: "Bold", elidable: false),
                ]
            ),
            AxisDefinition(
                tag: "ital",
                role: .designRecordOnly,
                values: [
                    AxisValue(id: "i0", value: 0, name: "Roman", elidable: true),
                ]
            ),
        ]
        let result = ElidedFallbackResolver.resolve(
            axes: axes,
            namingOrder: ["ital", "wght"],
            fileStatRegistration: ["ital": 0],
            sourceElidedFallback: "Regular",
            fileRole: nil
        )
        XCTAssertEqual(result.value, "Regular")
        XCTAssertFalse(result.inferred)
    }

    func testInferredWhenNoSourceFallback() {
        let axes = [
            AxisDefinition(
                tag: "wght",
                role: .instance,
                values: [AxisValue(id: "w1", value: 400, name: "Regular", elidable: true)]
            ),
        ]
        let result = ElidedFallbackResolver.resolve(
            axes: axes,
            namingOrder: ["wght"],
            fileStatRegistration: [:],
            sourceElidedFallback: nil,
            fileRole: nil
        )
        XCTAssertEqual(result.value, "Regular")
        XCTAssertTrue(result.inferred)
    }
}

final class StatParserFormat4Tests: XCTestCase {
    func testParsesFormat4CompoundEntry() throws {
        var data = Data()
        func appendUInt16(_ v: UInt16) {
            data.append(UInt8((v >> 8) & 0xFF))
            data.append(UInt8(v & 0xFF))
        }
        func appendUInt32(_ v: UInt32) {
            data.append(UInt8((v >> 24) & 0xFF))
            data.append(UInt8((v >> 16) & 0xFF))
            data.append(UInt8((v >> 8) & 0xFF))
            data.append(UInt8(v & 0xFF))
        }
        func appendFixed(_ value: Double) {
            let fixed = Int32(value * 65536.0)
            appendUInt32(UInt32(bitPattern: fixed))
        }
        func appendTag(_ tag: String) {
            data.append(contentsOf: Array(tag.utf8.prefix(4)))
        }

        // STAT 1.2 header — two design axes, one Format 4 value.
        appendUInt32(0x0001_0002)
        appendUInt16(8) // designAxisSize
        appendUInt16(2) // designAxisCount
        appendUInt32(20) // designAxesOffset
        appendUInt16(1) // axisValueCount
        appendUInt32(36) // axisValueOffsets
        appendUInt16(2) // elidedFallbackNameID

        // Design axes at 20
        appendTag("opsz")
        appendUInt16(256)
        appendUInt16(0)
        appendTag("wght")
        appendUInt16(257)
        appendUInt16(1)

        // AxisValue offset array at 36 — first record 2 bytes later
        appendUInt16(2)

        // Format 4 at 38: flags/nameID before interleaved AxisValueRecords
        appendUInt16(4) // format
        appendUInt16(2) // axisCount
        appendUInt16(0) // flags
        appendUInt16(300) // valueNameID
        appendUInt16(0) // opsz index
        appendFixed(100)
        appendUInt16(1) // wght index
        appendFixed(1)

        guard let parsed = StatParser.parse(data) else {
            XCTFail("parse returned nil")
            return
        }
        XCTAssertEqual(parsed.designAxes.map(\.tag), ["opsz", "wght"])
        XCTAssertEqual(parsed.values.count, 0)
        XCTAssertEqual(parsed.compoundValues.count, 1)
        let compound = try XCTUnwrap(parsed.compoundValues.first)
        XCTAssertEqual(compound.nameID, 300)
        XCTAssertEqual(compound.axisIndices, [0, 1])
        XCTAssertEqual(compound.axisValues[0], 100, accuracy: 0.001)
        XCTAssertEqual(compound.axisValues[1], 1, accuracy: 0.001)
    }

    func testParsesFormat4FromLivePatchedInterchange() throws {
        let path = "/Users/skymacbook/Downloads/_Fonts/WOFF2/New Folder With Items/Motaitalic/converted/Interchange-Variable-patched.ttf"
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("patched Interchange not on disk")
        }
        let analysis = try FontAnalysisReader.analyze(url: URL(fileURLWithPath: path))
        XCTAssertEqual(analysis.compoundStatValues.count, 16)
        XCTAssertFalse(analysis.compoundStatValues.contains { $0.coords.keys.contains("?") })
        XCTAssertTrue(analysis.compoundStatValues.contains { compound in
            compound.coords["opsz"] != nil && compound.coords["wght"] != nil
        })
        let posterExtrathin = analysis.compoundStatValues.first {
            $0.name.localizedCaseInsensitiveContains("Poster")
                && $0.name.localizedCaseInsensitiveContains("Thin")
                && ($0.coords["wght"] ?? 100) < 10
        }
        XCTAssertNotNil(posterExtrathin)
        XCTAssertEqual(posterExtrathin?.coords["opsz"] ?? 0, 100, accuracy: 0.01)
    }
}
