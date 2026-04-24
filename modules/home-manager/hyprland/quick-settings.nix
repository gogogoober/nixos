# Quick settings panel: a single popover exposing the toggles/sliders the
# user reaches for most (Wi-Fi, Bluetooth, volume, brightness, night light,
# notification DND, etc.) without digging into separate apps.
#
# Placeholder — no implementation yet. Likely options: a waybar custom module
# that launches an eww/ags/yad window, or an overlay similar to overlay.nix.
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
  config = mkIf cfg.enable {
    # Intentionally empty.
  };
}
