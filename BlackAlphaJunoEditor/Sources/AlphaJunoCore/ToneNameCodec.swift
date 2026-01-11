import Foundation

public enum ToneNameCodec
{
    // 6-bit character set (per spec):
    // 0..25 => 'A'..'Z'
    // 26..51 => 'a'..'z'
    // 52..61 => '0'..'9'
    // 62 => ' '
    // 63 => '-'

    public static func decode(codes: [UInt8]) throws -> String
    {
        var chars: [Character] = []
        chars.reserveCapacity(codes.count)

        for c in codes
        {
            let ch: Character
            switch c
            {
            case 0...25:
                ch = Character(UnicodeScalar(Int(("A" as Character).unicodeScalars.first!.value) + Int(c))!)
            case 26...51:
                ch = Character(UnicodeScalar(Int(("a" as Character).unicodeScalars.first!.value) + Int(c - 26))!)
            case 52...61:
                ch = Character(UnicodeScalar(Int(("0" as Character).unicodeScalars.first!.value) + Int(c - 52))!)
            case 62:
                ch = " "
            case 63:
                ch = "-"
            default:
                throw Error.invalidCode(c)
            }
            chars.append(ch)
        }

        // Trim trailing spaces
        while chars.last == " "
        {
            chars.removeLast()
        }

        return String(chars)
    }

    /// Encodes a String into exactly 10 6-bit codes, padding with space (62) and trimming to 10 chars.
    public static func encode(name: String) throws -> [UInt8]
    {
        let trimmed = String(name.prefix(10))
        var out: [UInt8] = []
        out.reserveCapacity(10)

        for ch in trimmed
        {
            out.append(try encodeChar(ch))
        }

        while out.count < 10
        {
            out.append(62) // space
        }

        return out
    }

    private static func encodeChar(_ ch: Character) throws -> UInt8
    {
        if ch >= "A" && ch <= "Z"
        {
            return UInt8(ch.unicodeScalars.first!.value - ("A" as Character).unicodeScalars.first!.value)
        }
        if ch >= "a" && ch <= "z"
        {
            return UInt8(26 + (ch.unicodeScalars.first!.value - ("a" as Character).unicodeScalars.first!.value))
        }
        if ch >= "0" && ch <= "9"
        {
            return UInt8(52 + (ch.unicodeScalars.first!.value - ("0" as Character).unicodeScalars.first!.value))
        }
        if ch == " " { return 62 }
        if ch == "-" { return 63 }
        throw Error.unencodableCharacter(ch)
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidCode(UInt8)
        case unencodableCharacter(Character)

        public var description: String
        {
            switch self
            {
            case let .invalidCode(c): return "Invalid 6-bit code \(c)."
            case let .unencodableCharacter(ch): return "Character '\(ch)' not encodable in ToneName charset."
            }
        }
    }
}

