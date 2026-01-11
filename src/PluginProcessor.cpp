#include "PluginProcessor.h"
#include "PluginEditor.h"

AlphaJuno2EditorAudioProcessor::AlphaJuno2EditorAudioProcessor()
    : juce::AudioProcessor (BusesProperties()
                                .withInput  ("Input",  juce::AudioChannelSet::stereo(), false)
                                .withOutput ("Output", juce::AudioChannelSet::stereo(), false))
{
}

AlphaJuno2EditorAudioProcessor::~AlphaJuno2EditorAudioProcessor() = default;

const juce::String AlphaJuno2EditorAudioProcessor::getName() const
{
    return "Alpha Juno-2 Editor";
}

bool AlphaJuno2EditorAudioProcessor::acceptsMidi() const       { return true; }
bool AlphaJuno2EditorAudioProcessor::producesMidi() const      { return false; }
bool AlphaJuno2EditorAudioProcessor::isMidiEffect() const      { return false; }
double AlphaJuno2EditorAudioProcessor::getTailLengthSeconds() const { return 0.0; }

int AlphaJuno2EditorAudioProcessor::getNumPrograms()           { return 1; }
int AlphaJuno2EditorAudioProcessor::getCurrentProgram()        { return 0; }
void AlphaJuno2EditorAudioProcessor::setCurrentProgram (int)   {}
const juce::String AlphaJuno2EditorAudioProcessor::getProgramName (int) { return {}; }
void AlphaJuno2EditorAudioProcessor::changeProgramName (int, const juce::String&) {}

void AlphaJuno2EditorAudioProcessor::prepareToPlay (double, int) {}
void AlphaJuno2EditorAudioProcessor::releaseResources() {}

bool AlphaJuno2EditorAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    // This plugin is effectively "editor-only"; keep layouts simple.
    return layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo()
        || layouts.getMainOutputChannelSet().isDisabled();
}

void AlphaJuno2EditorAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    juce::ignoreUnused (midi);
    buffer.clear();
}

bool AlphaJuno2EditorAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* AlphaJuno2EditorAudioProcessor::createEditor()
{
    return new AlphaJuno2EditorAudioProcessorEditor (*this);
}

void AlphaJuno2EditorAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    // TODO: persist editor state (MIDI port selection, etc.)
    destData.reset();
}

void AlphaJuno2EditorAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    juce::ignoreUnused (data, sizeInBytes);
}

// This creates new plugin instances.
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new AlphaJuno2EditorAudioProcessor();
}

