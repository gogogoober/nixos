# Touchscreen hardware layer: iio sensors, libwacom pen support
# Compositor-specific touch gestures live in the GNOME or Hyprland module, not here.
# This module is hardware-layer only.
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.touchscreen;
in {
  options.modules.touchscreen = {
    enable = mkEnableOption "touchscreen hardware support";
  };

  config = mkIf cfg.enable {
    hardware.sensor.iio.enable = true;
    services.udev.packages = [ pkgs.libwacom ];
  };
}
