#include "MainComponent.h"

namespace
{
struct ParamRow final : public juce::Component
{
    ParamRow (juce::String paramName, int minV, int maxV, int initV, std::function<void (int)> onChange)
        : name (std::move (paramName)), callback (std::move (onChange))
    {
        addAndMakeVisible (label);
        label.setText (name, juce::dontSendNotification);

        addAndMakeVisible (slider);
        slider.setRange ((double) minV, (double) maxV, 1.0);
        slider.setValue ((double) initV, juce::dontSendNotification);
        slider.onValueChange = [this]
        {
            if (callback)
                callback ((int) std::lround (slider.getValue()));
        };

        addAndMakeVisible (valueLabel);
        valueLabel.setJustificationType (juce::Justification::centredRight);
        valueLabel.setText (juce::String (initV), juce::dontSendNotification);
        slider.onValueChange = [this]
        {
            const auto v = (int) std::lround (slider.getValue());
            valueLabel.setText (juce::String (v), juce::dontSendNotification);
            if (callback)
                callback (v);
        };
    }

    void resized() override
    {
        auto r = getLocalBounds().reduced (6);
        auto left = r.removeFromLeft (220);
        label.setBounds (left);

        valueLabel.setBounds (r.removeFromRight (60));
        slider.setBounds (r);
    }

    void setValue (int v)
    {
        slider.setValue ((double) v, juce::dontSendNotification);
        valueLabel.setText (juce::String (v), juce::dontSendNotification);
    }

    juce::String name;
    juce::Label label;
    juce::Slider slider { juce::Slider::LinearHorizontal, juce::Slider::TextEntryBoxPosition::NoTextBox };
    juce::Label valueLabel;
    std::function<void (int)> callback;
};

struct ParamsList final : public juce::Component
{
    explicit ParamsList (std::vector<uint8_t>& dataRef) : data (dataRef)
    {
        for (int i = 0; i < (int) data.size(); ++i)
        {
            auto* row = rows.add (new ParamRow ("Param " + juce::String (i + 1),
                                                0,
                                                127,
                                                (int) data[(size_t) i],
                                                [this, i] (int newValue)
                                                {
                                                    data[(size_t) i] = (uint8_t) juce::jlimit (0, 127, newValue);
                                                }));
            addAndMakeVisible (row);
        }
    }

    void resized() override
    {
        auto r = getLocalBounds().reduced (6);
        const int rowH = 28;
        for (auto* row : rows)
            row->setBounds (r.removeFromTop (rowH).reduced (0, 2));
    }

    int getTotalHeight() const
    {
        return 6 + (int) rows.size() * 28 + 6;
    }

    void syncFromData()
    {
        for (int i = 0; i < rows.size(); ++i)
            rows.getUnchecked (i)->setValue ((int) data[(size_t) i]);
    }

    std::vector<uint8_t>& data;
    juce::OwnedArray<ParamRow> rows;
};

inline bool parseHexByte (juce::String token, uint8_t& out)
{
    token = token.trim();
    if (token.startsWithIgnoreCase ("0x"))
        token = token.substring (2);

    if (token.isEmpty() || token.length() > 2)
        return false;

    const auto v = token.getHexValue32();
    if (v < 0 || v > 0xFF)
        return false;

    out = (uint8_t) v;
    return true;
}

inline bool parseHexTriplet (juce::String s, std::array<uint8_t, 3>& out)
{
    auto toks = juce::StringArray::fromTokens (s, " ,\t", "");
    toks.removeEmptyStrings (true);
    if (toks.size() != 3)
        return false;

    uint8_t b0{}, b1{}, b2{};
    if (! parseHexByte (toks[0], b0)) return false;
    if (! parseHexByte (toks[1], b1)) return false;
    if (! parseHexByte (toks[2], b2)) return false;
    out = { b0, b1, b2 };
    return true;
}
}

MainComponent::MainComponent()
{
    setSize (1080, 720);

    setLookAndFeel (&lookAndFeel);

    addAndMakeVisible (lcd);
    lcd.setText ("ALPHA JUNO-2 EDITOR");
    lcd.setRightText ("MIDI: --  CH: 1");

    midiPanel.setTitle ("MIDI");
    actionsPanel.setTitle ("ACTIONS");
    rolandPanel.setTitle ("ROLAND SYSEX");
    paramsPanel.setTitle ("PARAMETERS (PLACEHOLDER)");
    logPanel.setTitle ("LOG");

    addAndMakeVisible (midiPanel);
    addAndMakeVisible (actionsPanel);
    addAndMakeVisible (rolandPanel);
    addAndMakeVisible (paramsPanel);
    addAndMakeVisible (logPanel);

    addAndMakeVisible (refreshButton);
    refreshButton.onClick = [this]
    {
        refreshMidiDeviceLists();
        logLine ("Refreshed MIDI device list.");
    };

    addAndMakeVisible (midiInLabel);
    addAndMakeVisible (midiOutLabel);

    addAndMakeVisible (midiInBox);
    addAndMakeVisible (midiOutBox);

    midiInBox.onChange = [this] { openSelectedMidiInput(); };
    midiOutBox.onChange = [this] { openSelectedMidiOutput(); };

    addAndMakeVisible (loadButton);
    addAndMakeVisible (saveButton);
    addAndMakeVisible (sendButton);
    addAndMakeVisible (requestButton);
    addAndMakeVisible (sendDT1Button);

    loadButton.onClick = [this] { loadSyxFromDisk(); };
    saveButton.onClick = [this] { saveSyxToDisk(); };
    sendButton.onClick = [this] { sendRawSyx(); };
    requestButton.onClick = [this] { requestPatch(); };
    sendDT1Button.onClick = [this] { sendWorkingDT1(); };

    addAndMakeVisible (deviceIdLabel);
    addAndMakeVisible (modelIdLabel);
    addAndMakeVisible (deviceIdHex);
    addAndMakeVisible (modelIdHex);
    addAndMakeVisible (addressLabel);
    addAndMakeVisible (sizeLabel);
    addAndMakeVisible (addressHex);
    addAndMakeVisible (sizeHex);

    deviceIdHex.setText ("10", juce::dontSendNotification);
    modelIdHex.setText ("35", juce::dontSendNotification);
    addressHex.setText ("00 00 00", juce::dontSendNotification);
    sizeHex.setText ("00 00 20", juce::dontSendNotification); // 32 bytes == our placeholder workingData

    deviceIdHex.onTextChange = [this]
    {
        uint8_t b{};
        if (parseHexByte (deviceIdHex.getText(), b))
            ids.deviceId = b;
    };

    modelIdHex.onTextChange = [this]
    {
        uint8_t b{};
        if (parseHexByte (modelIdHex.getText(), b))
            ids.modelId = b;
    };

    addAndMakeVisible (paramsViewport);
    paramsViewport.setScrollBarsShown (true, false);

    workingData.assign (32, 0);
    paramsContent = std::make_unique<ParamsList> (workingData);
    paramsViewport.setViewedComponent (paramsContent.get(), false);

    addAndMakeVisible (log);
    log.setMultiLine (true);
    log.setReadOnly (true);
    log.setScrollbarsShown (true);
    log.setFont (juce::Font (juce::FontOptions().withHeight (13.0f)));

    refreshMidiDeviceLists();
    startTimerHz (10);
    logLine ("Ready. Select MIDI In/Out. Load a .syx or use RQ1/DT1.");
}

MainComponent::~MainComponent()
{
    closeMidiDevices();
    setLookAndFeel (nullptr);
}

void MainComponent::paint (juce::Graphics& g)
{
    juce::ColourGradient bg (theme.bg0, 0.0f, 0.0f, theme.bg1, 0.0f, (float) getHeight(), false);
    g.setGradientFill (bg);
    g.fillAll();
}

void MainComponent::resized()
{
    auto r = getLocalBounds().reduced (12);

    // LCD strip
    auto top = r.removeFromTop (64);
    lcd.setBounds (top.removeFromTop (54));
    r.removeFromTop (10);

    // Top row panels: MIDI + Actions
    auto topRow = r.removeFromTop (118);
    auto midiArea = topRow.removeFromLeft (520);
    topRow.removeFromLeft (10);
    auto actionsArea = topRow;

    midiPanel.setBounds (midiArea);
    actionsPanel.setBounds (actionsArea);

    auto mp = midiArea.reduced (14);
    mp.removeFromTop (20);
    auto m1 = mp.removeFromTop (28);
    midiInLabel.setBounds (m1.removeFromLeft (60));
    midiInBox.setBounds (m1.removeFromLeft (340));
    m1.removeFromLeft (10);
    refreshButton.setBounds (m1.removeFromLeft (100));
    mp.removeFromTop (10);
    auto m2 = mp.removeFromTop (28);
    midiOutLabel.setBounds (m2.removeFromLeft (70));
    midiOutBox.setBounds (m2.removeFromLeft (330));

    auto ap = actionsArea.reduced (14);
    ap.removeFromTop (20);
    auto a1 = ap.removeFromTop (28);
    loadButton.setBounds (a1.removeFromLeft (120));
    a1.removeFromLeft (8);
    saveButton.setBounds (a1.removeFromLeft (120));
    a1.removeFromLeft (8);
    sendButton.setBounds (a1.removeFromLeft (200));
    ap.removeFromTop (10);
    auto a2 = ap.removeFromTop (28);
    requestButton.setBounds (a2.removeFromLeft (220));
    a2.removeFromLeft (8);
    sendDT1Button.setBounds (a2.removeFromLeft (240));

    r.removeFromTop (10);

    // Middle: Roland panel
    auto mid = r.removeFromTop (190);
    rolandPanel.setBounds (mid);
    auto gg = mid.reduced (14);
    gg.removeFromTop (20);

    auto rr1 = gg.removeFromTop (26);
    deviceIdLabel.setBounds (rr1.removeFromLeft (130));
    deviceIdHex.setBounds (rr1.removeFromLeft (80));
    rr1.removeFromLeft (12);
    modelIdLabel.setBounds (rr1.removeFromLeft (110));
    modelIdHex.setBounds (rr1.removeFromLeft (80));

    gg.removeFromTop (8);
    auto rr2 = gg.removeFromTop (26);
    addressLabel.setBounds (rr2.removeFromLeft (300));
    addressHex.setBounds (rr2.removeFromLeft (160));

    gg.removeFromTop (8);
    auto rr3 = gg.removeFromTop (26);
    sizeLabel.setBounds (rr3.removeFromLeft (300));
    sizeHex.setBounds (rr3.removeFromLeft (160));

    r.removeFromTop (10);

    // Bottom: params + log
    auto bottom = r;
    auto left = bottom.removeFromLeft (560);
    bottom.removeFromLeft (10);
    auto right = bottom;

    paramsPanel.setBounds (left);
    auto pg = left.reduced (14);
    pg.removeFromTop (20);
    paramsViewport.setBounds (pg);

    // keep the inner list tall enough for scrolling
    if (auto* list = dynamic_cast<ParamsList*> (paramsContent.get()))
        paramsContent->setSize (pg.getWidth() - 18, list->getTotalHeight());

    logPanel.setBounds (right);
    auto lg = right.reduced (14);
    lg.removeFromTop (20);
    log.setBounds (lg);
}

void MainComponent::refreshMidiDeviceLists()
{
    const auto inputs = juce::MidiInput::getAvailableDevices();
    const auto outputs = juce::MidiOutput::getAvailableDevices();

    auto currentIn = midiInBox.getText();
    auto currentOut = midiOutBox.getText();

    midiInBox.clear();
    midiOutBox.clear();

    int idx = 1;
    for (const auto& d : inputs)
        midiInBox.addItem (d.name, idx++);

    idx = 1;
    for (const auto& d : outputs)
        midiOutBox.addItem (d.name, idx++);

    midiInBox.setText (currentIn, juce::dontSendNotification);
    midiOutBox.setText (currentOut, juce::dontSendNotification);
}

void MainComponent::openSelectedMidiInput()
{
    const auto inputs = juce::MidiInput::getAvailableDevices();
    const int sel = midiInBox.getSelectedItemIndex();

    midiIn.reset();

    if (sel < 0 || sel >= inputs.size())
        return;

    selectedInputInfo = inputs.getReference (sel);
    midiIn = juce::MidiInput::openDevice (selectedInputInfo.identifier, this);

    if (midiIn)
    {
        midiIn->start();
        logLine ("Opened MIDI In: " + selectedInputInfo.name);
    }
    else
    {
        logLine ("Failed to open MIDI In: " + selectedInputInfo.name);
    }
}

void MainComponent::openSelectedMidiOutput()
{
    const auto outputs = juce::MidiOutput::getAvailableDevices();
    const int sel = midiOutBox.getSelectedItemIndex();

    midiOut.reset();

    if (sel < 0 || sel >= outputs.size())
        return;

    selectedOutputInfo = outputs.getReference (sel);
    midiOut = juce::MidiOutput::openDevice (selectedOutputInfo.identifier);

    if (midiOut)
        logLine ("Opened MIDI Out: " + selectedOutputInfo.name);
    else
        logLine ("Failed to open MIDI Out: " + selectedOutputInfo.name);
}

void MainComponent::closeMidiDevices()
{
    if (midiIn)
        midiIn->stop();
    midiIn.reset();
    midiOut.reset();
}

void MainComponent::handleIncomingMidiMessage (juce::MidiInput*, const juce::MidiMessage& message)
{
    if (message.isSysEx())
    {
        lastReceivedSysex = message;
        logLine ("Rx SysEx (" + juce::String (message.getRawDataSize()) + " bytes)."
                 + (roland::isRolandSysex (message) ? " Roland header detected." : ""));
        return;
    }
}

void MainComponent::timerCallback()
{
    // currently unused (kept for future: async UI updates, LED indicators, etc.)
}

void MainComponent::loadSyxFromDisk()
{
    juce::FileChooser fc ("Load SysEx (.syx)", juce::File{}, "*.syx");
    if (! fc.browseForFileToOpen())
        return;

    auto f = fc.getResult();
    juce::MemoryBlock mb;
    if (! f.loadFileAsData (mb))
    {
        logLine ("Failed to read file: " + f.getFullPathName());
        return;
    }

    const auto* bytes = static_cast<const uint8_t*> (mb.getData());
    const auto n = (int) mb.getSize();

    // Find the first F0..F7 block and load it as the "loadedSysex".
    int start = -1, end = -1;
    for (int i = 0; i < n; ++i)
    {
        if (bytes[i] == 0xF0) { start = i; break; }
    }
    if (start >= 0)
    {
        for (int i = start + 1; i < n; ++i)
        {
            if (bytes[i] == 0xF7) { end = i; break; }
        }
    }

    if (start < 0 || end < 0 || end <= start)
    {
        logLine ("No SysEx (F0..F7) found in: " + f.getFileName());
        return;
    }

    loadedSysex = juce::MidiMessage (bytes + start, end - start + 1);
    logLine ("Loaded SysEx from disk (" + juce::String (loadedSysex.getRawDataSize()) + " bytes).");
}

void MainComponent::saveSyxToDisk()
{
    const bool hasLoaded = loadedSysex.getRawDataSize() > 0 && loadedSysex.isSysEx();
    const bool hasRx = lastReceivedSysex.getRawDataSize() > 0 && lastReceivedSysex.isSysEx();

    if (! hasLoaded && ! hasRx)
    {
        logLine ("Nothing to save (load or receive a SysEx first).");
        return;
    }

    juce::FileChooser fc ("Save SysEx (.syx)", juce::File::getSpecialLocation (juce::File::userHomeDirectory).getChildFile ("patch.syx"), "*.syx");
    if (! fc.browseForFileToSave (true))
        return;

    const auto target = fc.getResult();
    const auto& msg = hasLoaded ? loadedSysex : lastReceivedSysex;

    juce::MemoryBlock mb (msg.getRawData(), (size_t) msg.getRawDataSize());
    if (target.replaceWithData (mb.getData(), mb.getSize()))
        logLine ("Saved: " + target.getFullPathName());
    else
        logLine ("Failed to save: " + target.getFullPathName());
}

void MainComponent::sendRawSyx()
{
    if (! midiOut)
    {
        logLine ("No MIDI Out open.");
        return;
    }

    if (! loadedSysex.isSysEx() || loadedSysex.getRawDataSize() <= 0)
    {
        logLine ("No loaded SysEx to send. Use 'Load .syx' first.");
        return;
    }

    midiOut->sendMessageNow (loadedSysex);
    logLine ("Tx loaded SysEx (" + juce::String (loadedSysex.getRawDataSize()) + " bytes).");
}

void MainComponent::requestPatch()
{
    if (! midiOut)
    {
        logLine ("No MIDI Out open.");
        return;
    }

    std::array<uint8_t, 3> addr { 0, 0, 0 };
    std::array<uint8_t, 3> size { 0, 0, 0 };

    if (! parseHexTriplet (addressHex.getText(), addr))
    {
        logLine ("Invalid address format. Expected 3 hex bytes like: 00 00 00");
        return;
    }

    if (! parseHexTriplet (sizeHex.getText(), size))
    {
        logLine ("Invalid size format. Expected 3 hex bytes like: 00 00 20");
        return;
    }

    const auto m = roland::makeRQ1 (ids, addr, size);
    midiOut->sendMessageNow (m);
    logLine ("Tx RQ1 (request) to address " + addressHex.getText().trim() + " size " + sizeHex.getText().trim());
}

void MainComponent::sendWorkingDT1()
{
    if (! midiOut)
    {
        logLine ("No MIDI Out open.");
        return;
    }

    std::array<uint8_t, 3> addr { 0, 0, 0 };
    if (! parseHexTriplet (addressHex.getText(), addr))
    {
        logLine ("Invalid address format. Expected 3 hex bytes like: 00 00 00");
        return;
    }

    const auto m = roland::makeDT1 (ids, addr, workingData);
    midiOut->sendMessageNow (m);
    logLine ("Tx DT1 (data) " + juce::String ((int) workingData.size()) + " bytes to address " + addressHex.getText().trim());
}

void MainComponent::logLine (juce::String s)
{
    const auto ts = juce::Time::getCurrentTime().toString (true, true);
    log.moveCaretToEnd();
    log.insertTextAtCaret ("[" + ts + "] " + s + "\n");
}

