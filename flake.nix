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
          iosevkaCadmusNerdFont =
            pkgs.runCommand "IosevkaCadmusNerdFont-${iosevkaCadmus.version}"
              {
                nativeBuildInputs = [ pkgs.nerd-font-patcher ];
              }
              ''
                fontDir="$out/share/fonts/truetype"
                mkdir -p "$fontDir"

                for font in ${iosevkaCadmus}/share/fonts/truetype/*.ttf; do
                  nerd-font-patcher \
                    --complete \
                    --single-width-glyphs \
                    --quiet \
                    --no-progressbars \
                    --outputdir "$fontDir" \
                    "$font"
                done

                patchedFonts=("$fontDir"/*.ttf)
                test "''${#patchedFonts[@]}" -eq 4
              '';
        in
        {
          checks = {
            default = iosevkaCadmus;
            nerd-font = iosevkaCadmusNerdFont;
          };

          packages = {
            default = iosevkaCadmus;
            iosevka-cadmus = iosevkaCadmus;
            iosevka-cadmus-nerd-font = iosevkaCadmusNerdFont;
          };
        };
    };
}
