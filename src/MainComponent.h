#pragma once

#include <juce_gui_extra/juce_gui_extra.h>
#include <juce_audio_devices/juce_audio_devices.h>

#include "RolandSysex.h"
#include "ui/UheLookAndFeel.h"
#include "ui/UhePanel.h"
#include "ui/LCDDisplay.h"

class MainComponent final : public juce::Component,
                            private juce::MidiInputCallback,
                            private juce::Timer
{
public:
    MainComponent();
    ~MainComponent() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    // ==== MIDI ====
    void refreshMidiDeviceLists();
    void openSelectedMidiInput();
    void openSelectedMidiOutput();
    void closeMidiDevices();

    void handleIncomingMidiMessage (juce::MidiInput* source, const juce::MidiMessage& message) override;
    void timerCallback() override;

    // ==== UI actions ====
    void loadSyxFromDisk();
    void saveSyxToDisk();
    void sendRawSyx();
    void requestPatch();
    void sendWorkingDT1();

    void logLine (juce::String s);

    // ==== State ====
    juce::MidiDeviceInfo selectedInputInfo;
    juce::MidiDeviceInfo selectedOutputInfo;
    std::unique_ptr<juce::MidiInput> midiIn;
    std::unique_ptr<juce::MidiOutput> midiOut;

    juce::MidiMessage lastReceivedSysex;
    juce::MidiMessage loadedSysex;
    std::vector<uint8_t> workingData;

    // ==== UI ====
    uhe::Theme theme;
    uhe::LookAndFeel lookAndFeel { theme };
    uhe::LCDDisplay lcd { theme };

    uhe::Panel midiPanel { theme };
    uhe::Panel actionsPanel { theme };
    uhe::Panel rolandPanel { theme };
    uhe::Panel paramsPanel { theme };
    uhe::Panel logPanel { theme };

    juce::TextButton refreshButton { "Refresh MIDI" };
    juce::ComboBox midiInBox;
    juce::ComboBox midiOutBox;
    juce::Label midiInLabel { {}, "MIDI In" };
    juce::Label midiOutLabel { {}, "MIDI Out" };

    juce::TextButton loadButton { "Load .syx" };
    juce::TextButton saveButton { "Save .syx" };
    juce::TextButton sendButton { "Send loaded SysEx" };
    juce::TextButton requestButton { "Request patch (RQ1)" };
    juce::TextButton sendDT1Button { "Send working data (DT1)" };

    // Roland SysEx controls (within rolandPanel)
    juce::Label deviceIdLabel { {}, "Device ID (hex)" };
    juce::Label modelIdLabel { {}, "Model ID (hex)" };
    juce::TextEditor deviceIdHex;
    juce::TextEditor modelIdHex;

    juce::Label addressLabel { {}, "Address (3 bytes hex, e.g. 00 00 00)" };
    juce::Label sizeLabel { {}, "Size (3 bytes hex, e.g. 00 00 20)" };
    juce::TextEditor addressHex;
    juce::TextEditor sizeHex;

    // Params (within paramsPanel)
    juce::Viewport paramsViewport;
    std::unique_ptr<juce::Component> paramsContent;

    juce::TextEditor log;

    roland::DeviceIds ids;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainComponent)
};

