{ pkgs, inputs, ... }:

let
  fsel = inputs.fsel.packages.${pkgs.stdenv.hostPlatform.system}.default;
  toml = pkgs.formats.toml { };

  inherit (import ../../design-system) colors;

  fselConfig = {
    terminal_launcher = "ghostty -e";
    rounded_borders = true;

    highlight_color = colors.text.accent;
    header_title_color = colors.text.accent;
    input_border_color = colors.border.focus;
    main_border_color = colors.border.default;
    apps_border_color = colors.border.default;
    pin_color = colors.status.warn;

    # fsel restricts these three to named colors, hex is rejected
    main_text_color = "White";
    apps_text_color = "White";
    input_text_color = "White";
  };

  # Pinned verbatim from upstream defaults. Mixed string-and-table arrays
  # are not representable through pkgs.formats.toml, so this stays literal.
  fselKeybinds = ''
    down = ["down", { key = "n", modifiers = "ctrl" }]
    up = ["up", { key = "p", modifiers = "ctrl" }]
    left = ["left"]
    right = ["right"]
    select = ["enter", { key = "y", modifiers = "ctrl" }]
    exit = ["esc", { key = "q", modifiers = "ctrl" }, { key = "c", modifiers = "ctrl" }]
    pin = [{ key = "space", modifiers = "ctrl" }]
    backspace = ["backspace"]
    image_preview = [{ key = "i", modifiers = "alt" }]
    tag = [{ key = "t", modifiers = "ctrl" }]
  '';
in
{
  modules.hyprland.popups.launcher = {
    type = "launcher";
    command = "${fsel}/bin/fsel -d";
    packages = [ fsel ];
  };

  xdg.configFile."fsel/config.toml".source = toml.generate "fsel-config.toml" fselConfig;
  xdg.configFile."fsel/keybinds.toml".text = fselKeybinds;
}
