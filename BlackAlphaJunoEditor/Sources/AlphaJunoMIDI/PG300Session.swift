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
        public var throttleHz: Int
        public var pendingCount: Int
        public var lastSentHex: String?
        public var lastError: String?
        public var sendInProgress: Bool
        public var sendSentCount: Int
        public var sendTotalCount: Int
        public var sendMode: String?
    }

    private let midi: CoreMIDIManager

    private var destinations: [CoreMIDIManager.Endpoint] = []
    private var sources: [CoreMIDIManager.Endpoint] = []

    private var channel: Int = 1
    private var liveSendEnabled: Bool = false
    private var throttleHz: Int = 60

    private var values: [UInt8: UInt8] = [:]
    private var pending: [UInt8: UInt8] = [:]

    private var flushTask: Task<Void, Never>?
    private var lastSentHex: String?
    private var lastError: String?

    private var sendInProgress: Bool = false
    private var sendSentCount: Int = 0
    private var sendTotalCount: Int = 0
    private var sendMode: String?
    private var cancelRequested: Bool = false

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

    public func setThrottleHz(_ hz: Int)
    {
        throttleHz = max(10, min(120, hz))
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
        await manualSend(params: PG300Parameters.all.map(\.id),
                         mode: "All",
                         interMessageDelayMs: interMessageDelayMs)
    }

    public func manualSend(params: [UInt8], mode: String, interMessageDelayMs: UInt64 = 6) async
    {
        if sendInProgress
        {
            lastError = "Send already in progress."
            return
        }

        cancelRequested = false
        sendInProgress = true
        sendMode = mode
        sendSentCount = 0
        sendTotalCount = params.count

        defer
        {
            sendInProgress = false
            sendMode = nil
            cancelRequested = false
        }

        do
        {
            for param in params
            {
                if Task.isCancelled || cancelRequested
                {
                    lastError = nil
                    break
                }

                let v = values[param] ?? 0
                let bytes = try SysExIPR.iprMessage(channel: channel, param: param, value: v)
                try await midi.sendSysEx(bytes, timeoutSeconds: 1.0)
                lastSentHex = Self.hex(bytes)
                sendSentCount += 1

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

    public func cancelManualSend()
    {
        cancelRequested = true
    }

    private func flushLoop() async
    {
        while !Task.isCancelled
        {
            await flushPending()
            let hz = max(10, throttleHz)
            let tickNs: UInt64 = UInt64(1_000_000_000 / hz)
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
            throttleHz: throttleHz,
            pendingCount: pending.count,
            lastSentHex: lastSentHex,
            lastError: lastError,
            sendInProgress: sendInProgress,
            sendSentCount: sendSentCount,
            sendTotalCount: sendTotalCount,
            sendMode: sendMode
        )
    }

    private static func hex(_ bytes: [UInt8]) -> String
    {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

