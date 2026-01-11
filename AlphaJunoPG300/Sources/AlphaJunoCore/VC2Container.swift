import Foundation

/// reKon "VC2!" container observed in:
/// - `*.rms` (preferences)
/// - `*.fxb` (bank)
///
/// Format (little-endian):
/// - bytes[0..<4]  = ASCII "VC2!"
/// - bytes[4..<8]  = UInt32 xmlLength
/// - bytes[8..<8+xmlLength] = UTF-8 XML bytes (often single-line)
public enum VC2Container
{
    public static func decodeXML(from bytes: [UInt8]) throws -> String
    {
        guard bytes.count >= 8 else { throw Error.tooShort(bytes.count) }
        guard bytes[0] == 0x56, bytes[1] == 0x43, bytes[2] == 0x32, bytes[3] == 0x21 else
        {
            throw Error.badMagic
        }

        let len = Int(UInt32(bytes[4]) | (UInt32(bytes[5]) << 8) | (UInt32(bytes[6]) << 16) | (UInt32(bytes[7]) << 24))
        guard len >= 0, 8 + len <= bytes.count else { throw Error.badLength(len) }

        let xmlBytes = Array(bytes[8..<(8 + len)])
        guard let xml = String(bytes: xmlBytes, encoding: .utf8) else { throw Error.badUTF8 }
        return xml
    }

    public static func encodeXML(_ xml: String) throws -> [UInt8]
    {
        guard let data = xml.data(using: .utf8) else { throw Error.badUTF8 }
        let len = UInt32(data.count)
        var out: [UInt8] = [0x56, 0x43, 0x32, 0x21] // "VC2!"
        out.append(UInt8(len & 0xFF))
        out.append(UInt8((len >> 8) & 0xFF))
        out.append(UInt8((len >> 16) & 0xFF))
        out.append(UInt8((len >> 24) & 0xFF))
        out.append(contentsOf: data)
        return out
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case tooShort(Int)
        case badMagic
        case badLength(Int)
        case badUTF8

        public var description: String
        {
            switch self
            {
            case let .tooShort(n): return "VC2 container too short (\(n) bytes)."
            case .badMagic: return "VC2 container missing 'VC2!' magic."
            case let .badLength(n): return "VC2 container has invalid XML length \(n)."
            case .badUTF8: return "VC2 container XML is not valid UTF-8."
            }
        }
    }
}

