{ pkgs, ... }:

{
  modules.hyprland.popups.wifi = {
    command = "${pkgs.wifitui}/bin/wifitui";
    refreshSignal = 9;
    packages = [ pkgs.wifitui ];
  };
}
