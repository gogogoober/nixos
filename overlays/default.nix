{ inputs }:

let
  # Both speech paths on these hosts are English only
  espeakLanguage = "en";
in
[
  # pkgs.unstable.<name> for the few packages that must outpace stable
  (final: prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (prev.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  })

  # espeak ships 645 MiB of MBROLA voices and 117 language dictionaries
  (final: prev: {
    espeak-ng = (prev.espeak-ng.override { mbrolaSupport = false; }).overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        find $out/share/espeak-ng-data -maxdepth 1 -name '*_dict' ! -name '${espeakLanguage}_dict' -delete
      '';
    });
  })
]
