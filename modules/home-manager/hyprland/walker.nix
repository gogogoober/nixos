{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.modules.hyprland;
  toml = pkgs.formats.toml { };

  inherit (import ../design-system) colors;

  walkerConfig = {
    theme = "design-system";

    # Apps stay the no-prefix default. Other providers gate behind their
    # single-character prefixes.
    providers.default = [ "desktopapplications" "calc" ];

    providers.prefixes = [
      { provider = "files"; prefix = "/"; }
      { provider = "runner"; prefix = ">"; }
      { provider = "calc"; prefix = "="; }
      { provider = "websearch"; prefix = "@"; }
      { provider = "clipboard"; prefix = ":"; }
      { provider = "windows"; prefix = "$"; }
      { provider = "providerlist"; prefix = ";"; }
    ];
  };

  # Walker themes inherit from default; only override what changes. We
  # rebind the four GTK named colors at the top of the default stylesheet
  # so every downstream rule picks up the design-system palette.
  walkerStyle = ''
    @define-color window_bg_color ${colors.background.default};
    @define-color accent_bg_color ${colors.text.accent};
    @define-color theme_fg_color ${colors.text.primary};
    @define-color error_bg_color ${colors.status.error};
    @define-color error_fg_color ${colors.text.inverse};

    .box-wrapper {
      border: 1px solid ${colors.border.default};
      border-radius: 16px;
    }

    .input {
      border: 1px solid ${colors.border.focus};
      border-radius: 10px;
    }
  '';
in
{
  config = mkIf cfg.enable {
    home.packages = [ pkgs.walker pkgs.elephant ];

    xdg.configFile."walker/config.toml".source =
      toml.generate "walker-config.toml" walkerConfig;

    xdg.configFile."walker/themes/design-system/style.css".text = walkerStyle;

    # Elephant is walker's provider backend and must be running before
    # walker connects. Walker's gapplication-service then keeps the UI
    # process warm so the keybind opens instantly.
    wayland.windowManager.hyprland.settings.exec-once = [
      "elephant"
      "walker --gapplication-service"
    ];
  };
}
