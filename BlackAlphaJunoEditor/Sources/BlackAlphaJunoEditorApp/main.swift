import SwiftUI

@main
struct BlackAlphaJunoEditorApp: App
{
    @StateObject private var prefs = PreferencesModel()

    var body: some Scene
    {
        WindowGroup
        {
            ContentView(prefs: prefs)
        }
        .windowResizability(.contentSize)

        Settings
        {
            PreferencesView(prefs: prefs)
                .frame(width: 520)
        }
    }
}

