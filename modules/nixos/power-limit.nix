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
  cfg = config.modules.powerLimit;

  applyLimits = pkgs.writeShellApplication {
    name = "power-limit-apply";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      sustained_watts=${toString cfg.sustainedWatts}
      burst_watts=${toString cfg.burstWatts}

      package_domain=""
      for domain in /sys/class/powercap/intel-rapl:*; do
        if [ -f "$domain/name" ] && [ "$(cat "$domain/name")" = "package-0" ]; then
          package_domain="$domain"
          break
        fi
      done

      if [ -z "$package_domain" ]; then
        echo "no RAPL package domain present, nothing to cap" >&2
        exit 1
      fi

      # Firmware can lock these registers, so confirm the value took
      apply_constraint() {
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
        echo "constraint $constraint capped at ''${watts}W"
      }

      rejected=0
      apply_constraint 0 "$sustained_watts" || rejected=1
      apply_constraint 1 "$burst_watts" || rejected=1
      exit "$rejected"
    '';
  };
in
{
  options.modules.powerLimit = {
    enable = mkEnableOption "cap the package power limit below the firmware default";

    sustainedWatts = mkOption {
      type = types.ints.positive;
      description = "Long-term package power limit, the ceiling the chip may hold indefinitely.";
    };

    burstWatts = mkOption {
      type = types.ints.positive;
      description = "Short-term package power limit, headroom for brief bursts before the long-term cap takes over.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.power-limit = {
      description = "Cap the package power limit below the firmware default";
      after = [ "suspend.target" ];
      wantedBy = [
        "multi-user.target"
        "suspend.target" # Firmware restores its own limits on resume
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${applyLimits}/bin/power-limit-apply";
      };
    };
  };
}
