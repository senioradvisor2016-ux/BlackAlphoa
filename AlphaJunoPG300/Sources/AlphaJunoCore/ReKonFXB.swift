import Foundation

/// Parser for the reKon `*.fxb` bank observed in the installer.
///
/// This bank is a VC2 container whose XML root tag looked like:
/// `VST.AU.Alpha.JUNO.EditorAllBanks`
///
/// The XML stores 64 programs as attributes:
/// - `ProgramName0`..`ProgramName63`
/// - `ProgramData0`..`ProgramData63` (opaque string; vendor-specific encoding)
public enum ReKonFXB
{
    public struct Program: Equatable, Sendable
    {
        public let index: Int // 0..63
        public let name: String
        public let data: String
    }

    public static func parsePrograms(fromVC2Bytes bytes: [UInt8]) throws -> [Program]
    {
        let xml = try VC2Container.decodeXML(from: bytes)
        return try parsePrograms(fromXML: xml)
    }

    public static func parsePrograms(fromXML xml: String) throws -> [Program]
    {
        // ultra-lightweight attribute scrape (no external XML libs; FoundationXML is fine on macOS but keep core pure).
        // We assume a single root element with attributes and no child nodes.
        guard let rootRange = xml.range(of: "<") else { throw Error.invalidXML }
        let tail = xml[rootRange.lowerBound...]
        guard let end = tail.firstIndex(of: ">") else { throw Error.invalidXML }
        let header = String(tail[..<end]) // "<Root ...attrs..."

        // Extract attribute values by pattern ` key="value"`
        func attr(_ key: String) -> String?
        {
            guard let r = header.range(of: "\(key)=\"") else { return nil }
            let s = header[r.upperBound...]
            guard let q = s.firstIndex(of: "\"") else { return nil }
            return String(s[..<q])
        }

        var programs: [Program] = []
        programs.reserveCapacity(64)
        for i in 0..<64
        {
            guard let name = attr("ProgramName\(i)"),
                  let data = attr("ProgramData\(i)") else
            {
                throw Error.missingProgram(i)
            }
            programs.append(Program(index: i, name: name, data: data))
        }
        return programs
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidXML
        case missingProgram(Int)

        public var description: String
        {
            switch self
            {
            case .invalidXML: return "Invalid reKon FXB XML."
            case let .missingProgram(i): return "Missing ProgramName/ProgramData for program \(i)."
            }
        }
    }
}

