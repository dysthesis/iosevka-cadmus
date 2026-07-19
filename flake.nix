{
  description = "Iosevka Cadmus, a low-DPI terminal font";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, ... }:
        let
          iosevkaCadmus = pkgs.iosevka.override {
            set = "Cadmus";
            privateBuildPlan = {
              family = "Iosevka Cadmus";
              spacing = "term";
              serifs = "sans";
              noCvSs = true;
              exportGlyphNames = false;

              variants.inherits = "ss03";

              ligations.enables = [
                "eqeq"
                "exeq"
                "lteq"
                "gteq"
                "arrow-r-hyphen"
                "arrow-r-equal"
              ];

              weights = {
                Medium = {
                  shape = 500;
                  menu = 500;
                  css = 500;
                };
                Bold = {
                  shape = 700;
                  menu = 700;
                  css = 700;
                };
              };

              slopes = {
                Upright = {
                  angle = 0;
                  shape = "upright";
                  menu = "upright";
                  css = "normal";
                };
                Italic = {
                  angle = 9.4;
                  shape = "italic";
                  menu = "italic";
                  css = "italic";
                };
              };

              widths.Normal = {
                shape = 600;
                menu = 5;
                css = "normal";
              };
            };
          };
        in
        {
          checks.default = iosevkaCadmus;

          packages = {
            default = iosevkaCadmus;
            iosevka-cadmus = iosevkaCadmus;
          };
        };
    };
}
