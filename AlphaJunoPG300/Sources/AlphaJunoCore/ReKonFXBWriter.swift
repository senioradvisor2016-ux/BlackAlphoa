import Foundation

public enum ReKonFXBWriter
{
    public struct Bank: Equatable, Sendable
    {
        public var bankName: String
        public var programs: [ReKonFXB.Program] // must be 64

        public init(bankName: String, programs: [ReKonFXB.Program])
        {
            self.bankName = bankName
            self.programs = programs
        }
    }

    /// Builds a VC2 `.fxb` bytes blob from programs.
    ///
    /// Note: `ProgramData` is treated as an opaque string. This supports roundtripping vendor `.fxb` files,
    /// and editing program names without understanding vendor program encoding.
    public static func buildFXBBytes(from bank: Bank) throws -> [UInt8]
    {
        guard bank.programs.count == 64 else { throw Error.invalidProgramCount(bank.programs.count) }

        var attrs: [String] = []
        attrs.append("pluginVersion=\"2\"")
        attrs.append("CurrentBank=\"0\"")
        attrs.append("CurrentProgram=\"0\"")
        attrs.append("Bank0=\"0\"")
        attrs.append("BankName0=\"\(escape(bank.bankName))\"")

        for p in bank.programs.sorted(by: { $0.index < $1.index })
        {
            attrs.append("ProgramName\(p.index)=\"\(escape(p.name))\"")
            attrs.append("ProgramData\(p.index)=\"\(escape(p.data))\"")
        }

        let xml = "<VST.AU.Alpha.JUNO.EditorAllBanks \(attrs.joined(separator: \" \")) />"
        return try VC2Container.encodeXML(xml)
    }

    private static func escape(_ s: String) -> String
    {
        s
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible
    {
        case invalidProgramCount(Int)

        public var description: String
        {
            switch self
            {
            case let .invalidProgramCount(n): return "FXB requires exactly 64 programs (got \(n))."
            }
        }
    }
}

