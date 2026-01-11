import Foundation

#if canImport(CoreMIDI)
import CoreMIDI

// MIDISendSysex requires the request struct to remain alive until complete.
// We heap-allocate the request, free the data buffer in this callback,
// and free the request after we observe completion.
private let sysexCompletionProc: MIDISysexSendRequestCompletionProc = { requestPtr in
    guard let requestPtr else { return }
    if let dataPtr = requestPtr.pointee.data
    {
        dataPtr.deallocate()
        requestPtr.pointee.data = nil
    }
}

public final class CoreMIDIManager: @unchecked Sendable
{
    public struct Endpoint: Identifiable, Equatable, Sendable
    {
        public let id: MIDIUniqueID
        public let name: String
        public let endpoint: MIDIEndpointRef

        public init(id: MIDIUniqueID, name: String, endpoint: MIDIEndpointRef)
        {
            self.id = id
            self.name = name
            self.endpoint = endpoint
        }
    }

    public enum Error: Swift.Error, CustomStringConvertible
    {
        case noDestinationSelected
        case coreMIDI(OSStatus)
        case timeout(seconds: Double)

        public var description: String
        {
            switch self
            {
            case .noDestinationSelected: return "No MIDI destination selected."
            case let .coreMIDI(s): return "CoreMIDI error \(s)."
            case let .timeout(seconds): return "SysEx send timed out after \(seconds)s."
            }
        }
    }

    private let client: MIDIClientRef
    private let outPort: MIDIPortRef
    private let inPort: MIDIPortRef

    public private(set) var destinations: [Endpoint] = []
    public private(set) var sources: [Endpoint] = []

    public var selectedDestination: Endpoint?
    public var selectedSource: Endpoint?
    public var mergeEnabled: Bool = false

    public init() throws
    {
        var c = MIDIClientRef()
        var o = MIDIPortRef()
        var i = MIDIPortRef()

        guard MIDIClientCreateWithBlock("BlackAlphaJunoEditor" as CFString, &c, { _ in }) == noErr else
        {
            throw Error.coreMIDI(-1)
        }

        guard MIDIOutputPortCreate(c, "Out" as CFString, &o) == noErr else
        {
            throw Error.coreMIDI(-2)
        }

        guard MIDIInputPortCreateWithBlock(c, "In" as CFString, &i, { [weak self] eventList, _ in
            guard let self else { return }
            guard self.mergeEnabled, let dest = self.selectedDestination else { return }
            MIDISendEventList(self.outPort, dest.endpoint, eventList)
        }) == noErr else
        {
            throw Error.coreMIDI(-3)
        }

        self.client = c
        self.outPort = o
        self.inPort = i

        refreshEndpoints()
    }

    deinit
    {
        MIDIPortDispose(inPort)
        MIDIPortDispose(outPort)
        MIDIClientDispose(client)
    }

    public func refreshEndpoints()
    {
        destinations = Self.fetchDestinations()
        sources = Self.fetchSources()

        if let selectedDestination, !destinations.contains(selectedDestination)
        {
            self.selectedDestination = nil
        }
        if let selectedSource, !sources.contains(selectedSource)
        {
            self.selectedSource = nil
        }
    }

    public func connectSource() throws
    {
        // disconnect all first (simple)
        for s in sources
        {
            MIDIPortDisconnectSource(inPort, s.endpoint)
        }

        guard let src = selectedSource else { return }
        let st = MIDIPortConnectSource(inPort, src.endpoint, nil)
        guard st == noErr else { throw Error.coreMIDI(st) }
    }

    /// Sends a SysEx message to the selected destination.
    /// Note: this awaits completion to avoid overlapping SysEx requests (important for rapid IPR bursts).
    public func sendSysEx(_ bytes: [UInt8], timeoutSeconds: Double = 1.0) async throws
    {
        guard let dest = selectedDestination else { throw Error.noDestinationSelected }
        guard bytes.first == 0xF0, bytes.last == 0xF7 else { throw Error.coreMIDI(-4) }

        // CoreMIDI requires a mutable buffer that stays alive until completion.
        let data = Data(bytes)
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: ptr, count: data.count)

        let req = UnsafeMutablePointer<MIDISysexSendRequest>.allocate(capacity: 1)
        req.initialize(to: MIDISysexSendRequest())
        req.pointee.destination = dest.endpoint
        req.pointee.data = ptr
        req.pointee.bytesToSend = UInt32(data.count)
        req.pointee.complete = false
        req.pointee.completionProc = sysexCompletionProc
        req.pointee.completionRefCon = nil

        let st = MIDISendSysex(req)
        guard st == noErr else
        {
            ptr.deallocate()
            req.deallocate()
            throw Error.coreMIDI(st)
        }

        // Wait for completion (avoid parallel SysEx requests).
        // Also wait until `data` has been nilled by the completionProc, so we don't race deallocation.
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !(req.pointee.complete && req.pointee.data == nil)
        {
            if Date() > deadline
            {
                // Important: do NOT deallocate `req` here; CoreMIDI may still be using it.
                // This is a controlled leak only in the timeout case.
                throw Error.timeout(seconds: timeoutSeconds)
            }
            try await Task.sleep(nanoseconds: 2_000_000) // 2ms
        }

        req.deinitialize(count: 1)
        req.deallocate()
    }

    private static func fetchDestinations() -> [Endpoint]
    {
        let count = MIDIGetNumberOfDestinations()
        return (0..<count).compactMap { idx in
            let ep = MIDIGetDestination(idx)
            return makeEndpoint(ep)
        }
    }

    private static func fetchSources() -> [Endpoint]
    {
        let count = MIDIGetNumberOfSources()
        return (0..<count).compactMap { idx in
            let ep = MIDIGetSource(idx)
            return makeEndpoint(ep)
        }
    }

    private static func makeEndpoint(_ ep: MIDIEndpointRef) -> Endpoint?
    {
        guard ep != 0 else { return nil }

        var uid: MIDIUniqueID = 0
        _ = MIDIObjectGetIntegerProperty(ep, kMIDIPropertyUniqueID, &uid)

        var pname: Unmanaged<CFString>?
        _ = MIDIObjectGetStringProperty(ep, kMIDIPropertyDisplayName, &pname)
        let name = (pname?.takeRetainedValue() as String?) ?? "MIDI \(uid)"

        return Endpoint(id: uid, name: name, endpoint: ep)
    }
}

#else

// Linux/CI-friendly stub (CoreMIDI is macOS-only).
public final class CoreMIDIManager: Sendable
{
    public struct Endpoint: Identifiable, Equatable, Sendable
    {
        public let id: Int
        public let name: String
        public init(id: Int, name: String) { self.id = id; self.name = name }
        public var endpoint: Int { id }
    }

    public enum Error: Swift.Error, CustomStringConvertible
    {
        case unsupported
        public var description: String { "CoreMIDI is not available on this platform." }
    }

    public init() throws {}

    public private(set) var destinations: [Endpoint] = []
    public private(set) var sources: [Endpoint] = []
    public var selectedDestination: Endpoint?
    public var selectedSource: Endpoint?
    public var mergeEnabled: Bool = false

    public func refreshEndpoints() {}
    public func connectSource() throws {}

    public func sendSysEx(_ bytes: [UInt8], timeoutSeconds: Double = 1.0) async throws
    {
        _ = (bytes, timeoutSeconds)
        throw Error.unsupported
    }
}

#endif

