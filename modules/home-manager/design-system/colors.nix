# Semantic color tokens, sourced from docs/design-system/colors.md
# Catppuccin Mocha. Hex includes alpha channel where opacity is baked in.
{
  # Raw palette, reach for these only when the semantic role does not fit
  palette = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";

    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";

    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    overlay2 = "#9399b2";

    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";

    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
  };

  # Window chrome and app shell
  background = {
    default = "#1e1e2e"; # Base, app background
    dark = "#181825"; # Mantle, sidebars and secondary panes
    deepest = "#11111b"; # Crust, title bars and status bars
  };

  # Raised elements that sit on top of the background
  surface = {
    default = "#313244"; # Surface 0, cards and inputs
    raised = "#45475a"; # Surface 1, hovered surfaces and dividers
    pressed = "#585b70"; # Surface 2, active and selected
    disabled = "#31324480"; # Surface 0 at 50% opacity
  };

  border = {
    default = "#45475a"; # Surface 1, standard divider
    subtle = "#6c7086"; # Overlay 0, faint
    strong = "#7f849c"; # Overlay 1, emphasis
    focus = "#b4befe"; # Lavender, keyboard focus ring
    error = "#f38ba8"; # Red
    warn = "#f9e2af"; # Yellow
    success = "#a6e3a1"; # Green
    info = "#94e2d5"; # Teal
    attention = "#f2cdcd"; # Flamingo, gentle pull
  };

  text = {
    primary = "#cdd6f4"; # Body and headlines
    secondary = "#bac2de"; # Sub-headlines, secondary labels
    tertiary = "#a6adc8"; # Tertiary labels, metadata
    muted = "#7f849c"; # Comment-tier, de-emphasized
    disabled = "#6c7086"; # Overlay 0
    inverse = "#1e1e2e"; # Base, text drawn on accent backgrounds
    link = "#89b4fa"; # Blue
    link-visited = "#cba6f7"; # Mauve
    error = "#f38ba8"; # Red
    alert = "#f38ba8"; # Alias of error
    warn = "#f9e2af"; # Yellow
    success = "#a6e3a1"; # Green
    info = "#94e2d5"; # Teal
    attention = "#f5c2e7"; # Pink, decorative pull
    accent = "#cba6f7"; # Mauve, brand accent
  };

  # Action / button color sets, paired bg + on (foreground on top)
  action = {
    primary-bg = "#89b4fa"; # Blue
    primary-on = "#1e1e2e"; # Base on accent
    primary-hover-bg = "#74c7ec"; # Sapphire, one step cooler
    primary-pressed-bg = "#89b4fabf"; # Blue at 75%

    secondary-bg = "#313244"; # Surface 0
    secondary-on = "#cdd6f4"; # Text
    secondary-hover-bg = "#45475a"; # Surface 1
    secondary-pressed-bg = "#585b70"; # Surface 2

    ghost-bg = "transparent";
    ghost-on = "#cdd6f4"; # Text
    ghost-hover-bg = "#45475a"; # Surface 1
    ghost-pressed-bg = "#585b70"; # Surface 2

    destructive-bg = "#f38ba8"; # Red
    destructive-on = "#1e1e2e"; # Base on accent
    destructive-hover-bg = "#eba0ac"; # Maroon
    destructive-pressed-bg = "#f38ba8bf"; # Red at 75%

    disabled-bg = "#31324480"; # Surface 0 at 50%
    disabled-on = "#6c7086"; # Overlay 0
  };

  # Status surfaces, for inline notices and badges
  status = {
    error = "#f38ba8";
    warn = "#f9e2af";
    success = "#a6e3a1";
    info = "#94e2d5";
    attention = "#f2cdcd";
    pending = "#f9e2af"; # Same lane as warn
    modified = "#eba0ac"; # Maroon, edited indicator
  };

  # Interaction layer treatments
  state = {
    hover = "#45475a"; # Surface 1
    pressed = "#585b70"; # Surface 2
    selected = "#9399b240"; # Overlay 2 at 25%
    focus-ring = "#b4befe"; # Lavender
    cursor = "#f5e0dc"; # Rosewater
  };

  # Floating layers
  overlay = {
    scrim = "#11111b99"; # Crust at 60%, modal dim
    tooltip-bg = "#9399b2"; # Overlay 2
    tooltip-on = "#1e1e2e"; # Base
    placeholder = "#7f849c"; # Overlay 1
  };

  # Canonical opacity stops. Compose by suffixing hex with the matching alpha
  opacity = {
    full = 1.0;
    de-emphasized = 0.75;
    disabled = 0.5;
    selection = 0.25;
    accent-tint = 0.10;
  };

  # Pre-computed alpha hex chunks, paired with the stops above
  alpha = {
    full = "ff";
    de-emphasized = "bf";
    scrim = "99"; # 60%
    disabled = "80";
    selection = "40";
    accent-tint = "1a";
  };
}
