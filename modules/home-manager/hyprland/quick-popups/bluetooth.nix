{ pkgs, ... }:

{
  modules.hyprland.popups.bluetooth = {
    command = "${pkgs.bluetui}/bin/bluetui";
    packages = [ pkgs.bluetui ];
  };
}
