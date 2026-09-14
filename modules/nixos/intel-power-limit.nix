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
  cfg = config.modules.intelPowerLimit;

  profileCases = concatStringsSep "\n" (
    mapAttrsToList (
      profile: limits:
      "          ${profile}) sustained_watts=${toString limits.sustainedWatts}; burst_watts=${toString limits.burstWatts} ;;"
    ) cfg.profiles
  );

  applyLimits = pkgs.writeShellApplication {
    name = "intel-power-limit-apply";
    runtimeInputs = with pkgs; [
      coreutils
      glib # gdbus
      jq
      systemd # busctl
    ];
    text = ''
            package_domain=""
            for domain in /sys/class/powercap/intel-rapl:*; do
              if [ -f "$domain/name" ] && [ "$(cat "$domain/name")" = "package-0" ]; then
                package_domain="$domain"
                break
              fi
            done

            if [ -z "$package_domain" ]; then
              echo "no Intel RAPL package domain present, nothing to cap" >&2
              exit 1
            fi

            active_profile() {
              busctl --json=short get-property \
                org.freedesktop.UPower.PowerProfiles \
                /org/freedesktop/UPower/PowerProfiles \
                org.freedesktop.UPower.PowerProfiles \
                ActiveProfile | jq -r '.data // empty'
            }

            # Firmware can lock these registers, so confirm the value took
            write_constraint() {
              constraint=$1
              watts=$2
              file="$package_domain/constraint_''${constraint}_power_limit_uw"
              target=$((watts * 1000000))

              echo "$target" > "$file" || true

              held=$(cat "$file")
              if [ "$held" != "$target" ]; then
                echo "constraint $constraint rejected: asked ''${target}uW, firmware holds ''${held}uW" >&2
                return 1
              fi
            }

            apply_limits() {
              profile=$(active_profile || true)

              if [ -z "$profile" ]; then
                echo "power profile daemon unreachable, leaving limits alone" >&2
                return
              fi

              case "$profile" in
      ${profileCases}
                *)
                  echo "no limits defined for profile $profile, leaving limits alone" >&2
                  return
                  ;;
              esac

              if write_constraint 0 "$sustained_watts" && write_constraint 1 "$burst_watts"; then
                echo "$profile: ''${sustained_watts}W sustained, ''${burst_watts}W burst"
              fi
            }

            apply_limits

            # Signals are only a wake-up; apply_limits re-reads the profile authoritatively
            gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles | while read -r _; do
              apply_limits
            done
    '';
  };
in
{
  options.modules.intelPowerLimit = {
    enable = mkEnableOption "cap the Intel package power limit per power profile";

    profiles = mkOption {
      description = "Package power limits applied when each power-profiles-daemon profile becomes active.";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            sustainedWatts = mkOption {
              type = types.ints.positive;
              description = "Long-term limit, the ceiling the package may hold indefinitely.";
            };
            burstWatts = mkOption {
              type = types.ints.positive;
              description = "Short-term limit, headroom for brief spikes before the long-term cap takes over.";
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.power-profiles-daemon.enable;
        message = "modules.intelPowerLimit.enable requires services.power-profiles-daemon.enable (the active profile is read from its D-Bus interface).";
      }
    ];

    systemd.services.intel-power-limit = {
      description = "Track the active power profile and cap the package power limit";
      wants = [ "power-profiles-daemon.service" ];
      after = [ "power-profiles-daemon.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${applyLimits}/bin/intel-power-limit-apply";
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.intel-power-limit-resume = {
      description = "Reapply the package power limit after resume";
      after = [ "suspend.target" ];
      wantedBy = [ "suspend.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl restart intel-power-limit.service";
      };
    };
  };
}
