import Foundation

/// SysEx helpers for Roland MKS-50 / Alpha Juno family (Format Type 0x23).
///
/// Common header:
/// `F0 41 <op> 0n 23 ... F7`
/// - 0x41 = Roland
/// - 0n = MIDI channel-1 (0x00..0x0F)
/// - 0x23 = format type (aka model/format id in some docs)
public enum SysExAlphaJuno
{
    public enum Opcode: UInt8, CaseIterable, Sendable
    {
        case apr = 0x35  // All Parameters
        case ipr = 0x36  // Individual Parameter
        case bld = 0x37  // Bulk Dump
        case wsf = 0x40  // Want to Send a File
        case rqf = 0x41  // Request a File
        case dat = 0x42  // Data
        case ack = 0x43  // Acknowledge
        case eof = 0x45  // End of File
        case err = 0x4E  // Communication Error
        case rjc = 0x4F  // Rejection
    }

    public static let roland: UInt8 = 0x41
    public static let formatType: UInt8 = 0x23

    public enum Group: Sendable
    {
        /// Tone parameter group (MKS-50 + Alpha Juno)
        case tone

        public var bytes: [UInt8]
        {
            switch self
            {
            case .tone: return [0x20, 0x01]
            }
        }
    }

    /// Validates and encodes MIDI channel 1...16 to 0x00...0x0F.
    public static func channelNibble(_ channel: Int) throws -> UInt8
    {
        guard (1...16).contains(channel) else { throw Error.invalidChannel(channel) }
        return UInt8(channel - 1) & 0x0F
    }

    /// Builds the simple 5-byte commands:
    /// `F0 41 <op> 0n 23 F7`
    public static func simple(channel: Int, op: Opcode) throws -> [UInt8]
    {
        let ch = try channelNibble(channel)
        return [0xF0, roland, op.rawValue, ch, formatType, 0xF7]
    }

    /// Builds an Individual Tone Parameter (IPR) SysEx message.
    ///
    /// Format: `F0 41 36 0n 23 20 01 pp vv F7`
    public static func ipr(channel: Int, group: Group = .tone, param: UInt8, value: UInt8) throws -> [UInt8]
    {
        let ch = try channelNibble(channel)
        guard value <= 0x7F else { throw Error.invalidValue(value) }
        guard param <= 0x7F else { throw Error.invalidParam(param) }
        return [0xF0, roland, Opcode.ipr.rawValue, ch, formatType] + group.bytes + [param, value, 0xF7]
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

