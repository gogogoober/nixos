{ pkgs, ... }:

{
  modules.hyprland.popups.volume = {
    command = "${pkgs.wiremix}/bin/wiremix --tab output";
    refreshSignal = 8;
    packages = [ pkgs.wiremix ];
  };
}
