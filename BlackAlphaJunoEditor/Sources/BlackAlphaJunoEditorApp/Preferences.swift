import Foundation
import SwiftUI

@MainActor
final class PreferencesModel: ObservableObject
{
    // Transport / send behavior
    @AppStorage("prefs.liveSendDefault") var liveSendDefault: Bool = false
    @AppStorage("prefs.throttleHz") var throttleHz: Int = 60
    @AppStorage("prefs.interMessageDelayMs") var interMessageDelayMs: Int = 6

    // UI behavior
    @AppStorage("prefs.showHexInStatusBar") var showHexInStatusBar: Bool = true

    enum TakeoverMode: String, CaseIterable
    {
        case jump
        case pickup
    }

    // Placeholder for a future custom knob control. For SwiftUI Slider this is not enforced yet.
    @AppStorage("prefs.takeoverMode") var takeoverModeRaw: String = TakeoverMode.jump.rawValue
    var takeoverMode: TakeoverMode
    {
        get { TakeoverMode(rawValue: takeoverModeRaw) ?? .jump }
        set { takeoverModeRaw = newValue.rawValue }
    }
}

