{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkForce
    mkIf
    ;
  cfg = config.modules.autoUpgrade;

  host = config.networking.hostName;
  flake = inputs.self.outPath;

  upgradeSchedule = "Mon 09:00";
  scheduleJitter = "45min";
  maxHeldBack = 3; # More failures than this is a toolchain break, not a leaf package

  stateDir = "/var/lib/nixos-upgrade";

  # Revision this system was built from, which is a revision where anything
  # newly broken at the channel tip still built
  runningRev = toString config.system.nixos.revision;

  # Wraps the repo flake and swaps the named packages for the revision they
  # last built at. @inputs@ and @overrides@ take one generated line per hold.
  # The wrapper inherits target's lock rather than re-resolving it, so the
  # tree it builds is whatever the first pass just re-locked in place
  fallbackTemplate = pkgs.writeText "nixos-upgrade-fallback-flake.nix" ''
    {
      inputs = {
        target.url = "path:@target@";
    @inputs@
      };

      outputs =
        inputs@{ target, ... }:
        {
          nixosConfigurations."@host@" = target.nixosConfigurations."@host@".extendModules {
            modules = [
              {
                nixpkgs.overlays = [
                  (
                    final: prev:
                    let
                      held =
                        rev:
                        import inputs."held-''${rev}" {
                          inherit (prev.stdenv.hostPlatform) system;
                          inherit (prev) config;
                        };
                    in
                    {
    @overrides@
                    }
                  )
                ];
              }
            ];
          };
        };
    }
  '';

  upgradeScript = pkgs.writeShellApplication {
    name = "nixos-upgrade-with-fallback";
    runtimeInputs = [
      config.nix.package
      config.system.build.nixos-rebuild
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
    ];
    text = ''
      state_dir=${stateDir}
      held_file="$state_dir/held-back"
      work_dir="$state_dir/work"
      log="$state_dir/last-attempt.log"

      mkdir -p "$state_dir"

      # First pass takes the whole channel tip, including anything held back
      # last week, which is how a fixed package stops being held
      if nixos-rebuild switch --flake ${flake}#${host} --recreate-lock-file -L --refresh 2>&1 | tee "$log"; then
        rm -f "$held_file"
        exit 0
      fi

      # Root causes only: a derivation whose own builder failed, never the
      # dependents that failed along with it
      mapfile -t broken < <(
        awk '
          /^error: Cannot build / { drv = $0; next }
          /Reason: builder failed/ { if (drv != "") print drv; drv = "" }
        ' "$log" \
          | sed "s|.*/nix/store/[a-z0-9]\{32\}-||; s|\.drv'.*||; s|-[0-9][0-9a-zA-Z.+_-]*$||" \
          | sort -u
      )

      if [ "''${#broken[@]}" -eq 0 ]; then
        echo "upgrade failed with no single package to blame" >&2
        exit 1
      fi

      if [ "''${#broken[@]}" -gt ${toString maxHeldBack} ]; then
        echo "''${#broken[@]} packages failed, too many to hold back" >&2
        exit 1
      fi

      running_rev=${runningRev}
      if [ -z "$running_rev" ]; then
        echo "the running system records no nixpkgs revision to fall back to" >&2
        exit 1
      fi

      rm -rf "$work_dir"
      mkdir -p "$work_dir"
      holds="$work_dir/holds"
      : > "$holds"

      for attr in "''${broken[@]}"; do
        # An already-held package keeps its revision, since the running
        # system was built from one where the newly broken ones still worked
        rev=$(awk -v attr="$attr" '$1 == attr { print $2; exit }' "$held_file" 2>/dev/null || true)
        if [ -z "$rev" ]; then
          rev=$running_rev
        fi
        if ! NIXPKGS_ALLOW_UNFREE=1 nix eval --impure --raw \
          "github:NixOS/nixpkgs/$rev#$attr.name" >/dev/null 2>&1; then
          echo "no $attr in nixpkgs $rev, nothing to hold it back to" >&2
          exit 1
        fi
        printf '%s %s\n' "$attr" "$rev" >> "$holds"
      done

      awk '{ printf "    \"held-%s\".url = \"github:NixOS/nixpkgs/%s\";\n", $2, $2 }' "$holds" \
        | sort -u > "$work_dir/inputs.part"
      awk '{ printf "                      %s = (held \"%s\").%s;\n", $1, $2, $1 }' "$holds" \
        > "$work_dir/overrides.part"

      sed -e "s|@target@|${flake}|" \
        -e "s|@host@|${host}|g" \
        -e "/@inputs@/r $work_dir/inputs.part" -e "/@inputs@/d" \
        -e "/@overrides@/r $work_dir/overrides.part" -e "/@overrides@/d" \
        ${fallbackTemplate} > "$work_dir/flake.nix"

      # The wrapper inherits target's lock, so a first pass that died before
      # re-locking would have us rebuild the running system and call it an
      # upgrade
      wrapper_rev=$(nix eval --raw "$work_dir#nixosConfigurations.\"${host}\".config.system.nixos.revision")
      if [ "$wrapper_rev" = "$running_rev" ]; then
        echo "the fallback would rebuild the running revision, not upgrading" >&2
        exit 1
      fi

      echo "retrying with held back: $(cut -d' ' -f1 "$holds" | tr '\n' ' ')"
      nixos-rebuild switch --flake "$work_dir#${host}" --recreate-lock-file -L
      cp "$holds" "$held_file"
    '';
  };
in
{
  options.modules.autoUpgrade = {
    enable = mkEnableOption "weekly upgrade that holds back packages whose build breaks" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = flake;
      dates = upgradeSchedule;
      randomizedDelaySec = scheduleJitter;
      persistent = true;
    };

    # Upstream's script gives up on the first broken package; ours retries
    # once with that package pulled from the revision it last built at.
    # Rebuild flags live in the script, so system.autoUpgrade.flags is unused
    systemd.services.nixos-upgrade = {
      script = mkForce "exec ${upgradeScript}/bin/nixos-upgrade-with-fallback";
      unitConfig.ConditionACPower = true; # Skipped weeks wait for the next Monday
    };
  };
}
