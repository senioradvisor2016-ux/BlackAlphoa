import SwiftUI
import AlphaJunoMIDI

struct ConnectionWizardView: View
{
    @ObservedObject var appModel: AppViewModel
    @ObservedObject var prefs: PreferencesModel

    @Environment(\.dismiss) private var dismiss

    @State private var sendingTest: Bool = false
    @State private var testResult: String?

    var body: some View
    {
        VStack(alignment: .leading, spacing: 14)
        {
            Text("Connection Wizard")
                .font(.title2)

            Text("Select MIDI Out (to the synth), optional MIDI In (for merge/thru), then test SysEx.")
                .foregroundStyle(.secondary)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10)
            {
                GridRow
                {
                    Text("MIDI Out")
                    Picker("", selection: $appModel.selectedDestinationID)
                    {
                        Text("None").tag(CoreMIDIManager.Endpoint.ID?.none)
                        ForEach(appModel.destinations) { d in
                            Text(d.name).tag(Optional(d.id))
                        }
                    }
                    .frame(width: 420)
                    .onChange(of: appModel.selectedDestinationID) { _, newValue in
                        Task { await appModel.selectDestination(newValue) }
                    }
                }

                GridRow
                {
                    Text("MIDI In")
                    Picker("", selection: $appModel.selectedSourceID)
                    {
                        Text("None").tag(CoreMIDIManager.Endpoint.ID?.none)
                        ForEach(appModel.sources) { s in
                            Text(s.name).tag(Optional(s.id))
                        }
                    }
                    .frame(width: 420)
                    .onChange(of: appModel.selectedSourceID) { _, newValue in
                        Task { await appModel.selectSource(newValue) }
                    }
                }

                GridRow
                {
                    Text("Merge/Thru")
                    Toggle("Enabled", isOn: $appModel.mergeEnabled)
                        .onChange(of: appModel.mergeEnabled) { _, newValue in
                            Task { await appModel.setMergeEnabled(newValue) }
                        }
                }

                GridRow
                {
                    Text("Channel")
                    Stepper("Ch \(appModel.channel)", value: $appModel.channel, in: 1...16)
                        .onChange(of: appModel.channel) { _, newValue in
                            Task { await appModel.setChannel(newValue) }
                        }
                }

                GridRow
                {
                    Text("Live Send")
                    Toggle("Enabled", isOn: $appModel.liveSendEnabled)
                        .onChange(of: appModel.liveSendEnabled) { _, newValue in
                            Task { await appModel.setLiveSendEnabled(newValue) }
                        }
                }

                GridRow
                {
                    Text("Throttle")
                    Stepper("\(prefs.throttleHz) Hz", value: $prefs.throttleHz, in: 10...120, step: 5)
                }

                GridRow
                {
                    Text("Manual delay")
                    Stepper("\(prefs.interMessageDelayMs) ms", value: $prefs.interMessageDelayMs, in: 0...50, step: 1)
                }
            }

            Divider()

            HStack(spacing: 10)
            {
                Button("Refresh MIDI")
                {
                    Task { await appModel.refreshEndpoints() }
                }

                Button(sendingTest ? "Sending…" : "Test SysEx (IPR)")
                {
                    Task { await runTest() }
                }
                .disabled(sendingTest || appModel.selectedDestinationID == nil)

                if let testResult
                {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done")
                {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 640)
        .onChange(of: prefs.throttleHz) { _, newValue in
            Task { await appModel.setThrottleHz(newValue) }
        }
    }

    private func runTest() async
    {
        sendingTest = true
        testResult = nil
        defer { sendingTest = false }

        let ok = await appModel.testIPRSysEx()
        testResult = ok ? "Sent IPR test message." : "Test failed (see status / errors)."
    }
}

