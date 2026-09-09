{ inputs }:

[
  # pkgs.unstable.<name> for the few packages that must outpace stable
  (final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (prev.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  })
]
