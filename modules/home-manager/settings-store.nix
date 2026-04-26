{
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  loc = osConfig.modules.location;

  defaults = {
    location = {
      inherit (loc)
        city
        state
        country
        units
        ;
    };
  };

  # Reads ~/.config/quick-settings/defaults.json (nix-managed) and
  # optionally merges ~/.config/quick-settings/settings.json on top.
  # Usage: quick-settings-get location.city
  reader = pkgs.writeShellScriptBin "quick-settings-get" ''
    set -eu
    dir="''${XDG_CONFIG_HOME:-$HOME/.config}/quick-settings"
    defaults="$dir/defaults.json"
    overrides="$dir/settings.json"
    key=".$1"
    if [ -f "$overrides" ]; then
      ${pkgs.jq}/bin/jq -r -s ".[0] * .[1] | $key" "$defaults" "$overrides"
    else
      ${pkgs.jq}/bin/jq -r "$key" "$defaults"
    fi
  '';
in
{
  home.packages = [ reader ];

  xdg.configFile."quick-settings/defaults.json".text = builtins.toJSON defaults;
}
