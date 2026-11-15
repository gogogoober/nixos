{
  config,
  lib,
  inputs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.claudeDesktop;
in
{
  imports = [ inputs.claude-desktop.nixosModules.default ];

  options.modules.claudeDesktop = {
    enable = mkEnableOption "the Claude desktop app";

    cowork = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Run Cowork's agent tasks in a QEMU virtual machine. The app probes
        hard-coded FHS paths for its UEFI firmware and virtiofsd with no env
        override, so this symlinks both into /usr, loads the vhost_vsock
        module, and puts the user in the kvm group.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.claude-desktop = {
      enable = true;
      cowork.enable = cfg.cowork;
      cowork.kvmUsers = [ config.modules.user.name ];
    };
  };
}
