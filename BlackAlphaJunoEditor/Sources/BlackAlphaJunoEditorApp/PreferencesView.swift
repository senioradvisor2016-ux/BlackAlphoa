import SwiftUI

struct PreferencesView: View
{
    @ObservedObject var prefs: PreferencesModel

    var body: some View
    {
        Form
        {
            Section("Send")
            {
                Toggle("Default Live Send", isOn: $prefs.liveSendDefault)
                Stepper("Throttle: \(prefs.throttleHz) Hz", value: $prefs.throttleHz, in: 10...120, step: 5)
                Stepper("Manual inter-message delay: \(prefs.interMessageDelayMs) ms",
                        value: $prefs.interMessageDelayMs,
                        in: 0...50,
                        step: 1)
            }

            Section("UI")
            {
                Toggle("Show SysEx hex in status bar", isOn: $prefs.showHexInStatusBar)
                Picker("Takeover mode", selection: Binding(get: {
                    prefs.takeoverMode
                }, set: { newValue in
                    prefs.takeoverMode = newValue
                }))
                {
                    ForEach(PreferencesModel.TakeoverMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
            }
        }
        .padding(12)
    }
}

