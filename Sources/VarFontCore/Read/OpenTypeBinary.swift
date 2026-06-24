import CoreText
import Foundation

enum OpenTypeBinary {
    static func tag(_ string: String) -> CTFontTableTag {
        precondition(string.count == 4)
        let bytes = Array(string.utf8)
        return CTFontTableTag(
            UInt32(bytes[0]) << 24
                | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8
                | UInt32(bytes[3])
        )
    }

    static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    static func readInt16(_ data: Data, _ offset: Int) -> Int16 {
        Int16(bitPattern: readUInt16(data, offset))
    }

    static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    static func readInt32(_ data: Data, _ offset: Int) -> Int32 {
        Int32(bitPattern: readUInt32(data, offset))
    }

    static func readFixed(_ data: Data, _ offset: Int) -> Double {
        Double(readInt32(data, offset)) / 65536.0
    }

    static func readTag(_ data: Data, _ offset: Int) -> String {
        guard offset + 4 <= data.count else { return "" }
        let bytes = data[offset..<(offset + 4)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
