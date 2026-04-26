# Typography tokens, sourced from docs/design-system/structure.md
# Sizes and weights are raw numbers, line heights are unitless ratios
{
  # Three family slots, max. Concrete fonts get pinned per app
  family = {
    ui = "Inter, system-ui, sans-serif"; # UI sans
    content = "Inter, system-ui, sans-serif"; # Content sans or serif
    mono = "JetBrainsMono Nerd Font, ui-monospace, monospace"; # Code, terminal
  };

  size = {
    xs = 12; # Caption
    sm = 13; # Code
    base = 14; # Body
    md = 16; # H3, body large
    lg = 20; # H2
    xl = 24; # H1
    display = 32; # Display
  };

  weight = {
    regular = 400;
    medium = 500;
    semibold = 600; # Headings default
    bold = 700;
  };

  line-height = {
    tight = 1.2; # Display
    snug = 1.25; # H1
    normal = 1.3; # H2
    comfortable = 1.4; # H3, caption
    relaxed = 1.5; # Body, code
  };

  # Letter spacing, sparse use only
  tracking = {
    tight = "-0.01em";
    normal = "0em";
    loose = "0.02em";
    caps = "0.04em"; # Small caps and labels
  };

  # Composite role tokens, prefer these at call sites
  role = {
    display = {
      size = 32;
      weight = 600;
      line-height = 1.2;
    };
    h1 = {
      size = 24;
      weight = 600;
      line-height = 1.25;
    };
    h2 = {
      size = 20;
      weight = 600;
      line-height = 1.3;
    };
    h3 = {
      size = 16;
      weight = 600;
      line-height = 1.4;
    };
    body = {
      size = 14;
      weight = 400;
      line-height = 1.5;
    };
    body-large = {
      size = 16;
      weight = 400;
      line-height = 1.5;
    };
    caption = {
      size = 12;
      weight = 400;
      line-height = 1.4;
    };
    code = {
      size = 13;
      weight = 400;
      line-height = 1.5;
    };
    label = {
      size = 12;
      weight = 500;
      line-height = 1.4;
    }; # Form labels
  };

  # Reading constraints
  measure = {
    body-max-chars = 75; # Cap body line length
  };
}
