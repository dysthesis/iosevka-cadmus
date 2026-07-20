"""Check the two Nerd Font icon-size contracts.

Usage: check-nerd-font.py WIDE_FONTDIR MONO_FONTDIR
"""

import sys
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont


CELL = 600
ICONS = {
    "folder": 0xF07B,
    "terminal": 0xF120,
}


def glyph_width(font, glyph_name):
    glyphs = font.getGlyphSet()
    pen = BoundsPen(glyphs)
    glyphs[glyph_name].draw(pen)
    if pen.bounds is None:
        return 0
    return pen.bounds[2] - pen.bounds[0]


def check_font(path, family, single_width):
    errors = []
    font = TTFont(path)
    families = {
        record.toUnicode() for record in font["name"].names if record.nameID in (1, 16)
    }
    if family not in families:
        errors.append(f"{path.name}: missing family {family!r}")

    cmap = font.getBestCmap()
    metrics = font["hmtx"].metrics
    pua = {
        codepoint: glyph
        for codepoint, glyph in cmap.items()
        if 0xE000 <= codepoint <= 0xF8FF
        or 0xF0000 <= codepoint <= 0xFFFFD
        or 0x100000 <= codepoint <= 0x10FFFD
    }
    if len(pua) < 10_000:
        errors.append(f"{path.name}: only {len(pua)} private-use glyphs")
    bad_advances = {metrics[glyph][0] for glyph in pua.values()} - {0, CELL}
    if bad_advances:
        errors.append(
            f"{path.name}: unexpected private-use advances {sorted(bad_advances)}"
        )

    for label, codepoint in ICONS.items():
        glyph = cmap.get(codepoint)
        if glyph is None:
            errors.append(f"{path.name}: missing {label} U+{codepoint:04X}")
            continue
        width = glyph_width(font, glyph)
        if single_width and width > CELL:
            errors.append(f"{path.name}: {label} width {width:g} exceeds one cell")
        if not single_width and width <= CELL:
            errors.append(
                f"{path.name}: {label} width {width:g} lost original icon size"
            )

    return errors


def main():
    wide = Path(sys.argv[1])
    mono = Path(sys.argv[2])
    errors = check_font(
        wide / "IosevkaCadmusNerdFont-Medium.ttf",
        "IosevkaCadmus Nerd Font",
        single_width=False,
    )
    errors += check_font(
        mono / "IosevkaCadmusNerdFontMono-Medium.ttf",
        "IosevkaCadmus Nerd Font Mono",
        single_width=True,
    )
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print("ok: original-size and single-width Nerd Font contracts hold")


if __name__ == "__main__":
    main()
