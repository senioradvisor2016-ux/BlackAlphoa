import Foundation

/// ProgramData is stored as a base64 string with '.' used instead of '/'.
/// In the shipped SQLite `.db`, the string is also terminated with a trailing '.'.
public enum BlackAlphaProgramDataCodec
{
    /// Decode ProgramData from a `.fxb` attribute value.
    public static func decodeFXBString(_ s: String) throws -> [UInt8]
    {
        try decodeBase64Variant(s, stripTrailingDot: false)
    }

    /// Decode ProgramData from a SQLite `.db` row (stored as ASCII BLOB / string).
    public static func decodeDBString(_ s: String) throws -> [UInt8]
    {
        try decodeBase64Variant(s, stripTrailingDot: true)
    }

    /// Encode ProgramData suitable for `.fxb` (no terminator).
    public static func encodeFXBString(bytes: [UInt8]) -> String
    {
        encodeBase64Variant(bytes: bytes, addTrailingDot: false)
    }

    /// Encode ProgramData suitable for `.db` (with trailing '.' terminator).
    public static func encodeDBString(bytes: [UInt8]) -> String
    {
        encodeBase64Variant(bytes: bytes, addTrailingDot: true)
    }

    // MARK: - Implementation

    private static func decodeBase64Variant(_ s: String, stripTrailingDot: Bool) throws -> [UInt8]
    {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripTrailingDot, t.hasSuffix(".")
        {
            t.removeLast()
        }

        // Variant: '.' stands for '/'
        t = t.replacingOccurrences(of: ".", with: "/")

        // Add '=' padding if needed.
        let mod = t.count % 4
        if mod == 1
        {
            // Impossible in base64; caller likely forgot to strip the trailing '.'.
            throw Error.invalidLength(t.count)
        }

        if mod != 0
        {
            t.append(String(repeating: "=", count: 4 - mod))
        }

        guard let data = Data(base64Encoded: t) else
        {
            throw Error.invalidBase64
        }
        return Array(data)
    }

    private static func encodeBase64Variant(bytes: [UInt8], addTrailingDot: Bool) -> String
    {
        let b64 = Data(bytes).base64EncodedString()
        // Strip '=' padding and convert '/' -> '.'
        var t = b64.replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "/", with: ".")
        if addTrailingDot { t.append(".") }
        return t
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidLength(Int)
        case invalidBase64

        public var description: String
        {
            switch self
            {
            case let .invalidLength(n): return "Invalid ProgramData length \(n) for base64 variant."
            case .invalidBase64: return "Invalid ProgramData base64 variant."
            }
        }
    }
}

