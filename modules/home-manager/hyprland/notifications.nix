{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    # Mako is launched by exec-once in startup.nix; this just writes the
    # config it reads on start. Default-timeout is in milliseconds; 0 means
    # no expiration, which is mako's default and the reason notifications
    # were sticking.
    xdg.configFile."mako/config".text = ''
      default-timeout=2000
    '';
  };
}
