{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.touchscreen;
in
{
  options.modules.touchscreen = {
    enable = mkEnableOption "touchscreen hardware support";
  };

  config = mkIf cfg.enable {
    hardware.sensor.iio.enable = true;
    services.udev.packages = [ pkgs.libwacom ];
  };
}
