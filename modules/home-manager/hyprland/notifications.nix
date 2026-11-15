{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
  ds = import ../design-system;
in
{
  config = mkIf cfg.enable {
    # default-timeout is in milliseconds
    xdg.configFile."mako/config".text = ''
      default-timeout=2000
      font=JetBrainsMono Nerd Font 11
      anchor=top-right

      background-color=${ds.colors.background.deepest}
      text-color=${ds.colors.text.primary}
      border-color=${ds.colors.surface.default}
      border-size=1
      border-radius=0

      padding=12
      margin=12
      max-icon-size=32

      [urgency=low]
      border-color=${ds.colors.border.subtle}

      [urgency=normal]
      border-color=${ds.colors.text.link}

      [urgency=critical]
      border-color=${ds.colors.border.error}
      default-timeout=0
    '';
  };
}
