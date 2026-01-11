#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "UheTheme.h"

namespace uhe
{
class LCDDisplay final : public juce::Component
{
public:
    explicit LCDDisplay (Theme t = {}) : theme (t)
    {
        setOpaque (true);
    }

    void setText (juce::String t)
    {
        if (text == t)
            return;
        text = std::move (t);
        repaint();
    }

    void setRightText (juce::String t)
    {
        if (rightText == t)
            return;
        rightText = std::move (t);
        repaint();
    }

    void paint (juce::Graphics& g) override
    {
        auto r = getLocalBounds().toFloat();

        // Outer bezel
        g.setColour (juce::Colour::fromRGB (35, 35, 36));
        g.fillRoundedRectangle (r, 8.0f);

        auto inner = r.reduced (5.0f);

        juce::ColourGradient grad (theme.lcdInner, inner.getX(), inner.getY(),
                                   theme.lcdOuter, inner.getX(), inner.getBottom(), false);
        g.setGradientFill (grad);
        g.fillRoundedRectangle (inner, 5.5f);

        // subtle scanline/grain
        if (! scan.isValid() || scan.getWidth() != (int) inner.getWidth() || scan.getHeight() != (int) inner.getHeight())
        {
            scan = makeNoiseImage ((int) inner.getWidth(), (int) inner.getHeight(), 0x123456u, 12);
        }
        g.drawImageWithin (scan, (int) inner.getX(), (int) inner.getY(), (int) inner.getWidth(), (int) inner.getHeight(),
                           juce::RectanglePlacement::stretchToFit);

        // Inner border + glow
        g.setColour (theme.lcdGlow);
        g.drawRoundedRectangle (inner.reduced (0.8f), 5.2f, 1.2f);
        g.setColour (theme.lcdShadow);
        g.drawRoundedRectangle (inner.reduced (2.0f), 4.6f, 1.0f);

        // Text
        auto tr = inner.reduced (10.0f, 6.0f);
        g.setFont (theme.fontMono());
        g.setColour (theme.lcdText);
        g.drawText (text, tr, juce::Justification::centredLeft, true);

        if (rightText.isNotEmpty())
        {
            g.setColour (theme.lcdText.withAlpha (0.85f));
            g.drawText (rightText, tr, juce::Justification::centredRight, true);
        }
    }

private:
    Theme theme;
    juce::String text, rightText;
    juce::Image scan;
};
}

