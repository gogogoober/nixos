# How windows are tiled: gaps, borders, layout engine, and the per-workspace
# rules that strip decoration when a workspace goes fullscreen. Aesthetic of
# the window itself (rounding, blur, shadow) lives in windows.nix.
{ config, lib, ... }:

with lib;
let
  cfg = config.modules.hyprland;
in
{
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
