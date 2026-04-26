# Reusable design tokens. Import this directory anywhere and read
# .colors, .fonts, or .structure. Not yet wired into any consumer
{
  colors = import ./colors.nix;
  fonts = import ./fonts.nix;
  structure = import ./structure.nix;
}
