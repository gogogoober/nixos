# Touchscreen hardware layer: udev rules, iio-sensor-proxy, palm rejection
{ config, lib, pkgs, ... }:

with lib;
let cfg = config.modules.touchscreen;
in {
  options.modules.touchscreen = {
    enable = mkEnableOption "touchscreen hardware support";
  };

  config = mkIf cfg.enable {
    # Touchscreen config goes here
  };
}
