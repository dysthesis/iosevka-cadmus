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

The TTF files are placed under `result/share/fonts/truetype`. Run both package
checks with:

```sh
nix flake check
```

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

[tweak]
ligatures=yes
```

For the patched variant, set
`font=IosevkaCadmus Nerd Font Mono:style=Medium:size=10.5` instead.
