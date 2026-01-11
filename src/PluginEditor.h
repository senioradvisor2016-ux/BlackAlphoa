#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

#include "MainComponent.h"
#include "PluginProcessor.h"

class AlphaJuno2EditorAudioProcessorEditor final : public juce::AudioProcessorEditor
{
public:
    explicit AlphaJuno2EditorAudioProcessorEditor (AlphaJuno2EditorAudioProcessor&);
    ~AlphaJuno2EditorAudioProcessorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    MainComponent main;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AlphaJuno2EditorAudioProcessorEditor)
};

