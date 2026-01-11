import SwiftUI
import UniformTypeIdentifiers
import AlphaJunoCore
import AlphaJunoMIDI

struct ContentView: View
{
    @StateObject private var appModel = AppViewModel()
    @StateObject private var librarianModel = LibrarianViewModel()

    var body: some View
    {
        VStack(spacing: 0)
        {
            TopBarView(appModel: appModel)
                .padding(12)
            Divider()

            HSplitView
            {
                LibrarianView(model: librarianModel)
                    .frame(minWidth: 320, idealWidth: 360)

                EditorView(appModel: appModel)
                    .frame(minWidth: 700, idealWidth: 900)
            }
            .frame(minHeight: 620)

            Divider()
            StatusBarView(appModel: appModel)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minWidth: 1100, idealWidth: 1280, minHeight: 740, idealHeight: 820)
        .alert("MIDI Error", isPresented: $appModel.showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(appModel.lastError ?? "Unknown error")
        })
    }
}

@MainActor
final class AppViewModel: ObservableObject
{
    @Published var destinations: [CoreMIDIManager.Endpoint] = []
    @Published var sources: [CoreMIDIManager.Endpoint] = []

    @Published var selectedDestinationID: CoreMIDIManager.Endpoint.ID?
    @Published var selectedSourceID: CoreMIDIManager.Endpoint.ID?

    @Published var mergeEnabled: Bool = false
    @Published var channel: Int = 1
    @Published var liveSendEnabled: Bool = false // default OFF (manual send)

    @Published var pendingCount: Int = 0
    @Published var lastSentHex: String?
    @Published var lastError: String?
    @Published var showError: Bool = false

    @Published var paramValues: [UInt8: UInt8] =
        Dictionary(uniqueKeysWithValues: PG300Parameters.all.map { ($0.id, UInt8(0)) })

    private var session: PG300Session?

    init()
    {
        Task { await start() }
    }

    func start() async
    {
        do
        {
            let s = try PG300Session()
            session = s

            await refreshEndpoints()
            await setChannel(channel)
            await setMergeEnabled(false)
            await setLiveSendEnabled(false)

            // Periodic status polling (UI only).
            Task { [weak self] in
                guard let self else { return }
                while true
                {
                    await self.pullStatus()
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
        }
        catch
        {
            lastError = String(describing: error)
            showError = true
        }
    }

    func refreshEndpoints() async
    {
        guard let session else { return }
        await session.refreshEndpoints()
        destinations = await session.getDestinations()
        sources = await session.getSources()
    }

    func selectDestination(_ id: CoreMIDIManager.Endpoint.ID?) async
    {
        selectedDestinationID = id
        guard let session else { return }
        await session.selectDestination(id: id)
        await pullStatus()
    }

    func selectSource(_ id: CoreMIDIManager.Endpoint.ID?) async
    {
        selectedSourceID = id
        guard let session else { return }
        do
        {
            try await session.selectSource(id: id)
        }
        catch
        {
            lastError = String(describing: error)
            showError = true
        }
        await pullStatus()
    }

    func setMergeEnabled(_ enabled: Bool) async
    {
        mergeEnabled = enabled
        guard let session else { return }
        do
        {
            try await session.setMergeEnabled(enabled)
        }
        catch
        {
            lastError = String(describing: error)
            showError = true
        }
        await pullStatus()
    }

    func setChannel(_ ch: Int) async
    {
        channel = max(1, min(16, ch))
        guard let session else { return }
        await session.setChannel(channel)
        await pullStatus()
    }

    func setLiveSendEnabled(_ enabled: Bool) async
    {
        liveSendEnabled = enabled
        guard let session else { return }
        await session.setLiveSendEnabled(enabled)
        await pullStatus()
    }

    func setParamValue(_ v: UInt8, for param: UInt8)
    {
        paramValues[param] = v
        guard let session else { return }
        Task { await session.setValue(param: param, value: v) }
    }

    func manualSendAll() async
    {
        guard let session else { return }
        await session.manualSendAll()
        await pullStatus()
    }

    func pullStatus() async
    {
        guard let session else { return }
        let st = await session.status()
        pendingCount = st.pendingCount
        lastSentHex = st.lastSentHex
        lastError = st.lastError
    }
}

struct TopBarView: View
{
    @ObservedObject var appModel: AppViewModel

    var body: some View
    {
        HStack(spacing: 14)
        {
            VStack(alignment: .leading, spacing: 2)
            {
                Text("BlackAlpha — Alpha Juno-2 / MKS-50 Editor")
                    .font(.headline)
                Text("IPR SysEx • Manual Send default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("MIDI Out", selection: Binding(get: {
                appModel.selectedDestinationID
            }, set: { newValue in
                Task { await appModel.selectDestination(newValue) }
            }))
            {
                Text("None").tag(CoreMIDIManager.Endpoint.ID?.none)
                ForEach(appModel.destinations) { d in
                    Text(d.name).tag(Optional(d.id))
                }
            }
            .frame(width: 260)

            Picker("MIDI In", selection: Binding(get: {
                appModel.selectedSourceID
            }, set: { newValue in
                Task { await appModel.selectSource(newValue) }
            }))
            {
                Text("None").tag(CoreMIDIManager.Endpoint.ID?.none)
                ForEach(appModel.sources) { s in
                    Text(s.name).tag(Optional(s.id))
                }
            }
            .frame(width: 260)

            Toggle("Merge", isOn: Binding(get: {
                appModel.mergeEnabled
            }, set: { v in
                Task { await appModel.setMergeEnabled(v) }
            }))
            .toggleStyle(.switch)

            Stepper("Ch \(appModel.channel)", value: Binding(get: {
                appModel.channel
            }, set: { v in
                Task { await appModel.setChannel(v) }
            }), in: 1...16)
            .frame(width: 110)

            Toggle("Live", isOn: Binding(get: {
                appModel.liveSendEnabled
            }, set: { v in
                Task { await appModel.setLiveSendEnabled(v) }
            }))
            .toggleStyle(.switch)

            Button("MANUAL SEND")
            {
                Task { await appModel.manualSendAll() }
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
    }
}

struct StatusBarView: View
{
    @ObservedObject var appModel: AppViewModel

    var body: some View
    {
        HStack(spacing: 12)
        {
            Text("Pending: \(appModel.pendingCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let last = appModel.lastSentHex
            {
                Text("Last SysEx: \(last)")
                    .font(.caption2)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
            else
            {
                Text("Last SysEx: —")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Refresh MIDI")
            {
                Task { await appModel.refreshEndpoints() }
            }
        }
    }
}

