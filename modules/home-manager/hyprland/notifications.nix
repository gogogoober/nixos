{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;

  # Catppuccin Mocha tokens — see docs/design-system/colors.md.
  # Mirrors the palette used in bar.nix so notifications read as part of the
  # same chrome rather than landing in mako's default beige.
  crust = "#11111b";
  surface0 = "#313244";
  text = "#cdd6f4";
  overlay0 = "#6c7086";
  blue = "#89b4fa";
  red = "#f38ba8";
in
{
  config = mkIf cfg.enable {
    # Mako is launched by exec-once in startup.nix; this just writes the
    # config it reads on start. Default-timeout is in milliseconds; 0 means
    # no expiration, which is mako's default and the reason notifications
    # were sticking.
    xdg.configFile."mako/config".text = ''
      default-timeout=2000
      font=JetBrainsMono Nerd Font 11
      anchor=top-right

      background-color=${crust}
      text-color=${text}
      border-color=${surface0}
      border-size=1
      border-radius=0

      padding=12
      margin=12
      max-icon-size=32

      [urgency=low]
      border-color=${overlay0}

      [urgency=normal]
      border-color=${blue}

      [urgency=critical]
      border-color=${red}
      default-timeout=0
    '';
  };
}
