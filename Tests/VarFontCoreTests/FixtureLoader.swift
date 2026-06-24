import Foundation
@testable import VarFontCore

enum FixtureLoader {
    static var examplesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("fixtures/examples", isDirectory: true)
    }

    static func url(_ name: String) -> URL {
        examplesDirectory.appendingPathComponent(name)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try VarFontJSON.decode(type, from: url(name))
    }
}
