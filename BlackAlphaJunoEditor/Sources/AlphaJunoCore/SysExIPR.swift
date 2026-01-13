import Foundation

public enum SysExIPR
{
    /// Builds an Alpha Juno / MKS-50 IPR (Individual Parameter) SysEx message.
    ///
    /// Format: `F0 41 36 ch 23 20 01 pp vv F7`
    /// - `ch` is 0x00..0x0F for channels 1..16 (UI).
    public static func iprMessage(channel: Int, param: UInt8, value: UInt8) throws -> [UInt8]
    {
        do { return try SysExAlphaJuno.ipr(channel: channel, param: param, value: value) }
        catch let e as SysExAlphaJuno.Error
        {
            switch e
            {
            case let .invalidChannel(ch): throw Error.invalidChannel(ch)
            case let .invalidParam(p): throw Error.invalidParam(p)
            case let .invalidValue(v): throw Error.invalidValue(v)
            }
        }
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

