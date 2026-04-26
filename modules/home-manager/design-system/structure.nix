# Layout, spacing, motion, and interaction tokens
# Sourced from docs/design-system/structure.md, all px unless noted
# Convert to rem at the boundary by dividing by 16
{
  # 4px base scale, multiples only. Step number from the doc kept as a comment
  spacing = {
    none = 0; # Step 0, flush
    xs = 4; # Step 1, icon-to-label
    sm = 8; # Step 2, tight stacks
    md = 12; # Step 3, form rhythm
    base = 16; # Step 4, card padding
    lg = 24; # Step 6, major section
    xl = 32; # Step 8, page gutter
    "2xl" = 48; # Step 12, hero
    "3xl" = 64; # Step 16, empty-state
  };

  border-width = {
    none = 0;
    thin = 1; # Default UI borders
    thick = 2; # Focus rings, emphasis
  };

  # Radii, not in the source doc, picked from the 4px scale
  radius = {
    none = 0;
    sm = 4; # Inputs, chips
    md = 8; # Buttons, cards
    lg = 16; # Panels, modals (1rem)
    pill = 9999; # Tags, fully rounded
  };

  # Focus ring composition, color lives in colors.state.focus-ring
  focus-ring = {
    width = 2;
    offset = 2;
  };

  layout = {
    columns = {
      desktop = 12;
      tablet = 8;
      mobile = 4;
    };
    gutter = 8; # Constant across sizes
    breakpoint = {
      sm = 640;
      md = 768;
      lg = 1024;
      xl = 1280;
      "2xl" = 1536;
    };
  };

  # Minimum interactive sizes
  hit-target = {
    dense = 32; # Toolbars and lists
    default = 40; # General use
    touch = 44; # Touch primary
  };

  # Standard row heights for lists and tables, pick one per view
  row-height = {
    compact = 32;
    default = 40;
    comfortable = 48;
  };

  # Durations in ms, easings as CSS keywords
  motion = {
    duration = {
      state = 150; # Hover, press
      enter = 250; # Element entering
      exit = 200; # Element leaving
      reduced = 100; # prefers-reduced-motion ceiling
    };
    easing = {
      enter = "ease-out";
      exit = "ease-in";
      in-place = "ease-in-out";
    };
  };

  # Stacking layers, leave gaps for ad-hoc tiers
  z = {
    base = 0;
    raised = 10;
    sticky = 100;
    dropdown = 500;
    overlay = 1000;
    modal = 1100;
    toast = 1200;
    tooltip = 1300;
  };

  # Modal scrim opacity, color lives in colors.overlay.scrim
  scrim-opacity = 0.6;
}
