{ pkgs, ... }:

{
  modules.hyprland.popups.battery = {
    command = "${pkgs.bottom}/bin/btm";
    packages = [ pkgs.bottom ];
  };
}
