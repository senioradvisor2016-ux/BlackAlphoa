#include "PluginEditor.h"

AlphaJuno2EditorAudioProcessorEditor::AlphaJuno2EditorAudioProcessorEditor (AlphaJuno2EditorAudioProcessor& p)
    : juce::AudioProcessorEditor (&p)
{
    addAndMakeVisible (main);
    setSize (main.getWidth(), main.getHeight());
}

AlphaJuno2EditorAudioProcessorEditor::~AlphaJuno2EditorAudioProcessorEditor() = default;

void AlphaJuno2EditorAudioProcessorEditor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::black);
}

void AlphaJuno2EditorAudioProcessorEditor::resized()
{
    main.setBounds (getLocalBounds());
}

