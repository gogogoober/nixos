{
  config,
  lib,
  ...
}:

with lib;
let
  cfg = config.modules.hyprland;
  ds = import ../design-system;

  px = n: "${toString n}px";

  style = ''
    window {
      background-color: ${ds.colors.background.deepest};
      border: ${px ds.structure.border-width.thin} solid ${ds.colors.border.default};
      border-radius: ${px ds.structure.radius.md};
      font-family: ${ds.fonts.family.ui};
      font-size: ${px ds.fonts.role.body.size};
      color: ${ds.colors.text.primary};
    }

    #input {
      margin: ${px ds.structure.spacing.sm};
      padding: ${px ds.structure.spacing.sm} ${px ds.structure.spacing.md};
      background-color: ${ds.colors.surface.default};
      color: ${ds.colors.text.primary};
      border: ${px ds.structure.border-width.thin} solid ${ds.colors.border.default};
      border-radius: ${px ds.structure.radius.sm};
      caret-color: ${ds.colors.state.cursor};
    }

    #input:focus {
      border-color: ${ds.colors.border.focus};
      outline: none;
    }

    #input image {
      color: ${ds.colors.text.muted};
    }

    #outer-box,
    #scroll {
      background-color: transparent;
      border: none;
      padding: 0;
      margin: 0;
    }

    #inner-box {
      background-color: transparent;
      border: none;
      margin: 0;
      padding: ${px ds.structure.spacing.xs};
    }

    #entry {
      margin: 0 ${px ds.structure.spacing.xs};
      padding: 0;
      background-color: transparent;
      border-radius: ${px ds.structure.radius.sm};
      min-height: ${px ds.structure.row-height.compact};
    }

    #entry:selected {
      background-color: ${ds.colors.state.hover};
    }

    #text {
      color: ${ds.colors.text.primary};
      padding: ${px ds.structure.spacing.sm} ${px ds.structure.spacing.md};
    }

    #entry:selected #text {
      color: ${ds.colors.text.primary};
    }

    #unselected {
      color: ${ds.colors.text.secondary};
    }
  '';

  settings = ''
    allow_markup=true
    hide_scroll=true
    gtk_dark=true
    location=center
    insensitive=true
    prompt=
  '';
in
{
  config = mkIf cfg.enable {
    xdg.configFile."wofi/style.css".text = style;
    xdg.configFile."wofi/config".text = settings;
  };
}
