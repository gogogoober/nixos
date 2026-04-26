{ pkgs, ... }:

{
  modules.hyprland.popups.bluetooth = {
    command = "${pkgs.bluetui}/bin/bluetui";
    refreshSignal = 10;
    packages = [ pkgs.bluetui ];
  };
}
