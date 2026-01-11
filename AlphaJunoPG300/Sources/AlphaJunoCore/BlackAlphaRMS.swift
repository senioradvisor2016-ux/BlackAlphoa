import Foundation

/// Parser for the `*.rms` preferences file format we support.
/// This is a VC2 container whose XML root contains lots of attributes like:
/// `Prefs_Midi_default_midi_channel`, `Prefs_Midi_device_id`, etc.
public enum BlackAlphaRMS
{
    public static func parsePrefs(fromVC2Bytes bytes: [UInt8]) throws -> [String: String]
    {
        let xml = try VC2Container.decodeXML(from: bytes)
        return try parsePrefs(fromXML: xml)
    }

    public static func parsePrefs(fromXML xml: String) throws -> [String: String]
    {
        // Same lightweight attribute scrape approach as FXB.
        guard let rootRange = xml.range(of: "<") else { throw Error.invalidXML }
        let tail = xml[rootRange.lowerBound...]
        guard let end = tail.firstIndex(of: ">") else { throw Error.invalidXML }
        let header = String(tail[..<end])

        var out: [String: String] = [:]

        // Very small attribute parser: scan key="value" tokens.
        // Assumes there are no '>' characters inside quoted values.
        var i = header.startIndex
        while i < header.endIndex
        {
            // find '='
            guard let eq = header[i...].firstIndex(of: "=") else { break }
            // find key start (skip whitespace)
            var ks = eq
            while ks > header.startIndex
            {
                let prev = header.index(before: ks)
                if header[prev].isWhitespace { break }
                ks = prev
            }
            let key = header[ks..<eq].trimmingCharacters(in: .whitespacesAndNewlines)

            // require quote
            let q1 = header.index(after: eq)
            guard q1 < header.endIndex, header[q1] == "\"" else { i = header.index(after: eq); continue }
            let vs = header.index(after: q1)
            guard let q2 = header[vs...].firstIndex(of: "\"") else { break }
            let val = String(header[vs..<q2])
            if !key.isEmpty { out[key] = val }

            i = header.index(after: q2)
        }

        // Drop the leading "<Tag" token if it got captured as a key.
        out = out.filter { !$0.key.hasPrefix("<") }
        return out
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidXML

        public var description: String
        {
            "Invalid RMS XML."
        }
    }
}

