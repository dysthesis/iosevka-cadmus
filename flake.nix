{
  description = "Iosevka Cadmus, a low-DPI terminal font";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem = {
        pkgs,
        lib,
        ...
      }: let
        buildPlan = {
          family = "Iosevka Cadmus";
          spacing = "term";
          serifs = "sans";
          noCvSs = true;
          exportGlyphNames = false;

          variants = {
            inherits = "ss03";
            design.capital-q = "crossing";
            upright.l = "serifed-flat-tailed";
          };

          ligations = {
            inherits = "dlig";
            enables = [
              "eqeq"
              "exeq"
              "lteq"
              "gteq"
              # without llgg, lteq/gteq half-ligate the suffix of <<= and >>=
              # into "<≤" / ">≥"; whole-trigram ligation is coherent and leaves
              # conflict markers alone (dlig ligates << >> <<< since d263016).
              "llggeq"
              "arrow-r-hyphen"
              "arrow-r-equal"
              "kern-dotty"
            ];
          };

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
        mkIosevka = {
          set,
          plan,
        }:
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
          plan =
            buildPlan
            // {
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
        mkNerdFont = {
          name,
          singleWidth ? false,
        }:
          pkgs.runCommand "${name}-${iosevkaCadmus.version}"
          {
            nativeBuildInputs = [pkgs.nerd-font-patcher];
          }
          # sh
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
      in {
        apps = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux tooling.apps;

        checks =
          {
            default = iosevkaCadmus;
            nerd-font = iosevkaCadmusNerdFont;
            nerd-font-mono = iosevkaCadmusNerdFontMono;
            font-semantics = tooling.fontCheck;
            nerd-font-semantics = tooling.nerdFontCheck;
          }
          // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            tooling = tooling.check;
          };

        devShells.default = pkgs.mkShellNoCC {
          name = "iosevka-cadmus-dev";
          packages = let
            python = pkgs.python313;
            pyPkgs = python.pkgs;
            headroom = pyPkgs.buildPythonApplication rec {
              pname = "headroom-ai";
              version = "0.32.0";
              pyproject = true;

              src = pkgs.fetchFromGitHub {
                owner = "headroomlabs-ai";
                repo = "headroom";
                tag = "v${version}";
                hash = "sha256-7+ul+rco4HvI3ar6Y9JvfBiFem8IeBwnBEGUcj/d9xU=";
              };

              cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
                inherit pname version src;
                hash = "sha256-bSBtv1CUP2NjZujQSsAgPpeFYd28O5Ea1FXKu6ZRcvs=";
              };

              nativeBuildInputs = with pkgs; [
                makeWrapper
                pkg-config
                rustPlatform.cargoSetupHook
                rustPlatform.maturinBuildHook
              ];

              buildInputs = with pkgs; [
                onnxruntime
                openssl
              ];

              postPatch = ''
                substituteInPlace headroom/proxy/models.py \
                  --replace-fail 'from dataclasses import InitVar, dataclass, field' $'from dataclasses import InitVar, dataclass, field\nimport os' \
                  --replace-fail 'from headroom.providers.registry import ProviderApiOverrides' $'from headroom.providers.registry import ProviderApiOverrides\n\n\ndef _env_int_or_none(name: str) -> int | None:\n    raw = os.environ.get(name, "").strip()\n    if not raw:\n        return None\n    try:\n        return int(raw)\n    except ValueError:\n        return None' \
                  --replace-fail 'compression_max_workers: int | None = None' 'compression_max_workers: int | None = field(default_factory=lambda: _env_int_or_none("HEADROOM_COMPRESSION_MAX_WORKERS"))'
              '';

              env = {
                ORT_STRATEGY = "system";
                ORT_LIB_LOCATION = "${lib.getLib pkgs.onnxruntime}/lib";
                ORT_PREFER_DYNAMIC_LINK = "true";
                ORT_DYLIB_PATH = "${lib.getLib pkgs.onnxruntime}/lib/libonnxruntime.so";
              };

              dependencies = with pyPkgs; [
                tomlkit
                click
                fastapi
                h2
                httpx
                litellm
                magika
                mcp
                openai
                pydantic
                rich
                sqlite-vec
                tiktoken
                transformers
                uvicorn
                watchdog
                websockets
                zstandard
                opentelemetry-api
                onnxruntime
              ];

              pythonRelaxDeps = [
                "litellm"
              ];

              pythonRemoveDeps = [
                "ast-grep-cli"
              ];

              makeWrapperArgs = [
                "--prefix PATH : ${lib.makeBinPath [pkgs.ast-grep]}"
                "--set ORT_DYLIB_PATH ${lib.getLib pkgs.onnxruntime}/lib/libonnxruntime.so"
                "--prefix LD_LIBRARY_PATH : ${lib.getLib pkgs.onnxruntime}/lib"
              ];

              pythonImportsCheck = [
                "headroom"
              ];

              meta = {
                description = "Context optimization layer for LLM applications and coding agents";
                homepage = "https://github.com/chopratejas/headroom";
                changelog = "https://github.com/chopratejas/headroom/releases/tag/v${version}";
                license = lib.licenses.asl20;
                mainProgram = "headroom";
                platforms = lib.platforms.linux;
              };
            };
          in
            with pkgs; [
              # Nix
              nil
              statix
              deadnix
              alejandra

              # Python
              basedpyright
              pyright
              black

              # JS
              nodejs

              # Misc
              headroom
            ];
        };

        packages =
          {
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
