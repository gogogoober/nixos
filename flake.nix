# flake.nix — import nixpkgs with config and use that pkgs in nixosSystem
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";

      makePkgs = systemArg: import nixpkgs {
        inherit systemArg;
        config = { allowUnfree = true; };
      };

      makePkgsUnstable = systemArg: import nixpkgs-unstable {
        inherit systemArg;
        config = { allowUnfree = true; };
      };

      pkgs = makePkgs system;
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
        pkgs = pkgs;
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ nixpkgs-fmt git ];
      };
    };
}
