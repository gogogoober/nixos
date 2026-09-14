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
    mapAttrsToList
    concatStringsSep
    ;
  cfg = config.modules.profileBrightness;

  profileCases = concatStringsSep "\n" (
    mapAttrsToList (
      profile: percent: "          ${profile}) percent=${toString percent} ;;"
    ) cfg.profiles
  );

  followProfile = pkgs.writeShellApplication {
    name = "profile-brightness";
    runtimeInputs = with pkgs; [
      brightnessctl
      coreutils
      glib # gdbus
      jq
      systemd # busctl
    ];
    text = ''
            active_profile() {
              busctl --json=short get-property \
                org.freedesktop.UPower.PowerProfiles \
                /org/freedesktop/UPower/PowerProfiles \
                org.freedesktop.UPower.PowerProfiles \
                ActiveProfile | jq -r '.data // empty'
            }

            apply_brightness() {
              case "$1" in
      ${profileCases}
                *) return ;;
              esac

              brightnessctl set "''${percent}%" >/dev/null
              echo "$1: brightness ''${percent}%"
            }

            # Recorded without applying, so restarting never overrides a manual setting
            last_profile=$(active_profile || true)

            gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles | while read -r _; do
              profile=$(active_profile || true)

              # Only a genuine switch sets brightness; anything else leaves it alone
              if [ -n "$profile" ] && [ "$profile" != "$last_profile" ]; then
                last_profile="$profile"
                apply_brightness "$profile"
              fi
            done
    '';
  };
in
{
  options.modules.profileBrightness = {
    enable = mkEnableOption "set a default screen brightness when the power profile changes";

    profiles = mkOption {
      type = types.attrsOf types.ints.positive;
      default = { };
      description = "Screen brightness percentage applied when each power-profiles-daemon profile becomes active. Adjusting brightness by hand afterwards is never overridden.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.power-profiles-daemon.enable;
        message = "modules.profileBrightness.enable requires services.power-profiles-daemon.enable (the active profile is read from its D-Bus interface).";
      }
    ];

    systemd.user.services.profile-brightness = {
      description = "Set a default screen brightness when the power profile changes";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${followProfile}/bin/profile-brightness";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
