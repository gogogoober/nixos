{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.touchscreen;

  # Reload hid_multitouch to force the touch controller to rebind. Surface
  # Go regression: re-attaching the type cover renumbers the USB device and
  # the driver loses the touchscreen until rebound.
  touchscreenReset = pkgs.writeShellScript "touchscreen-reset" ''
    set -e
    ${pkgs.kmod}/bin/modprobe -r hid_multitouch
    ${pkgs.kmod}/bin/modprobe hid_multitouch
  '';

  touchscreenFix = pkgs.writeShellApplication {
    name = "touchscreen-fix";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      if sudo -n ${touchscreenReset}; then
        notify-send -a Touchscreen "Touchscreen reset" "hid_multitouch reloaded"
      else
        notify-send -a Touchscreen "Touchscreen reset failed" "See journalctl -k"
        exit 1
      fi
    '';
  };
in
{
  options.modules.touchscreen = {
    enable = mkEnableOption "touchscreen hardware support";
  };

  config = mkIf cfg.enable {
    hardware.sensor.iio.enable = true;
    services.udev.packages = [ pkgs.libwacom ];

    environment.systemPackages = [ touchscreenFix ];

    security.sudo.extraRules = [
      {
        groups = [ "wheel" ];
        commands = [
          {
            command = "${touchscreenReset}";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
