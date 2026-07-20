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
          buildPlan = {
            family = "Iosevka Cadmus";
            spacing = "term";
            serifs = "sans";
            noCvSs = true;
            exportGlyphNames = false;

            variants.inherits = "ss03";
            variants.design.capital-q = "crossing";
            variants.upright.l = "serifed-flat-tailed";

            ligations.enables = [
              "eqeq"
              "exeq"
              "lteq"
              "gteq"
              # llggeq: without it, lteq/gteq half-ligate the suffix of
              # <<= and >>= into "<≤" / ">≥"; whole-trigram ligation is
              # coherent and leaves << >> <<< and conflict markers alone.
              "llggeq"
              "arrow-r-hyphen"
              "arrow-r-equal"
              "kern-dotty"
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
          mkIosevka =
            { set, plan }:
            pkgs.iosevka.override {
              inherit set;
              privateBuildPlan = plan;
            };
          iosevkaCadmus = mkIosevka {
            set = "Cadmus";
            plan = buildPlan;
          };
          iosevkaCadmusAudition = mkIosevka {
            set = "CadmusAudition";
            plan = buildPlan // {
              family = "Iosevka Cadmus Audition";
              noCvSs = false;
              weights = {
                inherit (buildPlan.weights) Medium;
              };
              slopes = {
                inherit (buildPlan.slopes) Upright;
              };
            };
          };
          mkNerdFont =
            {
              name,
              singleWidth ? false,
            }:
            pkgs.runCommand "${name}-${iosevkaCadmus.version}"
              {
                nativeBuildInputs = [ pkgs.nerd-font-patcher ];
              }
              ''
                fontDir="$out/share/fonts/truetype"
                mkdir -p "$fontDir"

                for font in ${iosevkaCadmus}/share/fonts/truetype/*.ttf; do
                  nerd-font-patcher \
                    --complete \
                    ${pkgs.lib.optionalString singleWidth "--single-width-glyphs"} \
                    --quiet \
                    --no-progressbars \
                    --outputdir "$fontDir" \
                    "$font"
                done

                patchedFonts=("$fontDir"/*.ttf)
                test "''${#patchedFonts[@]}" -eq 4
              '';
          iosevkaCadmusNerdFont = mkNerdFont {
            name = "IosevkaCadmusNerdFont";
          };
          iosevkaCadmusNerdFontMono = mkNerdFont {
            name = "IosevkaCadmusNerdFontMono";
            singleWidth = true;
          };
          tooling = import ./tools {
            inherit
              pkgs
              iosevkaCadmus
              iosevkaCadmusAudition
              iosevkaCadmusNerdFont
              iosevkaCadmusNerdFontMono
              ;
          };
        in
        {
          apps = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux tooling.apps;

          checks = {
            default = iosevkaCadmus;
            nerd-font = iosevkaCadmusNerdFont;
            nerd-font-mono = iosevkaCadmusNerdFontMono;
            font-semantics = tooling.fontCheck;
            nerd-font-semantics = tooling.nerdFontCheck;
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            tooling = tooling.check;
          };

          packages = {
            default = iosevkaCadmus;
            audition = iosevkaCadmusAudition;
            iosevka-cadmus = iosevkaCadmus;
            iosevka-cadmus-nerd-font = iosevkaCadmusNerdFont;
            iosevka-cadmus-nerd-font-mono = iosevkaCadmusNerdFontMono;
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            specimen = tooling.webSpecimen;
          };
        };
    };
}
