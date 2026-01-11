import SwiftUI
import UniformTypeIdentifiers
import AlphaJunoCore
import AlphaJunoMIDI

struct ContentView: View
{
    @StateObject private var appModel = AppViewModel()
    @StateObject private var librarianModel = LibrarianViewModel()
    @ObservedObject var prefs: PreferencesModel

    @State private var showConnectionWizard: Bool = false

    var body: some View
    {
        VStack(spacing: 0)
        {
            TopBarView(appModel: appModel, prefs: prefs, showConnectionWizard: $showConnectionWizard)
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
        .onAppear
        {
            // First-run experience: show connection wizard if no MIDI Out selected.
            if appModel.selectedDestinationID == nil
            {
                showConnectionWizard = true
            }
            // Apply default send mode.
            Task { await appModel.setLiveSendEnabled(prefs.liveSendDefault) }
            Task { await appModel.setThrottleHz(prefs.throttleHz) }
        }
        .onChange(of: prefs.throttleHz) { _, newValue in
            Task { await appModel.setThrottleHz(newValue) }
        }
        .sheet(isPresented: $showConnectionWizard)
        {
            ConnectionWizardView(appModel: appModel, prefs: prefs)
        }
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
    @Published var sendInProgress: Bool = false
    @Published var sendSentCount: Int = 0
    @Published var sendTotalCount: Int = 0
    @Published var sendMode: String?
    @Published var throttleHz: Int = 60

    @Published var paramValues: [UInt8: UInt8] =
        Dictionary(uniqueKeysWithValues: PG300Parameters.all.map { ($0.id, UInt8(0)) })

    private var lastSentValues: [UInt8: UInt8] =
        Dictionary(uniqueKeysWithValues: PG300Parameters.all.map { ($0.id, UInt8(0)) })
    @Published private(set) var dirtyParamCount: Int = 0
    private var dirtyParams: Set<UInt8> = []

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

    func setThrottleHz(_ hz: Int) async
    {
        throttleHz = max(10, min(120, hz))
        guard let session else { return }
        await session.setThrottleHz(throttleHz)
        await pullStatus()
    }

    func setParamValue(_ v: UInt8, for param: UInt8)
    {
        paramValues[param] = v
        if lastSentValues[param] != v
        {
            dirtyParams.insert(param)
        }
        else
        {
            dirtyParams.remove(param)
        }
        dirtyParamCount = dirtyParams.count

        guard let session else { return }
        Task { await session.setValue(param: param, value: v) }
    }

    func manualSendAll() async
    {
        guard let session else { return }
        await session.manualSendAll()
        await pullStatus()
    }

    func manualSendAll(interMessageDelayMs: UInt64) async
    {
        guard let session else { return }
        await session.manualSendAll(interMessageDelayMs: interMessageDelayMs)
        await pullStatus()
        if lastError == nil
        {
            lastSentValues = paramValues
            dirtyParams.removeAll(keepingCapacity: true)
            dirtyParamCount = 0
        }
    }

    func manualSendChanged(interMessageDelayMs: UInt64) async
    {
        guard let session else { return }
        let params = dirtyParams.sorted()
        await session.manualSend(params: params, mode: "Changed", interMessageDelayMs: interMessageDelayMs)
        await pullStatus()
        if lastError == nil
        {
            for p in params { lastSentValues[p] = paramValues[p] ?? 0 }
            dirtyParams.subtract(params)
            dirtyParamCount = dirtyParams.count
        }
    }

    func manualSendSection(group: PGParameter.Group, interMessageDelayMs: UInt64) async
    {
        guard let session else { return }
        let params = PG300Parameters.all.filter { $0.group == group }.map(\.id).sorted()
        await session.manualSend(params: params, mode: group.rawValue, interMessageDelayMs: interMessageDelayMs)
        await pullStatus()
        if lastError == nil
        {
            for p in params { lastSentValues[p] = paramValues[p] ?? 0 }
            dirtyParams.subtract(params)
            dirtyParamCount = dirtyParams.count
        }
    }

    func cancelManualSend() async
    {
        guard let session else { return }
        await session.cancelManualSend()
        await pullStatus()
    }

    func testIPRSysEx() async -> Bool
    {
        guard let session else { return false }
        do
        {
            // Send a harmless IPR message (param 0, value 0).
            try await session.sendIPRNow(param: 0x00, value: 0x00)
            await pullStatus()
            return true
        }
        catch
        {
            lastError = String(describing: error)
            showError = true
            return false
        }
    }

    func pullStatus() async
    {
        guard let session else { return }
        let st = await session.status()
        pendingCount = st.pendingCount
        lastSentHex = st.lastSentHex
        lastError = st.lastError
        sendInProgress = st.sendInProgress
        sendSentCount = st.sendSentCount
        sendTotalCount = st.sendTotalCount
        sendMode = st.sendMode
        throttleHz = st.throttleHz
    }
}

struct TopBarView: View
{
    @ObservedObject var appModel: AppViewModel
    @ObservedObject var prefs: PreferencesModel
    @Binding var showConnectionWizard: Bool
    @State private var showSectionSheet: Bool = false
    @State private var selectedSection: PGParameter.Group = .dco

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

            Button
            {
                showConnectionWizard = true
            }
            label:
            {
                Text(appModel.selectedDestinationID == nil ? "Setup (Required)" : "Setup")
            }

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

            Menu
            {
                Button("Send All (36)")
                {
                    Task { await appModel.manualSendAll(interMessageDelayMs: UInt64(max(0, prefs.interMessageDelayMs))) }
                }

                Button("Send Changed (\(appModel.dirtyParamCount))")
                {
                    Task { await appModel.manualSendChanged(interMessageDelayMs: UInt64(max(0, prefs.interMessageDelayMs))) }
                }
                .disabled(appModel.dirtyParamCount == 0)

                Divider()

                Button("Send Section…")
                {
                    showSectionSheet = true
                }
            }
            label:
            {
                Text(appModel.sendInProgress ? "SENDING…" : "SEND")
            }
            .disabled(appModel.sendInProgress)
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .sheet(isPresented: $showSectionSheet)
            {
                VStack(alignment: .leading, spacing: 12)
                {
                    Text("Send Section")
                        .font(.title2)
                    Text("Choose a section to send as IPR SysEx.")
                        .foregroundStyle(.secondary)

                    Picker("Section", selection: $selectedSection)
                    {
                        ForEach([PGParameter.Group.dco, .vcf, .hpf, .vca, .lfo, .env, .chorus, .bender], id: \.rawValue) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack
                    {
                        Button("Cancel") { showSectionSheet = false }
                        Spacer()
                        Button("Send")
                        {
                            showSectionSheet = false
                            Task { await appModel.manualSendSection(group: selectedSection, interMessageDelayMs: UInt64(max(0, prefs.interMessageDelayMs))) }
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(18)
                .frame(width: 520)
            }
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
            HStack(spacing: 6)
            {
                Circle()
                    .fill(appModel.selectedDestinationID == nil ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(appModel.selectedDestinationID == nil ? "Disconnected" : "Connected")
                    .font(.caption)
            }

            Text("Dirty: \(appModel.dirtyParamCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appModel.sendInProgress
            {
                Text("\(appModel.sendMode ?? "Send") \(appModel.sendSentCount)/\(max(1, appModel.sendTotalCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(appModel.sendSentCount), total: Double(max(1, appModel.sendTotalCount)))
                    .frame(width: 160)
                Button("Cancel")
                {
                    Task { await appModel.cancelManualSend() }
                }
            }
            else if let last = appModel.lastSentHex
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

