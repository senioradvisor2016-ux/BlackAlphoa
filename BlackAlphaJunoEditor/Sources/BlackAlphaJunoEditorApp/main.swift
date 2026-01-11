import SwiftUI

@main
struct BlackAlphaJunoEditorApp: App
{
    @StateObject private var prefs = PreferencesModel()
    @StateObject private var toneMeta = ToneMetaStore()

    var body: some Scene
    {
        WindowGroup
        {
            ContentView(prefs: prefs)
                .environmentObject(toneMeta)
        }
        .windowResizability(.contentSize)

        Settings
        {
            PreferencesView(prefs: prefs)
                .frame(width: 520)
        }
    }
}

