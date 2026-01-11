#pragma once

#include <juce_gui_basics/juce_gui_basics.h>

namespace uhe
{
struct Theme
{
    // Core palette (tuned for a "metal panel" look)
    juce::Colour bg0         = juce::Colour::fromRGB (20, 20, 22);
    juce::Colour bg1         = juce::Colour::fromRGB (34, 34, 38);
    juce::Colour panelTop    = juce::Colour::fromRGB (120, 120, 126);
    juce::Colour panelBottom = juce::Colour::fromRGB (74, 74, 80);
    juce::Colour panelEdge   = juce::Colour::fromRGB (30, 30, 32);
    juce::Colour panelHi     = juce::Colour::fromRGBA (255, 255, 255, 35);
    juce::Colour panelLo     = juce::Colour::fromRGBA (0, 0, 0, 110);

    juce::Colour textPrimary   = juce::Colour::fromRGB (240, 240, 242);
    juce::Colour textSecondary = juce::Colour::fromRGB (185, 185, 190);

    // LCD-ish
    juce::Colour lcdOuter   = juce::Colour::fromRGB (10, 18, 12);
    juce::Colour lcdInner   = juce::Colour::fromRGB (22, 40, 28);
    juce::Colour lcdGlow    = juce::Colour::fromRGBA (120, 255, 170, 55);
    juce::Colour lcdText    = juce::Colour::fromRGB (165, 255, 205);
    juce::Colour lcdShadow  = juce::Colour::fromRGBA (0, 0, 0, 160);

    juce::Colour accentAmber = juce::Colour::fromRGB (215, 170, 80);
    juce::Colour accentRed   = juce::Colour::fromRGB (220, 80, 80);
    juce::Colour accentGreen = juce::Colour::fromRGB (90, 200, 120);

    juce::Font fontTitle() const
    {
        return juce::Font (juce::FontOptions().withHeight (18.0f).withStyle ("Bold"));
    }

    juce::Font fontLabel() const
    {
        return juce::Font (juce::FontOptions().withHeight (12.5f));
    }

    juce::Font fontMono() const
    {
        auto opt = juce::FontOptions().withHeight (15.0f);
        return juce::Font (opt).withTypefaceStyle ("Regular");
    }
};

// Simple deterministic noise for panel grain (no external assets).
inline juce::Image makeNoiseImage (int w, int h, uint32_t seed = 0xC0FFEEu, uint8_t alpha = 16)
{
    juce::Image img (juce::Image::ARGB, w, h, true);
    juce::Random rng ((int) seed);

    for (int y = 0; y < h; ++y)
    {
        for (int x = 0; x < w; ++x)
        {
            const auto v = (uint8_t) rng.nextInt (256);
            img.setPixelAt (x, y, juce::Colour::fromRGBA (v, v, v, alpha));
        }
    }

    return img;
}
}

