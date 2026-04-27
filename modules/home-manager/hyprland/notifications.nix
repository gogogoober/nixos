{ config, lib, ... }:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;
  ds = import ../design-system;
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
