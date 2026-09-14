{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.chargerWatch;

  adapterOnline = "/sys/class/power_supply/${cfg.adapter}/online";
  batteryStatus = "/sys/class/power_supply/${cfg.battery}/status";

  firstCheckDelay = "2min"; # Let the desktop session come up first
  checkInterval = "20min";

  alertTitle = "Charger not detected";
  alertBody = "The charge controller lost the adapter. ${cfg.recovery}";

  checkScript = pkgs.writeShellApplication {
    name = "charger-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
    ];
    text = ''
      runtime_dir="/run/user/$(id -u)"
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
      warned_marker="$runtime_dir/charger-latch-warned"

      adapter_online=$(cat ${adapterOnline})
      battery_status=$(cat ${batteryStatus})

      # Unplugged reads Discharging, so this pair means the controller
      # latched off with the charger still attached
      if [ "$adapter_online" = "0" ] && [ "$battery_status" = "Not charging" ]; then
        if [ ! -e "$warned_marker" ]; then
          notify-send --urgency=critical --icon=battery-caution \
            ${lib.escapeShellArg alertTitle} ${lib.escapeShellArg alertBody} || true
          touch "$warned_marker"
        fi
      else
        rm -f "$warned_marker"
      fi
    '';
  };
in
{
  options.modules.chargerWatch = {
    enable = mkEnableOption "notify when the charge controller stops seeing the adapter";

    adapter = mkOption {
      type = types.str;
      example = "ACAD";
      description = "Mains adapter device under /sys/class/power_supply.";
    };

    battery = mkOption {
      type = types.str;
      example = "BAT1";
      description = "Battery device under /sys/class/power_supply.";
    };

    recovery = mkOption {
      type = types.str;
      example = "Hold volume-up + power for 20 seconds, release, then power on.";
      description = "How to clear the latch on this machine. Appended to the notification, so it must be the recovery this hardware actually needs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.charger-watch = {
      description = "Check whether the charge controller still sees the adapter";
      after = [ "suspend.target" ];
      wantedBy = [ "suspend.target" ]; # Also run on resume
      serviceConfig = {
        Type = "oneshot";
        User = config.modules.user.name;
        ExecStart = "${checkScript}/bin/charger-watch";
      };
    };

    systemd.timers.charger-watch = {
      description = "Periodic charge controller check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = firstCheckDelay;
        OnUnitActiveSec = checkInterval;
      };
    };
  };
}
