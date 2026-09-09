{ config, lib, ... }:

let
  inherit (lib) mkIf;
in
{
  config = mkIf config.modules.hyprland.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };

        listener = [
          {
            timeout = 420;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };
}
