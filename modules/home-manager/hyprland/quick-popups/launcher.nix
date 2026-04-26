{ pkgs, inputs, ... }:

let
  fsel = inputs.fsel.packages.${pkgs.system}.default;
in
{
  modules.hyprland.popups.launcher = {
    type = "launcher";
    command = "${fsel}/bin/fsel";
    packages = [ fsel ];
  };
}
