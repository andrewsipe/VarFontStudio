import CoreText
import Foundation

public enum OpenTypeNameTable {
    private static let nameTableTag = OpenTypeBinary.tag("name")

    /// Windows Unicode BMP English (en-US): platform 3, encoding 1, language 0x0409.
    public static let windowsEnglishPlatformID: UInt16 = 3
    public static let windowsUnicodeEncodingID: UInt16 = 1
    public static let windowsEnglishLanguageID: UInt16 = 0x0409
    public static let lowNameIDRange: ClosedRange<Int> = 0...25

    public static func name(id: Int, from font: CTFont) -> String? {
        guard let data = CTFontCopyTable(font, nameTableTag, []) as Data? else { return nil }
        return bestName(id: id, in: data)
    }

    public static func bestName(id: Int, in data: Data) -> String? {
        let records = parseRecords(data).filter { $0.nameID == id }
        guard !records.isEmpty, data.count >= 6 else { return nil }

        let stringOffset = Int(OpenTypeBinary.readUInt16(data, 4))
        let sorted = records.sorted { preferenceScore($0) < preferenceScore($1) }
        for record in sorted {
            if let value = decode(record: record, in: data, stringOffset: stringOffset), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    /// Windows English records for name IDs in `0...25` (populated only).
    public static func windowsEnglishLowNames(from font: CTFont) -> [WindowsNameRecord] {
        guard let data = CTFontCopyTable(font, nameTableTag, []) as Data? else { return [] }
        return windowsEnglishLowNames(in: data)
    }

    public static func windowsEnglishLowNames(in data: Data) -> [WindowsNameRecord] {
        guard data.count >= 6 else { return [] }
        let stringOffset = Int(OpenTypeBinary.readUInt16(data, 4))
        var byID: [Int: String] = [:]
        for record in parseRecords(data) {
            let id = Int(record.nameID)
            guard lowNameIDRange.contains(id) else { continue }
            guard record.platformID == windowsEnglishPlatformID,
                  record.encodingID == windowsUnicodeEncodingID,
                  record.languageID == windowsEnglishLanguageID else { continue }
            guard let value = decode(record: record, in: data, stringOffset: stringOffset) else { continue }
            byID[id] = value
        }
        return byID.keys.sorted().map { WindowsNameRecord(nameID: $0, string: byID[$0] ?? "") }
    }

    public static func uniqueNameIDs(in data: Data) -> Set<Int> {
        Set(parseRecords(data).map { Int($0.nameID) })
    }

    public static func firstFreeNameID(used: Set<Int>, startingAt: Int = 256) -> Int {
        var candidate = startingAt
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    public static func standardNameLabel(for id: Int) -> String? {
        switch id {
        case 0: "Copyright"
        case 1: "Font Family"
        case 2: "Font Subfamily"
        case 3: "Unique ID"
        case 4: "Full Name"
        case 5: "Version"
        case 6: "PostScript Name"
        case 7: "Trademark"
        case 8: "Manufacturer"
        case 9: "Designer"
        case 10: "Description"
        case 11: "Vendor URL"
        case 12: "Designer URL"
        case 13: "License"
        case 14: "License URL"
        case 15: "Reserved"
        case 16: "Typographic Family"
        case 17: "Typographic Subfamily"
        case 18: "Compatible Full"
        case 19: "Sample Text"
        case 20: "PostScript CID"
        case 21: "WWS Family"
        case 22: "WWS Subfamily"
        case 23: "Light Palette"
        case 24: "Dark Palette"
        case 25: "Variations PS Prefix"
        default: nil
        }
    }

    /// Catalog IDs editable in the Names panel (skips reserved 15).
    public static var editableLowNameIDs: [Int] {
        Array(0...25).filter { $0 != 15 }
    }

    private struct NameRecord {
        var platformID: UInt16
        var encodingID: UInt16
        var languageID: UInt16
        var nameID: UInt16
        var length: UInt16
        var offset: UInt16
    }

    private static func parseRecords(_ data: Data) -> [NameRecord] {
        guard data.count >= 6 else { return [] }
        let count = Int(OpenTypeBinary.readUInt16(data, 2))
        guard count > 0 else { return [] }

        var records: [NameRecord] = []
        var pos = 6
        for _ in 0..<count {
            guard pos + 12 <= data.count else { break }
            records.append(NameRecord(
                platformID: OpenTypeBinary.readUInt16(data, pos),
                encodingID: OpenTypeBinary.readUInt16(data, pos + 2),
                languageID: OpenTypeBinary.readUInt16(data, pos + 4),
                nameID: OpenTypeBinary.readUInt16(data, pos + 6),
                length: OpenTypeBinary.readUInt16(data, pos + 8),
                offset: OpenTypeBinary.readUInt16(data, pos + 10)
            ))
            pos += 12
        }
        return records
    }

    private static func decode(record: NameRecord, in data: Data, stringOffset: Int) -> String? {
        let start = stringOffset + Int(record.offset)
        let length = Int(record.length)
        guard start >= 0, length > 0, start + length <= data.count else { return nil }
        let slice = data[start..<(start + length)]

        switch (record.platformID, record.encodingID) {
        case (3, 1), (3, 10), (0, 3):
            return decodeUTF16BE(slice)
        case (1, 0), (1, 25):
            return String(bytes: slice, encoding: .macOSRoman)
        case (3, 0):
            return String(bytes: slice, encoding: .windowsCP1252)
        default:
            return decodeUTF16BE(slice) ?? String(bytes: slice, encoding: .macOSRoman)
        }
    }

    private static func decodeUTF16BE(_ slice: Data.SubSequence) -> String? {
        guard !slice.isEmpty, slice.count.isMultiple(of: 2) else { return nil }
        return String(data: Data(slice), encoding: .utf16BigEndian)
    }

    private static func preferenceScore(_ record: NameRecord) -> Int {
        if record.platformID == 3 {
            if record.languageID == 0x0409 { return 0 }
            if record.languageID == 0 { return 1 }
            return 2
        }
        if record.platformID == 1 {
            if record.languageID == 0 { return 3 }
            return 4
        }
        return 10
    }
}

/// Windows platform name record (plat 3 · enc 1 · lang 0x0409).
public struct WindowsNameRecord: Codable, Equatable, Sendable, Identifiable {
    public var nameID: Int
    public var string: String

    public var id: Int { nameID }

    public init(nameID: Int, string: String) {
        self.nameID = nameID
        self.string = string
    }

    enum CodingKeys: String, CodingKey {
        case nameID = "name_id"
        case string
    }
}
