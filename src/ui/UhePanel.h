#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "UheTheme.h"

namespace uhe
{
class Panel final : public juce::Component
{
public:
    explicit Panel (Theme t = {}) : theme (t)
    {
        setOpaque (true);
    }

    void setTitle (juce::String t) { title = std::move (t); repaint(); }
    void setShowScrews (bool b) { showScrews = b; repaint(); }

    void paint (juce::Graphics& g) override
    {
        auto r = getLocalBounds().toFloat();

        // Base brushed metal gradient
        juce::ColourGradient grad (theme.panelTop, r.getX(), r.getY(),
                                   theme.panelBottom, r.getX(), r.getBottom(), false);
        g.setGradientFill (grad);
        g.fillRoundedRectangle (r, 10.0f);

        // Inner bevel
        g.setColour (theme.panelHi);
        g.drawRoundedRectangle (r.reduced (0.8f), 9.5f, 1.0f);
        g.setColour (theme.panelLo);
        g.drawRoundedRectangle (r.reduced (1.8f), 8.8f, 1.2f);

        // Grain overlay
        if (! grain.isValid() || grain.getWidth() != (int) r.getWidth() || grain.getHeight() != (int) r.getHeight())
            grain = makeNoiseImage ((int) r.getWidth(), (int) r.getHeight(), 0xBADC0DEu, 18);

        g.setOpacity (1.0f);
        g.drawImageAt (grain, (int) r.getX(), (int) r.getY());

        // Border
        g.setColour (theme.panelEdge.withAlpha (0.8f));
        g.drawRoundedRectangle (r, 10.0f, 1.2f);

        // Title
        if (title.isNotEmpty())
        {
            auto tr = getLocalBounds().reduced (10).removeFromTop (18);
            g.setColour (theme.textSecondary);
            g.setFont (theme.fontLabel().withStyle (juce::Font::bold));
            g.drawText (title.toUpperCase(), tr, juce::Justification::centredLeft);
        }

        if (showScrews)
            drawScrews (g);
    }

private:
    void drawScrews (juce::Graphics& g)
    {
        auto r = getLocalBounds().toFloat();
        const float s = 10.0f;
        const float pad = 10.0f;

        const juce::Point<float> pts[] = {
            { r.getX() + pad, r.getY() + pad },
            { r.getRight() - pad, r.getY() + pad },
            { r.getX() + pad, r.getBottom() - pad },
            { r.getRight() - pad, r.getBottom() - pad }
        };

        for (auto p : pts)
        {
            auto c = juce::Rectangle<float> (p.x - s * 0.5f, p.y - s * 0.5f, s, s);
            g.setColour (juce::Colour::fromRGBA (0, 0, 0, 110));
            g.fillEllipse (c.translated (0.8f, 0.9f));

            juce::ColourGradient cg (juce::Colour::fromRGB (210, 210, 215), c.getX(), c.getY(),
                                     juce::Colour::fromRGB (90, 90, 95), c.getRight(), c.getBottom(), false);
            g.setGradientFill (cg);
            g.fillEllipse (c);

            g.setColour (juce::Colour::fromRGBA (255, 255, 255, 70));
            g.drawEllipse (c.reduced (0.7f), 1.0f);

            // screw slot
            g.setColour (juce::Colour::fromRGBA (0, 0, 0, 140));
            g.drawLine (c.getCentreX() - 3.5f, c.getCentreY(), c.getCentreX() + 3.5f, c.getCentreY(), 1.3f);
        }
    }

    Theme theme;
    juce::String title;
    bool showScrews = true;
    juce::Image grain;
};
}

