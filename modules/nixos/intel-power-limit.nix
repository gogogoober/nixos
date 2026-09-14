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

  recheckSeconds = "60"; # How often to re-check inside the settle window
  settleSeconds = "300"; # Firmware reclaims the sustained register shortly after start

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

            # The driver registers its domains late in boot; Restart=always retries
            if [ -z "$package_domain" ]; then
              echo "no Intel RAPL package domain present yet" >&2
              exit 1
            fi

            active_profile() {
              busctl --json=short get-property \
                org.freedesktop.UPower.PowerProfiles \
                /org/freedesktop/UPower/PowerProfiles \
                org.freedesktop.UPower.PowerProfiles \
                ActiveProfile | jq -r '.data // empty'
            }

            # Sets `changed` so a quiet recheck stays out of the journal
            write_constraint() {
              constraint=$1
              watts=$2
              file="$package_domain/constraint_''${constraint}_power_limit_uw"
              target=$((watts * 1000000))

              if [ "$(cat "$file")" = "$target" ]; then
                return 0
              fi

              echo "$target" > "$file" || true

              held=$(cat "$file")
              if [ "$held" != "$target" ]; then
                echo "constraint $constraint rejected: asked ''${target}uW, firmware holds ''${held}uW" >&2
                return 1
              fi
              changed=1
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

              changed=0
              write_constraint 0 "$sustained_watts" || return
              write_constraint 1 "$burst_watts" || return

              if [ "$changed" = 1 ]; then
                echo "$profile: ''${sustained_watts}W sustained, ''${burst_watts}W burst"
              fi
            }

            # Exit lets Restart=always retry until the daemon is on the bus
            if [ -z "$(active_profile || true)" ]; then
              echo "power profile daemon not on the bus yet" >&2
              exit 1
            fi

            apply_limits

            settle_deadline=$((SECONDS + ${settleSeconds}))

            # Re-check only while the limits are settling; drift after that is a different bug
            gdbus monitor --system --dest org.freedesktop.UPower.PowerProfiles | while :; do
              read_status=0
              if [ "$SECONDS" -lt "$settle_deadline" ]; then
                read -r -t ${recheckSeconds} _ || read_status=$?
              else
                read -r _ || read_status=$?
              fi

              # Over 128 is the read timeout; anything else non-zero means the monitor died
              if [ "$read_status" -ne 0 ] && [ "$read_status" -le 128 ]; then
                echo "profile monitor closed" >&2
                exit 1
              fi

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
      # Ordering after the daemon deadlocks: it starts after multi-user.target, which wants this
      wants = [ "power-profiles-daemon.service" ];
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
