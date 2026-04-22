{
  description = "Hugo's NixOS Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }:
    let
      system = "x86_64-linux";

      makePkgs = systemArg: import nixpkgs {
        system = systemArg;
        config = { allowUnfree = true; };
      };

      makePkgsUnstable = systemArg: import nixpkgs-unstable {
        system = systemArg;
        config = { allowUnfree = true; };
      };

      pkgs = makePkgs system;
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [ nixpkgs-fmt git ];
      };

      formatter.${system} = pkgs.nixpkgs-fmt;

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
        pkgs = pkgs;
      };
    };
}
