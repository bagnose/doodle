// vi:noai:sw=4

#include "terminal/x_font_set.hpp"

X_FontSet::X_FontSet(Display           * display,
                     const std::string & fontName) :
    mDisplay(display),
    mNormal(nullptr),
    mItalic(nullptr),
    mItalicBold(nullptr),
    mBold(nullptr),
    mWidth(0),
    mHeight(0)
{
    FcPattern * pattern;

    pattern = FcNameParse(reinterpret_cast<const FcChar8 *>(fontName.c_str()));
    ENFORCE(pattern,);

    FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);

    // Normal
    mNormal = load(pattern);

    // Italic
    FcPatternDel(pattern, FC_SLANT);
    FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ITALIC);
    mItalic = load(pattern);

    // Italic bold
    FcPatternDel(pattern, FC_WEIGHT);
    FcPatternAddInteger(pattern, FC_WEIGHT, FC_WEIGHT_BOLD);
    mItalicBold = load(pattern);

    // Bold
    FcPatternDel(pattern, FC_SLANT);
    FcPatternAddInteger(pattern, FC_SLANT, FC_SLANT_ROMAN);
    mBold = load(pattern);

    FcPatternDestroy(pattern);
}

X_FontSet::~X_FontSet() {
    unload(mBold);
    unload(mItalicBold);
    unload(mItalic);
    unload(mNormal);
}

XftFont * X_FontSet::load(FcPattern * pattern) {
    FcResult result;
    FcPattern * match = FcFontMatch(nullptr, pattern, &result);
    ENFORCE(match,);

    XftFont * font = XftFontOpenPattern(mDisplay, match);
    ENFORCE(font,);

    FcPatternDestroy(match);

    mWidth  = std::max(mWidth, static_cast<uint16_t>(font->max_advance_width));
    mHeight = std::max(mWidth, static_cast<uint16_t>(font->height));

    return font;
}

void X_FontSet::unload(XftFont * font) {
    XftFontClose(mDisplay, font);
}
