{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.claude;

  # Wrap seed script with the seed tree path baked in
  claudeSkillsSeed = pkgs.writeShellApplication {
    name = "claude-skills-seed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export CLAUDE_SEED=${./../../assets/claude}
      # shellcheck source=/dev/null
      source ${./scripts/claude-skills-seed.sh}
    '';
  };
in
{
  options.modules.claude = {
    enable = mkEnableOption "Claude Code baseline (CLAUDE.md + skills/)" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ claudeSkillsSeed ];

    # Re-seed ~/.claude each rebuild; only files in assets/claude/ are touched
    home.activation.seedClaudeSkills = hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${claudeSkillsSeed}/bin/claude-skills-seed
    '';
  };
}
