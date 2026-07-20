# Iosevka Cadmus

A terminal-focused Iosevka build for low-DPI displays. It uses 600-unit cells,
term spacing, the Consolas-style `ss03` variants, and a deliberately small
ligation set. The package contains Medium and Bold in upright and italic forms.

## Build

```sh
nix build
```

Build the Nerd Font variant with:

```sh
nix build .#iosevka-cadmus-nerd-font
```

This adds every Nerd Fonts glyph set and constrains the added icons to one cell
without changing the widths of Iosevka's existing glyphs. Its family name is
`IosevkaCadmus Nerd Font Mono`; the unpatched font remains the default package.

The TTF files are placed under `result/share/fonts/truetype`. Run all flake
checks with:

```sh
nix flake check
```

The `font-semantics` check (`tools/check-font.py`) asserts the rendering
contract: the exact four faces, the TrueType hinting tables, the `calt`
ligation behaviour including untouched `<<`/`>>`, and 600-unit advances for
every shaped component.

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

To install the patched variant instead, replace `.default` with
`.iosevka-cadmus-nerd-font` and use `IosevkaCadmus Nerd Font Mono` as the family
name in the Fontconfig rule.

## foot

The ligature setting requires the corresponding patched foot and fcft builds.

```ini
[main]
font=Iosevka Cadmus:style=Medium:size=10.5
dpi-aware=yes

[tweak]
ligatures=yes
```

For the patched variant, set
`font=IosevkaCadmus Nerd Font Mono:style=Medium:size=10.5` instead.

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
`IOSEVKA_PIXEL_SIZE` changes the deterministic foot capture size.

The headless foot capture runs the real patched foot/fcft path inside a private
wlroots compositor. Browser captures are suitable for comparing outlines,
features, engines, and regressions, but headless browser antialiasing is not a
substitute for judging low-DPI crispness interactively on the G244F.
