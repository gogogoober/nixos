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
      power-profiles-daemon # powerprofilesctl
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

            # Exit lets Restart=always retry until the daemon is on the bus
            if [ -z "$(active_profile || true)" ]; then
              echo "power profile daemon not on the bus yet" >&2
              exit 1
            fi

            # Survives a restart, dropped with the session, so a crash never undoes a deliberate switch
            session_marker="$RUNTIME_DIRECTORY/applied"
            if [ ! -e "$session_marker" ]; then
              powerprofilesctl set "${cfg.loginProfile}"
              apply_brightness "${cfg.loginProfile}"
              touch "$session_marker"
            fi

            last_profile=$(active_profile)

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
    enable = mkEnableOption "reset the power profile and screen brightness at login, then follow later profile switches";

    greeterPercent = mkOption {
      type = types.ints.between 1 100;
      description = "Screen brightness percentage held outside a user session, so the login screen never inherits a level from one.";
    };

    loginProfile = mkOption {
      type = types.str;
      description = "Power profile forced at every login, discarding whatever was active in the last session.";
    };

    profiles = mkOption {
      type = types.attrsOf (types.ints.between 1 100);
      description = "Screen brightness percentage applied at session start and whenever a power-profiles-daemon profile becomes active. Adjusting brightness by hand afterwards is never overridden.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.power-profiles-daemon.enable;
        message = "modules.profileBrightness.enable requires services.power-profiles-daemon.enable (the active profile is read from its D-Bus interface).";
      }
      {
        assertion = cfg.profiles ? ${cfg.loginProfile};
        message = "modules.profileBrightness.loginProfile is set to \"${cfg.loginProfile}\", which has no entry in modules.profileBrightness.profiles.";
      }
    ];

    # Restoring the last session's level only fights the profile that sets it
    systemd.services."systemd-backlight@".enable = false;

    systemd.services.greeter-brightness = {
      description = "Hold a fixed screen brightness outside a user session";
      before = [ "display-manager.service" ];
      wantedBy = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.brightnessctl}/bin/brightnessctl set ${toString cfg.greeterPercent}%";
      };
    };

    systemd.user.services.profile-brightness = {
      description = "Reset the power profile at login and match screen brightness to it";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${followProfile}/bin/profile-brightness";
        Restart = "always";
        RestartSec = 5;
        RuntimeDirectory = "profile-brightness";
        RuntimeDirectoryPreserve = "restart";
      };
    };
  };
}
