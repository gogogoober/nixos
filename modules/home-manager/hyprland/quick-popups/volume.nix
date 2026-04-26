{ pkgs, ... }:

{
  modules.hyprland.popups.volume = {
    command = "${pkgs.wiremix}/bin/wiremix";
    refreshSignal = 8;
    packages = [ pkgs.wiremix ];
  };
}
