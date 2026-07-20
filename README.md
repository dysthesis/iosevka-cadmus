# Iosevka Cadmus

A terminal-focused Iosevka build for low-DPI displays. It uses 600-unit cells,
term spacing, the Consolas-style `ss03` variants with a clearer crossing `Q`
and flat-tailed upright `l`, and a deliberately small ligation set. The package
contains Medium and Bold in upright and italic forms.

## Build

```sh
nix build
```

Build the Nerd Font variant with original-size icons with:

```sh
nix build .#iosevka-cadmus-nerd-font
```

This adds every Nerd Fonts glyph set without changing the widths of Iosevka's
existing glyphs. The icons retain their larger artwork and can overhang adjacent
cells, so this variant is best when icons are isolated or padded. Its family
name is `IosevkaCadmus Nerd Font`.

For Nerd Fonts' single-width icon scaling, which is safer beside terminal text,
build:

```sh
nix build .#iosevka-cadmus-nerd-font-mono
```

Its family name is `IosevkaCadmus Nerd Font Mono`. The unpatched font remains
the default package.

The TTF files are placed under `result/share/fonts/truetype`. Run all flake
checks with:

```sh
nix flake check
```

The `font-semantics` check (`tools/check-font.py`) asserts the rendering
contract: the exact four faces, the TrueType hinting tables, the `calt`
ligation behaviour including untouched jj/git conflict markers, and 600-unit
advances for every shaped component. `nerd-font-semantics` additionally checks both Nerd
Font families, their icon-size contracts, and preservation of ASCII metrics.

## NixOS

Given this flake as an input named `iosevka-cadmus`, install the package and
scope full hinting to this family:

```nix
{ inputs, pkgs, ... }:
{
  fonts.packages = [
    inputs.iosevka-cadmus.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  fonts.fontconfig.localConf = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="font">
        <test name="family" compare="eq">
          <string>Iosevka Cadmus</string>
        </test>
        <edit name="hintstyle" mode="assign">
          <const>hintfull</const>
        </edit>
      </match>
    </fontconfig>
  '';
}
```

To install an original-size patched variant instead, replace `.default` with
`.iosevka-cadmus-nerd-font` and use `IosevkaCadmus Nerd Font` as the family name
in the Fontconfig rule. For the single-width variant, use
`.iosevka-cadmus-nerd-font-mono` and `IosevkaCadmus Nerd Font Mono`.

## foot

The ligature setting requires the corresponding patched foot and fcft builds.

```ini
[main]
font=Iosevka Cadmus:size=10.5
dpi-aware=yes

[tweak]
ligatures=yes
```

With `dpi-aware=yes`, point sizes already track the monitor's physical DPI.
Use the same `size` across correctly reported displays; use `pixelsize` only
for exact raster auditions.

Do not pin `style=Medium` in the pattern: fontconfig then resolves foot's
derived bold and italic requests back to the Medium upright face. The family
alone matches Medium as the regular weight and lets bold/italic escalation
work.

For the original-size patched variant, set
`font=IosevkaCadmus Nerd Font:size=10.5` instead. For the single-width variant,
use `font=IosevkaCadmus Nerd Font Mono:size=10.5`.

## Inspection tooling

The Linux apps use an isolated Fontconfig configuration containing the current
flake output, so an older installed copy cannot contaminate a comparison.

| Command | Purpose |
| --- | --- |
| `nix run .#foot` | Open the full four-face specimen in patched foot |
| `nix run .#foot-audition` | Open the faster Medium Upright audition build |
| `nix run .#foot-screenshot` | Write a deterministic headless foot capture |
| `nix run .#foot-audition-screenshot` | Capture the audition build |
| `nix run .#chromium` | Open the browser proof sheet in Chromium |
| `nix run .#firefox` | Open the browser proof sheet in Firefox |
| `nix run .#chromium-screenshot` | Capture the proof sheet with headless Chromium |
| `nix run .#firefox-screenshot` | Capture the proof sheet with headless Firefox |

Screenshot commands write to `artifacts/` by default, which Git ignores. Pass
an explicit output path after `--` when required:

```sh
nix run .#foot-screenshot -- /tmp/cadmus-foot.png
nix run .#chromium-screenshot -- /tmp/cadmus-chromium.png
nix run .#firefox-screenshot -- /tmp/cadmus-firefox.png
```

The audition package builds only Medium Upright and retains Iosevka's `cv##`
and `ss##` features. Select comma-separated features without rebuilding:

```sh
IOSEVKA_FONT_FEATURES='cv01=3,cv06=1' nix run .#foot-audition
```

Set `IOSEVKA_FOOT` to override the detected foot executable. By default the
launchers use `foot` from `PATH` and verify that it accepts
`tweak.ligatures=yes`; the wrapper in
`~/Documents/Projects/laplace/user/wrapped/foot` satisfies this requirement.
`IOSEVKA_SIZE` changes the interactive point size, while
`IOSEVKA_PIXEL_SIZE` changes the deterministic foot capture size; the capture
scales the line height with it. Above roughly 22 px the full specimen no
longer fits the default 1400x1200 headless output and scrolls, so raise
`IOSEVKA_CAPTURE_MODE` (for example `3040x3160` for 40 px).

The headless foot capture runs the real patched foot/fcft path inside a private
wlroots compositor. Browser captures are suitable for comparing outlines,
features, engines, and regressions, but headless browser antialiasing is not a
substitute for judging low-DPI crispness interactively on the G244F.
