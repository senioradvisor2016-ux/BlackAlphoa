#pragma once

#include <juce_audio_devices/juce_audio_devices.h>
#include <array>
#include <cstdint>
#include <vector>

namespace roland
{
// Roland checksum used by many legacy devices:
// checksum = (128 - (sum(data) & 0x7f)) & 0x7f
inline uint8_t checksum7bit (const uint8_t* data, size_t size)
{
    uint32_t sum = 0;
    for (size_t i = 0; i < size; ++i)
        sum += data[i];

    return static_cast<uint8_t> ((128 - (sum & 0x7f)) & 0x7f);
}

inline uint8_t checksum7bit (const std::vector<uint8_t>& data)
{
    return checksum7bit (data.data(), data.size());
}

// Minimal "Roland-style" builder for RQ1 (0x11) and DT1 (0x12).
// Many Roland synths differ in model-id length and addressing; this is intentionally configurable.
struct DeviceIds
{
    // For many Roland devices the "Device ID" byte is 0x10..0x1f (unit 0..15).
    // If your device expects something else, edit it in the UI.
    uint8_t deviceId = 0x10;
    uint8_t modelId  = 0x35; // Unknown default for Alpha Juno-2; change in UI.
};

inline juce::MidiMessage makeRQ1 (DeviceIds ids,
                                 std::array<uint8_t, 3> address,
                                 std::array<uint8_t, 3> size)
{
    std::vector<uint8_t> msg;
    msg.reserve (1 + 1 + 1 + 1 + 1 + 3 + 3 + 1 + 1);

    msg.push_back (0xF0);
    msg.push_back (0x41);
    msg.push_back (ids.deviceId);
    msg.push_back (ids.modelId);
    msg.push_back (0x11); // RQ1

    msg.insert (msg.end(), address.begin(), address.end());
    msg.insert (msg.end(), size.begin(), size.end());

    std::vector<uint8_t> cksumData;
    cksumData.reserve (3 + 3);
    cksumData.insert (cksumData.end(), address.begin(), address.end());
    cksumData.insert (cksumData.end(), size.begin(), size.end());
    msg.push_back (checksum7bit (cksumData));

    msg.push_back (0xF7);
    return juce::MidiMessage (msg.data(), (int) msg.size());
}

inline juce::MidiMessage makeDT1 (DeviceIds ids,
                                 std::array<uint8_t, 3> address,
                                 const std::vector<uint8_t>& data)
{
    std::vector<uint8_t> msg;
    msg.reserve (1 + 1 + 1 + 1 + 1 + 3 + data.size() + 1 + 1);

    msg.push_back (0xF0);
    msg.push_back (0x41);
    msg.push_back (ids.deviceId);
    msg.push_back (ids.modelId);
    msg.push_back (0x12); // DT1

    msg.insert (msg.end(), address.begin(), address.end());
    msg.insert (msg.end(), data.begin(), data.end());

    std::vector<uint8_t> cksumData;
    cksumData.reserve (3 + data.size());
    cksumData.insert (cksumData.end(), address.begin(), address.end());
    cksumData.insert (cksumData.end(), data.begin(), data.end());
    msg.push_back (checksum7bit (cksumData));

    msg.push_back (0xF7);
    return juce::MidiMessage (msg.data(), (int) msg.size());
}

inline bool isRolandSysex (const juce::MidiMessage& m)
{
    if (! m.isSysEx())
        return false;

    const auto* d = m.getSysExData();
    const auto n = (size_t) m.getSysExDataSize();
    if (n < 2)
        return false;

    // Note: JUCE SysEx buffer excludes 0xF0 and 0xF7 in MidiMessage::getSysExData()
    // so "Roland" starts with 0x41.
    return d[0] == 0x41;
}
}

