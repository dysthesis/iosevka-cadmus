{
  pkgs,
  iosevkaCadmus,
  iosevkaCadmusAudition,
}:

let
  inherit (pkgs) lib;

  mkHintingConfig =
    family:
    pkgs.writeText "${lib.strings.sanitizeDerivationName family}-hinting.conf" ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <match target="font">
          <test name="family" compare="eq">
            <string>${family}</string>
          </test>
          <edit name="antialias" mode="assign"><bool>true</bool></edit>
          <edit name="hinting" mode="assign"><bool>true</bool></edit>
          <edit name="autohint" mode="assign"><bool>false</bool></edit>
          <edit name="hintstyle" mode="assign"><const>hintfull</const></edit>
        </match>
      </fontconfig>
    '';

  mkFontConfig =
    { font, family }:
    pkgs.makeFontsConf {
      fontDirectories = [ font ];
      impureFontDirectories = [ ];
      includes = [ (mkHintingConfig family) ];
    };

  mkFootConfig =
    family:
    pkgs.writeText "${lib.strings.sanitizeDerivationName family}-foot.ini" ''
      [main]
      # No style= pin: fontconfig would then ignore foot's derived
      # weight/slant and resolve every face to Medium upright.
      font=${family}:size=10.5
      dpi-aware=yes
      line-height=15.75
      pad=16x16
      bold-text-in-bright=no
      initial-window-size-chars=124x46

      [tweak]
      ligatures=yes

      [colors-dark]
      background=000000
      foreground=ffffff
      regular0=080808
      regular1=d70000
      regular2=789978
      regular3=ffaa88
      regular4=7788aa
      regular5=d7007d
      regular6=708090
      regular7=deeeed
      bright0=444444
      bright1=d70000
      bright2=789978
      bright3=ffaa88
      bright4=7788aa
      bright5=d7007d
      bright6=708090
      bright7=deeeed
    '';

  terminalRenderer = pkgs.writeShellApplication {
    name = "iosevka-terminal-specimen";
    text = ''
      printf '\033[2J\033[H'
      printf '\033[38;2;255;170;136mIOSEVKA CADMUS / TERMINAL PROOF\033[0m\n\n'

      line=
      while IFS= read -r line || [[ -n "$line" ]]; do
        printf '%s\n' "$line"
      done < ${../specimen/terminal.txt}

      printf '\n\033[22mMedium upright  0O 1lI| == != <= >= -> =>\033[0m\n'
      printf '\033[1mBold upright    0O 1lI| == != <= >= -> =>\033[0m\n'
      printf '\033[3mMedium italic   0O 1lI| == != <= >= -> =>\033[0m\n'
      printf '\033[1;3mBold italic     0O 1lI| == != <= >= -> =>\033[0m\n'
    '';
  };

  mkFootLauncher =
    {
      name,
      title,
      font,
      family,
    }:
    let
      config = mkFootConfig family;
      fontConfig = mkFontConfig { inherit font family; };
    in
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        foot_bin="''${IOSEVKA_FOOT:-}"
        if [[ -z "$foot_bin" ]]; then
          foot_bin="$(command -v foot || true)"
        fi
        if [[ -z "$foot_bin" || ! -x "$foot_bin" ]]; then
          printf 'error: patched foot not found; set IOSEVKA_FOOT or install the laplace wrapper\n' >&2
          exit 1
        fi

        export FONTCONFIG_FILE=${fontConfig}
        if ! "$foot_bin" --config=${config} --check-config; then
          printf 'error: %s does not accept tweak.ligatures=yes\n' "$foot_bin" >&2
          exit 1
        fi

        font_pattern="''${IOSEVKA_FONT_PATTERN:-${family}:size=''${IOSEVKA_SIZE:-10.5}}"
        if [[ -n "''${IOSEVKA_FONT_FEATURES:-}" ]]; then
          old_ifs="$IFS"
          IFS=',' read -r -a features <<< "$IOSEVKA_FONT_FEATURES"
          IFS="$old_ifs"
          for feature in "''${features[@]}"; do
            if [[ -n "$feature" ]]; then
              font_pattern+=":fontfeatures=$feature"
            fi
          done
        fi

        foot_args=(
          --config=${config}
          "--override=main.font=$font_pattern"
          --title=${lib.escapeShellArg title}
          --app-id=iosevka-cadmus-specimen
        )
        if [[ $# -eq 0 ]]; then
          exec "$foot_bin" "''${foot_args[@]}" --hold ${lib.getExe terminalRenderer}
        fi
        exec "$foot_bin" "''${foot_args[@]}" "$@"
      '';
    };

  foot = mkFootLauncher {
    name = "iosevka-foot";
    title = "Iosevka Cadmus terminal proof";
    font = iosevkaCadmus;
    family = "Iosevka Cadmus";
  };

  footAudition = mkFootLauncher {
    name = "iosevka-foot-audition";
    title = "Iosevka Cadmus audition";
    font = iosevkaCadmusAudition;
    family = "Iosevka Cadmus Audition";
  };

  mkFootScreenshot =
    {
      name,
      launcher,
      launcherName,
      family,
      defaultOutput,
    }:
    let
      capture = pkgs.writeShellScript "${name}-capture" ''
        set -euo pipefail
        ${lib.getExe pkgs.wlr-randr} --output HEADLESS-1 --custom-mode 1400x1200
        ${launcher}/bin/${launcherName} &
        foot_pid=$!

        cleanup() {
          if kill -0 "$foot_pid" 2>/dev/null; then
            kill "$foot_pid"
          fi
          wait "$foot_pid" 2>/dev/null || true
        }
        trap cleanup EXIT

        # simplification: Cage has no client-ready signal; fail if foot exits during the short wait.
        sleep "''${IOSEVKA_CAPTURE_DELAY:-2}"
        if ! kill -0 "$foot_pid" 2>/dev/null; then
          printf 'error: foot exited before the screenshot\n' >&2
          exit 1
        fi
        ${lib.getExe pkgs.grim} "$IOSEVKA_SCREENSHOT_OUTPUT"
      '';
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.coreutils ];
      text = ''
        if [[ $# -gt 1 ]]; then
          printf 'usage: ${name} [OUTPUT.png]\n' >&2
          exit 2
        fi

        output="''${1:-$PWD/artifacts/${defaultOutput}}"
        mkdir -p "$(dirname "$output")"
        output="$(realpath -m "$output")"
        runtime_dir="$(mktemp -d)"
        cleanup() { rm -rf "$runtime_dir"; }
        trap cleanup EXIT
        chmod 0700 "$runtime_dir"

        export XDG_RUNTIME_DIR="$runtime_dir"
        export WLR_BACKENDS=headless
        export WLR_HEADLESS_OUTPUTS=1
        export WLR_RENDERER=pixman
        export IOSEVKA_SCREENSHOT_OUTPUT="$output"
        export IOSEVKA_FONT_PATTERN="${family}:pixelsize=''${IOSEVKA_PIXEL_SIZE:-14}"

        ${lib.getExe pkgs.cage} -- ${capture}
        if [[ ! -s "$output" ]]; then
          printf 'error: screenshot was not written to %s\n' "$output" >&2
          exit 1
        fi
        printf 'wrote %s\n' "$output"
      '';
    };

  footScreenshot = mkFootScreenshot {
    name = "iosevka-foot-screenshot";
    launcher = foot;
    launcherName = "iosevka-foot";
    family = "Iosevka Cadmus";
    defaultOutput = "foot.png";
  };

  footAuditionScreenshot = mkFootScreenshot {
    name = "iosevka-foot-audition-screenshot";
    launcher = footAudition;
    launcherName = "iosevka-foot-audition";
    family = "Iosevka Cadmus Audition";
    defaultOutput = "foot-audition.png";
  };

  webSpecimen = pkgs.runCommand "iosevka-cadmus-web-specimen" { } ''
    mkdir -p "$out/fonts"
    cp ${../specimen/index.html} "$out/index.html"
    cp ${iosevkaCadmus}/share/fonts/truetype/*.ttf "$out/fonts/"
  '';

  webUrl = "file://${webSpecimen}/index.html";
  webFontConfig = mkFontConfig {
    font = iosevkaCadmus;
    family = "Iosevka Cadmus";
  };

  chromium = pkgs.writeShellApplication {
    name = "iosevka-chromium";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      profile="$(mktemp -d)"
      cleanup() { rm -rf "$profile"; }
      trap cleanup EXIT
      export FONTCONFIG_FILE=${webFontConfig}
      export HOME="$profile/home"
      mkdir -p "$HOME"
      ${lib.getExe pkgs.chromium} \
        --user-data-dir="$profile/chromium" \
        --no-first-run \
        --no-default-browser-check \
        --new-window \
        "$@" \
        ${lib.escapeShellArg webUrl}
    '';
  };

  firefox = pkgs.writeShellApplication {
    name = "iosevka-firefox";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      profile="$(mktemp -d)"
      cleanup() { rm -rf "$profile"; }
      trap cleanup EXIT
      export FONTCONFIG_FILE=${webFontConfig}
      export HOME="$profile/home"
      export MOZ_ENABLE_WAYLAND=1
      mkdir -p "$HOME" "$profile/firefox"
      ${lib.getExe pkgs.firefox} \
        --no-remote \
        --profile "$profile/firefox" \
        --new-window ${lib.escapeShellArg webUrl} \
        "$@"
    '';
  };

  chromiumScreenshot = pkgs.writeShellApplication {
    name = "iosevka-chromium-screenshot";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ $# -gt 1 ]]; then
        printf 'usage: iosevka-chromium-screenshot [OUTPUT.png]\n' >&2
        exit 2
      fi
      output="''${1:-$PWD/artifacts/chromium.png}"
      mkdir -p "$(dirname "$output")"
      output="$(realpath -m "$output")"
      profile="$(mktemp -d)"
      cleanup() { rm -rf "$profile"; }
      trap cleanup EXIT
      export FONTCONFIG_FILE=${webFontConfig}
      export HOME="$profile/home"
      mkdir -p "$HOME"
      ${lib.getExe pkgs.chromium} \
        --headless=new \
        --user-data-dir="$profile/chromium" \
        --no-first-run \
        --disable-background-networking \
        --force-device-scale-factor=1 \
        --hide-scrollbars \
        --run-all-compositor-stages-before-draw \
        --virtual-time-budget=1000 \
        --window-size=1600,1450 \
        --screenshot="$output" \
        ${lib.escapeShellArg webUrl}
      test -s "$output"
      printf 'wrote %s\n' "$output"
    '';
  };

  firefoxScreenshot = pkgs.writeShellApplication {
    name = "iosevka-firefox-screenshot";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [[ $# -gt 1 ]]; then
        printf 'usage: iosevka-firefox-screenshot [OUTPUT.png]\n' >&2
        exit 2
      fi
      output="''${1:-$PWD/artifacts/firefox.png}"
      mkdir -p "$(dirname "$output")"
      output="$(realpath -m "$output")"
      profile="$(mktemp -d)"
      cleanup() { rm -rf "$profile"; }
      trap cleanup EXIT
      export FONTCONFIG_FILE=${webFontConfig}
      export HOME="$profile/home"
      export MOZ_HEADLESS=1
      mkdir -p "$HOME" "$profile/firefox"
      ${lib.getExe pkgs.firefox} \
        --headless \
        --no-remote \
        --profile "$profile/firefox" \
        --window-size 1600,1450 \
        --screenshot "$output" \
        ${lib.escapeShellArg webUrl}
      test -s "$output"
      printf 'wrote %s\n' "$output"
    '';
  };

  mkApp = package: {
    type = "app";
    program = lib.getExe package;
  };

  apps = {
    foot = mkApp foot;
    foot-audition = mkApp footAudition;
    foot-screenshot = mkApp footScreenshot;
    foot-audition-screenshot = mkApp footAuditionScreenshot;
    chromium = mkApp chromium;
    chromium-screenshot = mkApp chromiumScreenshot;
    firefox = mkApp firefox;
    firefox-screenshot = mkApp firefoxScreenshot;
  };

  fontCheck =
    pkgs.runCommand "iosevka-cadmus-font-check"
      {
        nativeBuildInputs = [
          (pkgs.python3.withPackages (p: [
            p.fonttools
            p.uharfbuzz
          ]))
        ];
      }
      ''
        python3 ${./check-font.py} ${iosevkaCadmus}/share/fonts/truetype
        touch "$out"
      '';

  check = pkgs.runCommand "iosevka-cadmus-tooling-check" { } ''
    test -f ${webSpecimen}/index.html
    test -f ${webSpecimen}/fonts/IosevkaCadmus-Medium.ttf
    test -f ${webSpecimen}/fonts/IosevkaCadmus-MediumItalic.ttf
    test -f ${webSpecimen}/fonts/IosevkaCadmus-Bold.ttf
    test -f ${webSpecimen}/fonts/IosevkaCadmus-BoldItalic.ttf
    grep -Fq "IosevkaCadmus-Medium.ttf" ${webSpecimen}/index.html
    touch "$out"
  '';
in
{
  inherit
    apps
    check
    fontCheck
    webSpecimen
    ;
}
