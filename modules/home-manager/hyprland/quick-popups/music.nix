{ pkgs, ... }:

{
  modules.hyprland.popups.music = {
    command = "${pkgs.spotify-player}/bin/spotify_player";
    persistent = true;
    packages = [ pkgs.spotify-player ];
  };
}
