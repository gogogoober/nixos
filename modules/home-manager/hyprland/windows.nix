# Tiling behaviour and appearance: gaps, borders, rounding, blur/shadow, and
# the per-workspace rules that strip decoration in fullscreen.
{ config, lib, ... }:

with lib;
let cfg = config.modules.hyprland;
in {
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      general = {
        gaps_in = 2;
        gaps_out = 8;
        border_size = 1;
        "col.active_border" = "rgba(ccccffff)";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = true;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 4;
        shadow = {
          enabled = true;
          range = 2;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      # Smart gaps: drop borders/rounding/gaps only when a workspace is
      # fullscreen (f[1]). A lone tiled window still gets outer margin.
      workspace = [
        "f[1], gapsout:0, gapsin:0"
      ];

      windowrule = [
        "border_size 0, rounding 0, match:float 0, match:workspace f[1]"
      ];
    };
  };
}
