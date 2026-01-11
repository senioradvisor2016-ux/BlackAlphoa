import Foundation
import AlphaJunoCore

public actor PG300Session
{
    public struct Status: Equatable, Sendable
    {
        public var destinationName: String?
        public var sourceName: String?
        public var mergeEnabled: Bool
        public var channel: Int
        public var liveSendEnabled: Bool
        public var pendingCount: Int
        public var lastSentHex: String?
        public var lastError: String?
    }

    private let midi: CoreMIDIManager

    private var destinations: [CoreMIDIManager.Endpoint] = []
    private var sources: [CoreMIDIManager.Endpoint] = []

    private var channel: Int = 1
    private var liveSendEnabled: Bool = false

    private var values: [UInt8: UInt8] = [:]
    private var pending: [UInt8: UInt8] = [:]

    private var flushTask: Task<Void, Never>?
    private var lastSentHex: String?
    private var lastError: String?

    public init() throws
    {
        self.midi = try CoreMIDIManager()

        // Init values to 0 for all parameters.
        for p in PG300Parameters.all
        {
            values[p.id] = 0
        }

        refreshEndpoints()
    }

    // MARK: - Endpoints

    public func refreshEndpoints()
    {
        midi.refreshEndpoints()
        destinations = midi.destinations
        sources = midi.sources
    }

    public func getDestinations() -> [CoreMIDIManager.Endpoint] { destinations }
    public func getSources() -> [CoreMIDIManager.Endpoint] { sources }

    public func selectDestination(id: CoreMIDIManager.Endpoint.ID?) async
    {
        guard let id else
        {
            midi.selectedDestination = nil
            return
        }
        midi.selectedDestination = destinations.first { $0.id == id }
    }

    public func selectSource(id: CoreMIDIManager.Endpoint.ID?) async throws
    {
        guard let id else
        {
            midi.selectedSource = nil
            try midi.connectSource()
            return
        }

        midi.selectedSource = sources.first { $0.id == id }
        try midi.connectSource()
    }

    public func setMergeEnabled(_ enabled: Bool) async throws
    {
        midi.mergeEnabled = enabled
        try midi.connectSource()
    }

    // MARK: - Channel + send modes

    public func setChannel(_ ch: Int)
    {
        channel = max(1, min(16, ch))
    }

    public func setLiveSendEnabled(_ enabled: Bool)
    {
        liveSendEnabled = enabled

        flushTask?.cancel()
        flushTask = nil

        if enabled
        {
            flushTask = Task { await self.flushLoop() }
        }
    }

    // MARK: - Parameter updates

    public func setValue(param: UInt8, value: UInt8)
    {
        values[param] = value
        if liveSendEnabled
        {
            pending[param] = value
        }
    }

    public func getValue(param: UInt8) -> UInt8
    {
        values[param] ?? 0
    }

    // MARK: - Sending

    public func sendIPRNow(param: UInt8, value: UInt8) async throws
    {
        let bytes = try SysExIPR.iprMessage(channel: channel, param: param, value: value)
        try await midi.sendSysEx(bytes, timeoutSeconds: 1.0)
        lastSentHex = Self.hex(bytes)
        lastError = nil
    }

    public func manualSendAll(interMessageDelayMs: UInt64 = 6) async
    {
        do
        {
            for p in PG300Parameters.all
            {
                let v = values[p.id] ?? 0
                let bytes = try SysExIPR.iprMessage(channel: channel, param: p.id, value: v)
                try await midi.sendSysEx(bytes, timeoutSeconds: 1.0)
                lastSentHex = Self.hex(bytes)
                if interMessageDelayMs > 0
                {
                    try await Task.sleep(nanoseconds: interMessageDelayMs * 1_000_000)
                }
            }
            lastError = nil
        }
        catch
        {
            lastError = String(describing: error)
        }
    }

    private func flushLoop() async
    {
        // Spec: 60 Hz flush for smooth sliders; coalescing keeps traffic reasonable.
        let tickNs: UInt64 = 16_666_667
        while !Task.isCancelled
        {
            await flushPending()
            try? await Task.sleep(nanoseconds: tickNs)
        }
    }

    public func flushPending() async
    {
        guard !pending.isEmpty else { return }

        let toSend = pending
        pending.removeAll(keepingCapacity: true)

        do
        {
            for (param, v) in toSend.sorted(by: { $0.key < $1.key })
            {
                let bytes = try SysExIPR.iprMessage(channel: channel, param: param, value: v)
                try await midi.sendSysEx(bytes, timeoutSeconds: 1.0)
                lastSentHex = Self.hex(bytes)
            }
            lastError = nil
        }
        catch
        {
            lastError = String(describing: error)
        }
    }

    // MARK: - Status

    public func status() -> Status
    {
        Status(
            destinationName: midi.selectedDestination?.name,
            sourceName: midi.selectedSource?.name,
            mergeEnabled: midi.mergeEnabled,
            channel: channel,
            liveSendEnabled: liveSendEnabled,
            pendingCount: pending.count,
            lastSentHex: lastSentHex,
            lastError: lastError
        )
    }

    private static func hex(_ bytes: [UInt8]) -> String
    {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

