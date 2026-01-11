import Foundation

public struct PGParameter: Identifiable, Equatable, Sendable
{
    public enum Range: Equatable, Sendable
    {
        case continuous(min: UInt8, max: UInt8)
        case discrete(min: UInt8, max: UInt8, labels: [String]?)

        public var min: UInt8
        {
            switch self
            {
            case let .continuous(min, _): return min
            case let .discrete(min, _, _): return min
            }
        }

        public var max: UInt8
        {
            switch self
            {
            case let .continuous(_, max): return max
            case let .discrete(_, max, _): return max
            }
        }

        public func clamped(_ value: UInt8) -> UInt8
        {
            Swift.min(max, Swift.max(min, value))
        }
    }

    public let id: UInt8
    public let name: String
    public let range: Range

    public init(id: UInt8, name: String, range: Range)
    {
        self.id = id
        self.name = name
        self.range = range
    }
}

public enum PG300Parameters
{
    /// The full PG-300 style list (36 params; 0x00..0x23) per spec.
    public static let all: [PGParameter] =
    [
        .init(id: 0x00, name: "DCO ENV Mode", range: .discrete(min: 0, max: 3, labels: nil)),
        .init(id: 0x01, name: "VCF ENV Mode", range: .discrete(min: 0, max: 3, labels: nil)),
        .init(id: 0x02, name: "VCA ENV Mode", range: .discrete(min: 0, max: 3, labels: nil)),

        .init(id: 0x03, name: "DCO Pulse Wave", range: .discrete(min: 0, max: 3, labels: nil)),
        .init(id: 0x04, name: "DCO Saw Wave", range: .discrete(min: 0, max: 5, labels: nil)),
        .init(id: 0x05, name: "DCO Sub Wave", range: .discrete(min: 0, max: 5, labels: nil)),

        .init(id: 0x06, name: "DCO Range", range: .discrete(min: 0, max: 3, labels: ["4'", "8'", "16'", "32'"])),
        .init(id: 0x07, name: "DCO Sub Level", range: .discrete(min: 0, max: 3, labels: nil)),
        .init(id: 0x08, name: "DCO Noise Level", range: .discrete(min: 0, max: 3, labels: nil)),

        .init(id: 0x09, name: "HPF Cutoff", range: .discrete(min: 0, max: 3, labels: nil)),

        .init(id: 0x0A, name: "Chorus On/Off", range: .discrete(min: 0, max: 1, labels: ["Off", "On"])),

        .init(id: 0x0B, name: "DCO LFO Depth", range: .continuous(min: 0, max: 127)),
        .init(id: 0x0C, name: "DCO ENV Depth", range: .continuous(min: 0, max: 127)),
        .init(id: 0x0D, name: "DCO Aftertouch", range: .continuous(min: 0, max: 127)),
        .init(id: 0x0E, name: "DCO PW/PWM Depth", range: .continuous(min: 0, max: 127)),
        .init(id: 0x0F, name: "DCO PWM Rate", range: .continuous(min: 0, max: 127)),

        .init(id: 0x10, name: "VCF Cutoff", range: .continuous(min: 0, max: 127)),
        .init(id: 0x11, name: "VCF Resonance", range: .continuous(min: 0, max: 127)),
        .init(id: 0x12, name: "VCF LFO Depth", range: .continuous(min: 0, max: 127)),
        .init(id: 0x13, name: "VCF ENV Depth", range: .continuous(min: 0, max: 127)),
        .init(id: 0x14, name: "VCF Key Follow", range: .continuous(min: 0, max: 127)),
        .init(id: 0x15, name: "VCF Aftertouch", range: .continuous(min: 0, max: 127)),

        .init(id: 0x16, name: "VCA Level", range: .continuous(min: 0, max: 127)),
        .init(id: 0x17, name: "VCA Aftertouch", range: .continuous(min: 0, max: 127)),

        .init(id: 0x18, name: "LFO Rate", range: .continuous(min: 0, max: 127)),
        .init(id: 0x19, name: "LFO Delay", range: .continuous(min: 0, max: 127)),

        .init(id: 0x1A, name: "ENV T1 (Attack Time)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x1B, name: "ENV L1 (Attack Level)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x1C, name: "ENV T2 (Break Time)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x1D, name: "ENV L2 (Break Level)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x1E, name: "ENV T3 (Decay Time)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x1F, name: "ENV L3 (Sustain)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x20, name: "ENV T4 (Release)", range: .continuous(min: 0, max: 127)),
        .init(id: 0x21, name: "ENV Key Follow", range: .continuous(min: 0, max: 127)),

        .init(id: 0x22, name: "Chorus Rate", range: .continuous(min: 0, max: 127)),
        .init(id: 0x23, name: "Bender Range", range: .discrete(min: 0, max: 12, labels: nil))
    ]
}

