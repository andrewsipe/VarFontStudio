import XCTest
@testable import VarFontCore

final class AxisTreeMergeTests: XCTestCase {
    private func wghtAxis(values: [AxisValue]) -> AxisDefinition {
        AxisDefinition(
            tag: "wght",
            min: 360,
            default: 400,
            max: 900,
            role: .instance,
            values: values
        )
    }

    private func italAxis(role: AxisRole, values: [AxisValue]) -> AxisDefinition {
        AxisDefinition(tag: "ital", displayName: "Italic", role: role, values: values)
    }

    func testPushCopiesInstanceAxisStopsFromMaster() throws {
        let masterStop = AxisValue(id: "m1", value: 700, name: "Bold", elidable: false)
        let targetStop = AxisValue(id: "t1", value: 500, name: "Medium", elidable: false)
        let master = [wghtAxis(values: [masterStop])]
        let target = [wghtAxis(values: [targetStop])]

        let merged = AxisTreeMerge.mergeAxesFromMaster(master: master, into: target, syncRoles: true)
        let wght = try XCTUnwrap(merged.first { $0.tag == "wght" })
        XCTAssertEqual(wght.values.map(\.value), [700])
        XCTAssertEqual(wght.values.map(\.name), ["Bold"])
        XCTAssertNotEqual(wght.values.first?.id, "m1")
    }

    func testPushPreservesRegistrationAxisStopsOnTargetWhenMasterUsesFormat1() throws {
        let masterItal = italAxis(
            role: .designRecordOnly,
            values: [AxisValue(id: "roman", value: 0, name: "Regular", elidable: true)]
        )
        let targetItal = italAxis(
            role: .designRecordOnly,
            values: [AxisValue(id: "italic", value: 1, name: "Italic", elidable: false)]
        )
        let masterWght = wghtAxis(values: [
            AxisValue(id: "m700", value: 700, name: "Bold", elidable: false),
            AxisValue(id: "m900", value: 900, name: "Black", elidable: false),
        ])
        let targetWght = wghtAxis(values: [
            AxisValue(id: "t500", value: 500, name: "Medium", elidable: false),
        ])

        let merged = AxisTreeMerge.mergeAxesFromMaster(
            master: [masterWght, masterItal],
            into: [targetWght, targetItal],
            syncRoles: true,
            targetFileStatRegistration: ["ital": 1],
            targetIsItalicFile: true
        )

        let ital = try XCTUnwrap(merged.first { $0.tag == "ital" })
        XCTAssertEqual(ital.values.count, 1)
        XCTAssertEqual(ital.values[0].value, 1)
        XCTAssertEqual(ital.values[0].name, "Italic")
        XCTAssertEqual(ital.values[0].id, "italic")
        XCTAssertEqual(ital.values[0].statFormat, 1)

        let wght = try XCTUnwrap(merged.first { $0.tag == "wght" })
        XCTAssertEqual(wght.values.map(\.value), [700, 900])
    }

    func testPushMirrorsItalFormat3ToVariantWhenMasterUsesFormat3() throws {
        let masterItal = italAxis(
            role: .designRecordOnly,
            values: [
                AxisValue(id: "roman", value: 0, name: "Roman", elidable: true, statFormat: 3, linkedValue: 1),
            ]
        )
        let targetItal = italAxis(
            role: .designRecordOnly,
            values: [
                AxisValue(id: "italic", value: 1, name: "Italic", elidable: false, statFormat: 1),
            ]
        )

        let merged = AxisTreeMerge.mergeAxesFromMaster(
            master: [masterItal],
            into: [targetItal],
            syncRoles: true,
            targetFileStatRegistration: ["ital": 1],
            targetIsItalicFile: true
        )

        let ital = try XCTUnwrap(merged.first)
        XCTAssertEqual(ital.values[0].value, 1)
        XCTAssertEqual(ital.values[0].name, "Italic")
        XCTAssertEqual(ital.values[0].id, "italic")
        XCTAssertEqual(ital.values[0].statFormat, 3)
        XCTAssertEqual(ital.values[0].linkedValue, 0)
    }

    func testPushDoesNotSyncRoleOntoRegistrationAxis() throws {
        let masterItal = italAxis(
            role: .instance,
            values: [AxisValue(id: "roman", value: 0, name: "Regular", elidable: true)]
        )
        let targetItal = italAxis(
            role: .designRecordOnly,
            values: [AxisValue(id: "italic", value: 1, name: "Italic", elidable: false)]
        )

        let merged = AxisTreeMerge.mergeAxesFromMaster(
            master: [masterItal],
            into: [targetItal],
            syncRoles: true
        )

        let ital = try XCTUnwrap(merged.first)
        XCTAssertEqual(ital.role, .designRecordOnly)
    }

    func testPushSeedsItalicItalWhenTargetMissingAxis() throws {
        let masterItal = italAxis(
            role: .designRecordOnly,
            values: [
                AxisValue(id: "roman", value: 0, name: "Roman", elidable: true, statFormat: 3, linkedValue: 1),
            ]
        )

        let merged = AxisTreeMerge.mergeAxesFromMaster(
            master: [masterItal],
            into: [],
            syncRoles: true,
            targetFileStatRegistration: ["ital": 1],
            targetIsItalicFile: true
        )

        let ital = try XCTUnwrap(merged.first { $0.tag == "ital" })
        XCTAssertEqual(ital.values.count, 1)
        XCTAssertEqual(ital.values[0].value, 1)
        XCTAssertEqual(ital.values[0].name, "Italic")
        XCTAssertEqual(ital.values[0].statFormat, 3)
        XCTAssertEqual(ital.values[0].linkedValue, 0)
    }

    func testPushSeedsItalicItalWhenTargetAxisEmpty() throws {
        let masterItal = italAxis(
            role: .designRecordOnly,
            values: [
                AxisValue(id: "roman", value: 0, name: "Roman", elidable: true, statFormat: 3, linkedValue: 1),
            ]
        )
        let targetItal = italAxis(role: .designRecordOnly, values: [])

        let merged = AxisTreeMerge.mergeAxesFromMaster(
            master: [masterItal],
            into: [targetItal],
            syncRoles: true,
            targetFileStatRegistration: ["ital": 1],
            targetIsItalicFile: true
        )

        let ital = try XCTUnwrap(merged.first { $0.tag == "ital" })
        XCTAssertEqual(ital.values.count, 1)
        XCTAssertEqual(ital.values[0].value, 1)
        XCTAssertEqual(ital.values[0].name, "Italic")
        XCTAssertEqual(ital.values[0].statFormat, 3)
        XCTAssertEqual(ital.values[0].linkedValue, 0)
    }

    func testPushDoesNotAddMasterOnlyFvarAxesToSubVariable() {
        let master = [
            AxisDefinition(
                tag: "MONO",
                displayName: "Mono",
                min: 0,
                default: 0,
                max: 100,
                role: .instance,
                values: [
                    AxisValue(id: "p", value: 0, name: "Proportional", elidable: true),
                    AxisValue(id: "m", value: 100, name: "Mono", elidable: false),
                ]
            ),
            wghtAxis(values: [
                AxisValue(id: "thin", value: 100, name: "Thin", elidable: false),
                AxisValue(id: "black", value: 900, name: "Black", elidable: false),
            ]),
            AxisDefinition(
                tag: "slnt",
                displayName: "Slant",
                min: 0,
                default: 0,
                max: 11,
                role: .instance,
                values: [
                    AxisValue(id: "up", value: 0, name: "Upright", elidable: true),
                    AxisValue(id: "it", value: 11, name: "Italic", elidable: false),
                ]
            ),
        ]
        let target = [
            wghtAxis(values: [
                AxisValue(id: "reg", value: 400, name: "Regular", elidable: true),
            ]),
            AxisDefinition(
                tag: "slnt",
                displayName: "Slant",
                min: 0,
                default: 0,
                max: 11,
                role: .instance,
                values: [
                    AxisValue(id: "up0", value: 0, name: "Roman", elidable: true),
                ]
            ),
        ]

        let merged = AxisTreeMerge.mergeAxesFromMaster(master: master, into: target, syncRoles: true)
        XCTAssertEqual(merged.map(\.tag), ["wght", "slnt"])
        XCTAssertEqual(merged.first { $0.tag == "wght" }?.values.map(\.name), ["Thin", "Black"])
        XCTAssertEqual(merged.first { $0.tag == "slnt" }?.values.map(\.name), ["Upright", "Italic"])
    }

    func testPushKeepsTargetOnlyAxes() {
        let master = [wghtAxis(values: [
            AxisValue(id: "m400", value: 400, name: "Regular", elidable: true),
        ])]
        let extra = AxisDefinition(
            tag: "opsz",
            displayName: "Optical Size",
            min: 8,
            default: 12,
            max: 144,
            role: .instance,
            values: [AxisValue(id: "t12", value: 12, name: "Text", elidable: true)]
        )
        let target = [wghtAxis(values: [
            AxisValue(id: "t700", value: 700, name: "Bold", elidable: false),
        ]), extra]

        let merged = AxisTreeMerge.mergeAxesFromMaster(master: master, into: target, syncRoles: true)
        XCTAssertEqual(Set(merged.map(\.tag)), ["wght", "opsz"])
        XCTAssertEqual(merged.first { $0.tag == "opsz" }?.values.map(\.name), ["Text"])
    }
}
