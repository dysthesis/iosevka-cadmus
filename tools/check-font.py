"""Semantic checks for the Iosevka Cadmus rendering contract.

Usage: check-font.py FONTDIR [FILENAME_PREFIX]

Fails when an Iosevka or nixpkgs update silently drops a face, strips the
TrueType hinting tables, changes the ligation behaviour, breaks the
600-unit monospace advance, or degrades the box-drawing/block coverage
terminals rely on for seamless rules and blocks.
"""

import sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont

FACE_SUFFIXES = {"Medium", "MediumItalic", "Bold", "BoldItalic"}
HINTING_TABLES = ("cvt ", "fpgm", "prep")
CELL = 600
# Vertical cell edges: U+2588 FULL BLOCK must fill exactly this box.
CELL_BOTTOM, CELL_TOP = -285, 965
# Box drawing U+2500-257F plus block elements U+2580-259F.
BOX_BLOCK = range(0x2500, 0x25A0)

# Every sequence the enabled ligation groups must transform.
MUST_LIGATE = [
    "==", "===", "!=", "!==", "!===",          # eqeq, exeq
    "<=", ">=",                                # lteq, gteq
    "<<=", ">>=",                              # llggeq
    "->", "->>", "-->", "--->",                # arrow-r-hyphen
    "=>", "=>>", "==>",                        # arrow-r-equal
    "::", ":::", "...",                        # kern-dotty
    "<<", ">>", "<<<", ">>>",                  # dlig inheritance (d263016)
    "<-", "://", "=:=",
]

# Sequences that must shape identically with and without calt.
# `=!=` is excluded: its `!=` suffix ligates.
MUST_NOT_LIGATE = [
    "2>&1",
    "<<<<<<<", ">>>>>>>", "%%%%%%%",           # jj/git conflict markers
]


def glyph_bounds(tt, glyph_name):
    glyphs = tt.getGlyphSet()
    pen = BoundsPen(glyphs)
    glyphs[glyph_name].draw(pen)
    return pen.bounds


def check_box_drawing(tt, cmap, metrics):
    errors = []
    missing = [f"U+{cp:04X}" for cp in BOX_BLOCK if cp not in cmap]
    if missing:
        return [f"missing box/block glyphs {missing}"]
    bad = {
        f"U+{cp:04X}": metrics[cmap[cp]][0]
        for cp in BOX_BLOCK
        if metrics[cmap[cp]][0] != CELL
    }
    if bad:
        errors.append(f"non-{CELL} box/block advances {bad}")

    full = glyph_bounds(tt, cmap[0x2588])
    if full != (0, CELL_BOTTOM, CELL, CELL_TOP):
        errors.append(f"U+2588 bbox {full} != (0, {CELL_BOTTOM}, {CELL}, {CELL_TOP})")
    hbar = glyph_bounds(tt, cmap[0x2500])
    if (hbar[0], hbar[2]) != (0, CELL):
        errors.append(f"U+2500 x-span {hbar[0]}..{hbar[2]} != 0..{CELL}")
    vbar = glyph_bounds(tt, cmap[0x2502])
    if (vbar[1], vbar[3]) != (CELL_BOTTOM, CELL_TOP):
        errors.append(f"U+2502 y-span {vbar[1]}..{vbar[3]} != {CELL_BOTTOM}..{CELL_TOP}")
    return errors


def shape(font, text, calt):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {"calt": calt})
    return [(i.codepoint, p.x_advance) for i, p in zip(buf.glyph_infos, buf.glyph_positions)]


def check_face(path):
    errors = []
    tt = TTFont(path)
    upm = tt["head"].unitsPerEm
    missing = [t for t in HINTING_TABLES if t not in tt]
    if missing:
        errors.append(f"missing hinting tables: {missing}")
    if upm != 1000:  # CELL = 600 assumes Iosevka's 1000-unit em
        errors.append(f"unexpected unitsPerEm {upm}")

    cmap = tt.getBestCmap()
    metrics = tt["hmtx"].metrics
    bad_ascii = {
        chr(codepoint): metrics[cmap[codepoint]][0]
        for codepoint in range(0x20, 0x7F)
        if metrics[cmap[codepoint]][0] != CELL
    }
    if bad_ascii:
        errors.append(f"non-{CELL} ASCII advances {bad_ascii}")
    errors += check_box_drawing(tt, cmap, metrics)

    font = hb.Font(hb.Face(hb.Blob.from_file_path(str(path))))
    for text in MUST_LIGATE + MUST_NOT_LIGATE:
        shaped = shape(font, text, calt=True)
        bad = [a for _, a in shaped if a != CELL]
        if bad:
            errors.append(f"{text!r}: non-600 advances {bad}")
        if sum(a for _, a in shaped) != CELL * len(text):
            errors.append(f"{text!r}: total advance != {CELL} * {len(text)}")
    for text in MUST_LIGATE:
        if shape(font, text, calt=True) == shape(font, text, calt=False):
            errors.append(f"{text!r}: calt substitution missing")
    for text in MUST_NOT_LIGATE:
        if shape(font, text, calt=True) != shape(font, text, calt=False):
            errors.append(f"{text!r}: unexpectedly transformed by calt")
    return errors


def main():
    fontdir = Path(sys.argv[1])
    prefix = sys.argv[2] if len(sys.argv) > 2 else "IosevkaCadmus"
    expected_faces = {f"{prefix}-{suffix}.ttf" for suffix in FACE_SUFFIXES}
    faces = {p.name for p in fontdir.glob("*.ttf")}
    failed = False
    if faces != expected_faces:
        print(f"face set mismatch:\n  extra: {faces - expected_faces}\n  missing: {expected_faces - faces}")
        failed = True
    for name in sorted(faces & expected_faces):
        for err in check_face(fontdir / name):
            print(f"{name}: {err}")
            failed = True
    if failed:
        sys.exit(1)
    print(f"ok: {len(faces)} faces, hinting tables present, ligation contract holds")


if __name__ == "__main__":
    main()
