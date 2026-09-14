{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.gnome;

  speechPanel = pkgs.runCommand "gnome-shell-extension-speech-panel" { } ''
    mkdir -p $out/share/gnome-shell/extensions
    cp -r ${./scripts/speech-panel} $out/share/gnome-shell/extensions/speech-panel@nixos
  '';

  powerDraw = pkgs.runCommand "gnome-shell-extension-power-draw" { } ''
    mkdir -p $out/share/gnome-shell/extensions
    cp -r ${./scripts/power-draw} $out/share/gnome-shell/extensions/power-draw@nixos
  '';
in
{
  options.modules.gnome = {
    enable = mkEnableOption "GNOME desktop environment";

    display = mkOption {
      default = null;
      description = "Built-in panel written to GNOME's monitors.xml. Null leaves GNOME's own display settings alone and editable in Settings.";
      type = types.nullOr (
        types.submodule {
          options = {
            connector = mkOption {
              type = types.str;
              description = "Output name, as the kernel names it.";
            };
            vendor = mkOption {
              type = types.str;
              description = "Panel vendor, as reported by EDID.";
            };
            product = mkOption {
              type = types.str;
              description = "Panel product id, as reported by EDID.";
            };
            serial = mkOption {
              type = types.str;
              default = "0x00000000";
              description = "Panel serial, as reported by EDID.";
            };
            width = mkOption {
              type = types.ints.positive;
              description = "Horizontal resolution in pixels.";
            };
            height = mkOption {
              type = types.ints.positive;
              description = "Vertical resolution in pixels.";
            };
            rate = mkOption {
              type = types.str;
              description = "Refresh rate, formatted exactly as the compositor advertises it.";
            };
            scale = mkOption {
              type = types.ints.positive;
              default = 1;
              description = "Integer display scale.";
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.desktop.enable;
        message = "modules.gnome.enable requires modules.desktop.enable (xserver, GDM, and pipewire live there).";
      }
    ];

    services.desktopManager.gnome.enable = true;

    services.gnome.localsearch.enable = false; # File-content indexer, too heavy here

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour # Welcome/onboarding
      epiphany # GNOME Web browser
      gnome-music # Music player
      gnome-maps # Maps
      gnome-weather # Weather
      totem # Video player
    ];

    environment.systemPackages = with pkgs; [
      gnome-tweaks # GUI for GNOME tweaks
      dconf-editor # Low-level dconf editor
      gnomeExtensions.forge # Tiling window manager extension
      speechPanel # Top bar dictate and speak toggles
      powerDraw # Watts drawn, beside the battery indicator
    ];

    services.udev.packages = [ pkgs.gnome-settings-daemon ];

    home-manager.users.${config.modules.user.name}.modules.gnome = {
      enable = true;
      inherit (cfg) display;
    };
  };
}
