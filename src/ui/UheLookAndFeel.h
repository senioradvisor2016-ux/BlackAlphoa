#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "UheTheme.h"

namespace uhe
{
class LookAndFeel final : public juce::LookAndFeel_V4
{
public:
    explicit LookAndFeel (Theme t = {}) : theme (t)
    {
        setColour (juce::Label::textColourId, theme.textPrimary);
        setColour (juce::TextEditor::textColourId, theme.textPrimary);
        setColour (juce::TextEditor::backgroundColourId, juce::Colour::fromRGB (18, 18, 20));
        setColour (juce::ComboBox::backgroundColourId, juce::Colour::fromRGB (22, 22, 24));
        setColour (juce::ComboBox::textColourId, theme.textPrimary);
        setColour (juce::TextButton::buttonColourId, juce::Colour::fromRGB (45, 45, 48));
        setColour (juce::TextButton::textColourOffId, theme.textPrimary);
    }

    void drawRotarySlider (juce::Graphics& g,
                           int x, int y, int width, int height,
                           float sliderPosProportional,
                           float rotaryStartAngle,
                           float rotaryEndAngle,
                           juce::Slider& slider) override
    {
        juce::ignoreUnused (slider);
        auto bounds = juce::Rectangle<float> ((float) x, (float) y, (float) width, (float) height).reduced (2.0f);
        const auto radius = juce::jmin (bounds.getWidth(), bounds.getHeight()) * 0.5f;
        auto centre = bounds.getCentre();

        // Shadow
        g.setColour (juce::Colour::fromRGBA (0, 0, 0, 120));
        g.fillEllipse (bounds.translated (1.2f, 1.6f));

        // Metal body
        juce::ColourGradient cg (juce::Colour::fromRGB (210, 210, 214), centre.x - radius, centre.y - radius,
                                 juce::Colour::fromRGB (70, 70, 74), centre.x + radius, centre.y + radius, false);
        g.setGradientFill (cg);
        g.fillEllipse (bounds);

        // Rim
        g.setColour (juce::Colour::fromRGBA (0, 0, 0, 120));
        g.drawEllipse (bounds, 1.2f);
        g.setColour (juce::Colour::fromRGBA (255, 255, 255, 75));
        g.drawEllipse (bounds.reduced (1.4f), 1.0f);

        // Tick marks (static)
        g.setColour (juce::Colour::fromRGBA (0, 0, 0, 90));
        const int ticks = 21;
        for (int i = 0; i < ticks; ++i)
        {
            const float p = (float) i / (float) (ticks - 1);
            const float a = rotaryStartAngle + p * (rotaryEndAngle - rotaryStartAngle);
            const float r0 = radius * 0.78f;
            const float r1 = radius * 0.92f;
            g.drawLine (centre.x + std::cos (a) * r0,
                        centre.y + std::sin (a) * r0,
                        centre.x + std::cos (a) * r1,
                        centre.y + std::sin (a) * r1,
                        (i % 5 == 0) ? 1.1f : 0.7f);
        }

        // Pointer
        const float angle = rotaryStartAngle + sliderPosProportional * (rotaryEndAngle - rotaryStartAngle);
        auto p = juce::Point<float> (centre.x + std::cos (angle) * radius * 0.62f,
                                     centre.y + std::sin (angle) * radius * 0.62f);
        g.setColour (theme.accentAmber);
        g.drawLine (centre.x, centre.y, p.x, p.y, 2.0f);

        // Cap
        g.setColour (juce::Colour::fromRGBA (20, 20, 22, 180));
        g.fillEllipse (bounds.reduced (radius * 0.55f));
    }

    void drawLinearSlider (juce::Graphics& g, int x, int y, int width, int height,
                           float sliderPos, float minSliderPos, float maxSliderPos,
                           const juce::Slider::SliderStyle style, juce::Slider& slider) override
    {
        juce::ignoreUnused (minSliderPos, maxSliderPos, slider);
        auto r = juce::Rectangle<float> ((float) x, (float) y, (float) width, (float) height).reduced (2.0f);

        const bool isHorizontal = (style == juce::Slider::LinearHorizontal);
        if (isHorizontal)
        {
            auto track = r.withHeight (6.0f).withCentre (r.getCentre());
            g.setColour (juce::Colour::fromRGBA (0, 0, 0, 120));
            g.fillRoundedRectangle (track.translated (1.0f, 1.2f), 3.0f);
            g.setColour (juce::Colour::fromRGB (50, 50, 54));
            g.fillRoundedRectangle (track, 3.0f);

            auto filled = track.withRight (sliderPos);
            g.setColour (theme.accentAmber.withAlpha (0.75f));
            g.fillRoundedRectangle (filled, 3.0f);

            // Thumb "cap"
            auto thumb = juce::Rectangle<float> (sliderPos - 6.0f, track.getCentreY() - 10.0f, 12.0f, 20.0f);
            g.setColour (juce::Colour::fromRGBA (0, 0, 0, 110));
            g.fillRoundedRectangle (thumb.translated (1.0f, 1.2f), 4.0f);
            juce::ColourGradient cg (juce::Colour::fromRGB (210, 210, 214), thumb.getX(), thumb.getY(),
                                     juce::Colour::fromRGB (85, 85, 90), thumb.getRight(), thumb.getBottom(), false);
            g.setGradientFill (cg);
            g.fillRoundedRectangle (thumb, 4.0f);
            g.setColour (juce::Colour::fromRGBA (0, 0, 0, 120));
            g.drawRoundedRectangle (thumb, 4.0f, 1.0f);
            return;
        }

        // Fallback to base for uncommon styles
        juce::LookAndFeel_V4::drawLinearSlider (g, x, y, width, height, sliderPos, minSliderPos, maxSliderPos, style, slider);
    }

private:
    Theme theme;
};
}

