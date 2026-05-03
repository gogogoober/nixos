{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf;
  cfg = config.modules.hyprland;

  wallpaperDir = ../../../assets/wallpapers;

  wallpaperCycle = pkgs.writeShellScript "hyprpaper-cycle" ''
    set -eu
    export PATH=${pkgs.hyprland}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:$PATH
    DIR="${wallpaperDir}"
    FILE=$(find "$DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \) | shuf -n 1)
    if [ -n "$FILE" ]; then
      hyprctl hyprpaper preload "$FILE"
      hyprctl hyprpaper wallpaper ",$FILE"
      hyprctl hyprpaper unload unused
    fi
  '';
in
{
  config = mkIf cfg.enable {
    # Hyprpaper reads this on start; cycle script drives wallpapers via IPC
    xdg.configFile."hypr/hyprpaper.conf".text = ''
      splash = false
      ipc = on
    '';

    systemd.user.services.hyprpaper-cycle = {
      Unit = {
        Description = "Cycle Hyprland wallpaper from assets/wallpapers";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${wallpaperCycle}";
      };
    };

    systemd.user.timers.hyprpaper-cycle = {
      Unit.Description = "Cycle Hyprland wallpaper every 5 minutes";
      Timer = {
        OnActiveSec = "10s";
        OnUnitActiveSec = "5min";
        Unit = "hyprpaper-cycle.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
