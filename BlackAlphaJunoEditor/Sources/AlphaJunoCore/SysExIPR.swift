import Foundation

public enum SysExIPR
{
    /// Builds an Alpha Juno / MKS-50 IPR (Individual Parameter) SysEx message.
    ///
    /// Format: `F0 41 36 ch 23 20 01 pp vv F7`
    /// - `ch` is 0x00..0x0F for channels 1..16 (UI).
    public static func iprMessage(channel: Int, param: UInt8, value: UInt8) throws -> [UInt8]
    {
        guard (1...16).contains(channel) else
        {
            throw Error.invalidChannel(channel)
        }

        // Param id is specified as 0x00..0x23 (36 params). We'll validate but keep it flexible.
        guard param <= 0x7F else
        {
            throw Error.invalidParam(param)
        }

        guard value <= 0x7F else
        {
            throw Error.invalidValue(value)
        }

        let ch = UInt8(channel - 1) & 0x0F
        return [0xF0, 0x41, 0x36, ch, 0x23, 0x20, 0x01, param, value, 0xF7]
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidChannel(Int)
        case invalidParam(UInt8)
        case invalidValue(UInt8)

        public var description: String
        {
            switch self
            {
            case let .invalidChannel(ch): return "Invalid MIDI channel \(ch). Expected 1...16."
            case let .invalidParam(p): return "Invalid param id 0x\(String(p, radix: 16)). Expected 0x00...0x7F."
            case let .invalidValue(v): return "Invalid value \(v). Expected 0...127."
            }
        }
    }
}

