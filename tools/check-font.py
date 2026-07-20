"""Semantic checks for the Iosevka Cadmus rendering contract.

Usage: check-font.py FONTDIR

Fails when an Iosevka or nixpkgs update silently drops a face, strips the
TrueType hinting tables, changes the ligation behaviour, or breaks the
600-unit monospace advance.
"""

import sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

EXPECTED_FACES = {
    "IosevkaCadmus-Medium.ttf",
    "IosevkaCadmus-MediumItalic.ttf",
    "IosevkaCadmus-Bold.ttf",
    "IosevkaCadmus-BoldItalic.ttf",
}
HINTING_TABLES = ("cvt ", "fpgm", "prep")
CELL = 600

# Every sequence the enabled ligation groups must transform.
MUST_LIGATE = [
    "==", "===", "!=", "!==", "!===",          # eqeq, exeq
    "<=", ">=",                                # lteq, gteq
    "<<=", ">>=",                              # llggeq
    "->", "->>", "-->", "--->",                # arrow-r-hyphen
    "=>", "=>>", "==>",                        # arrow-r-equal
    "::", ":::", "...",                        # kern-dotty
]

# Sequences that must shape identically with and without calt.
# `=!=` is excluded: its `!=` suffix ligates.
MUST_NOT_LIGATE = [
    "<<", ">>", "<<<", ">>>", "2>&1",
    "<-", "://", "=:=",
    "<<<<<<<", ">>>>>>>", "%%%%%%%",           # jj/git conflict markers
]


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
    faces = {p.name for p in fontdir.glob("*.ttf")}
    failed = False
    if faces != EXPECTED_FACES:
        print(f"face set mismatch:\n  extra: {faces - EXPECTED_FACES}\n  missing: {EXPECTED_FACES - faces}")
        failed = True
    for name in sorted(faces & EXPECTED_FACES):
        for err in check_face(fontdir / name):
            print(f"{name}: {err}")
            failed = True
    if failed:
        sys.exit(1)
    print(f"ok: {len(faces)} faces, hinting tables present, ligation contract holds")


if __name__ == "__main__":
    main()
