# Iosevka Cadmus

A terminal-focused Iosevka build for low-DPI displays. It uses 600-unit cells,
term spacing, the Consolas-style `ss03` variants, and a deliberately small
ligation set. The package contains Medium and Bold in upright and italic forms.

## Build

```sh
nix build
```

The TTF files are placed under `result/share/fonts/truetype`. Run the complete
flake check with:

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

## foot

The ligature setting requires the corresponding patched foot and fcft builds.

```ini
[main]
font=Iosevka Cadmus:style=Medium:size=10.5

[tweak]
ligatures=yes
```
