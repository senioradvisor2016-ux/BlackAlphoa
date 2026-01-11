import Foundation

public struct SyxBank: Equatable, Sendable
{
    public struct Tone: Equatable, Sendable
    {
        public let index: Int // 0..63
        public var raw32: [UInt8] // 32 bytes

        public init(index: Int, raw32: [UInt8])
        {
            self.index = index
            self.raw32 = raw32
        }

        public var name: String
        {
            get
            {
                let slice = raw32[21...30].map { $0 & 0x3F }
                return (try? ToneNameCodec.decode(codes: slice)) ?? ""
            }
        }

        public mutating func setName(_ newName: String) throws
        {
            let codes = try ToneNameCodec.encode(name: newName)
            for i in 0..<10
            {
                let old = raw32[21 + i]
                raw32[21 + i] = (old & 0xC0) | (codes[i] & 0x3F)
            }
        }
    }

    public var messages: [[UInt8]] // each message includes F0..F7
    public var tones: [Tone]       // 64 tones (decoded)

    public init(messages: [[UInt8]], tones: [Tone])
    {
        self.messages = messages
        self.tones = tones
    }

    /// Split concatenated SysEx bytes into individual messages (each includes F0..F7).
    public static func splitSyxMessages(_ data: [UInt8]) throws -> [[UInt8]]
    {
        var out: [[UInt8]] = []
        var i = 0
        while i < data.count
        {
            // seek to F0
            while i < data.count, data[i] != 0xF0 { i += 1 }
            if i >= data.count { break }
            let start = i
            i += 1
            while i < data.count, data[i] != 0xF7 { i += 1 }
            guard i < data.count else { throw Error.missingF7(startIndex: start) }
            let end = i
            let msg = Array(data[start...end])
            out.append(msg)
            i = end + 1
        }
        return out
    }

    /// Parse an Alpha Juno / MKS-50 bank dump (e.g. NEWBANK1.SYX) into messages and 64 decoded tones.
    public static func parseBankFileBytes(_ bytes: [UInt8]) throws -> SyxBank
    {
        let messages = try splitSyxMessages(bytes)
        guard messages.count == 16 else { throw Error.invalidMessageCount(messages.count) }

        var tones: [Tone] = []
        tones.reserveCapacity(64)

        for (msgIndex, msg) in messages.enumerated()
        {
            guard msg.count == 266 else { throw Error.invalidMessageLength(index: msgIndex, length: msg.count) }
            guard msg.first == 0xF0, msg.last == 0xF7 else { throw Error.invalidMessageBounds(index: msgIndex) }

            // Header bytes
            guard msg[1] == 0x41 else { throw Error.invalidHeader(index: msgIndex, reason: "not Roland (0x41)") }
            guard msg[2] == 0x37 else { throw Error.invalidHeader(index: msgIndex, reason: "not BLD bulk dump (0x37)") }
            // msg[3] deviceId/channel (don't validate)
            guard msg[4] == 0x23 else { throw Error.invalidHeader(index: msgIndex, reason: "format type not 0x23") }
            guard msg[5] == 0x20, msg[6] == 0x01 else { throw Error.invalidHeader(index: msgIndex, reason: "not tone group 0x20 0x01") }
            guard msg[7] == 0x00 else { throw Error.invalidHeader(index: msgIndex, reason: "expected 0x00 at header[7]") }

            let startToneIndex = Int(msg[8])
            if startToneIndex != msgIndex * 4 { throw Error.unexpectedStartToneIndex(index: msgIndex, got: startToneIndex) }

            // 256 bytes data from offset 9
            let dataStart = 9
            for toneInMsg in 0..<4
            {
                let globalTone = startToneIndex + toneInMsg
                let encodedStart = dataStart + toneInMsg * 64
                let encoded = Array(msg[encodedStart..<(encodedStart + 64)])
                let raw32 = try nibbleDecode32(encoded64: encoded)
                tones.append(Tone(index: globalTone, raw32: raw32))
            }
        }

        guard tones.count == 64 else { throw Error.invalidToneCount(tones.count) }
        return SyxBank(messages: messages, tones: tones)
    }

    /// Apply the current `tones[*].raw32` back into `messages` and return the full concatenated `.syx` bytes.
    public func encodeBankFileBytes() throws -> [UInt8]
    {
        guard messages.count == 16 else { throw Error.invalidMessageCount(messages.count) }
        guard tones.count == 64 else { throw Error.invalidToneCount(tones.count) }

        var newMessages: [[UInt8]] = messages

        for msgIndex in 0..<16
        {
            var msg = newMessages[msgIndex]
            guard msg.count == 266 else { throw Error.invalidMessageLength(index: msgIndex, length: msg.count) }

            let startToneIndex = Int(msg[8])
            for toneInMsg in 0..<4
            {
                let globalTone = startToneIndex + toneInMsg
                guard let tone = tones.first(where: { $0.index == globalTone }) else
                {
                    throw Error.missingTone(globalTone)
                }
                let encoded = try nibbleEncode64(raw32: tone.raw32)
                let encodedStart = 9 + toneInMsg * 64
                msg.replaceSubrange(encodedStart..<(encodedStart + 64), with: encoded)
            }

            newMessages[msgIndex] = msg
        }

        return newMessages.flatMap { $0 }
    }

    // MARK: - Nibble encode/decode

    public static func nibbleDecode32(encoded64: [UInt8]) throws -> [UInt8]
    {
        guard encoded64.count == 64 else { throw Error.invalidEncodedToneLength(encoded64.count) }
        var raw: [UInt8] = Array(repeating: 0, count: 32)
        for i in 0..<32
        {
            let lo = encoded64[2 * i] & 0x0F
            let hi = encoded64[2 * i + 1] & 0x0F
            raw[i] = lo | (hi << 4)
        }
        return raw
    }

    public static func nibbleEncode64(raw32: [UInt8]) throws -> [UInt8]
    {
        guard raw32.count == 32 else { throw Error.invalidRawToneLength(raw32.count) }
        var encoded: [UInt8] = Array(repeating: 0, count: 64)
        for i in 0..<32
        {
            encoded[2 * i] = raw32[i] & 0x0F
            encoded[2 * i + 1] = (raw32[i] >> 4) & 0x0F
        }
        return encoded
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case missingF7(startIndex: Int)
        case invalidMessageCount(Int)
        case invalidMessageLength(index: Int, length: Int)
        case invalidMessageBounds(index: Int)
        case invalidHeader(index: Int, reason: String)
        case unexpectedStartToneIndex(index: Int, got: Int)
        case invalidToneCount(Int)
        case missingTone(Int)
        case invalidEncodedToneLength(Int)
        case invalidRawToneLength(Int)

        public var description: String
        {
            switch self
            {
            case let .missingF7(startIndex): return "Missing 0xF7 terminator (started at byte \(startIndex))."
            case let .invalidMessageCount(c): return "Invalid message count \(c). Expected 16."
            case let .invalidMessageLength(i, l): return "Invalid message length at \(i): \(l). Expected 266."
            case let .invalidMessageBounds(i): return "Invalid message bounds at \(i) (missing F0/F7)."
            case let .invalidHeader(i, reason): return "Invalid header at \(i): \(reason)."
            case let .unexpectedStartToneIndex(i, got): return "Unexpected startToneIndex in message \(i): \(got). Expected \(i * 4)."
            case let .invalidToneCount(c): return "Invalid tone count \(c). Expected 64."
            case let .missingTone(i): return "Missing tone index \(i)."
            case let .invalidEncodedToneLength(n): return "Invalid encoded tone length \(n). Expected 64."
            case let .invalidRawToneLength(n): return "Invalid raw tone length \(n). Expected 32."
            }
        }
    }
}

