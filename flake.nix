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

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      systems = [ "x86_64-linux" ];
      makePkgs = system: import nixpkgs { inherit system; };
      makePkgsUnstable = system: import nixpkgs-unstable { inherit system; };
    in {
      # Generic Nix Flake outputs for the supported systems
      # packages.x86_64-linux = import ./packages { pkgs = makePkgs "x86_64-linux"; };

      devShells.x86_64-linux.default = let
        pkgs = makePkgs "x86_64-linux";
      in pkgs.mkShell {
        buildInputs = with pkgs; [ nixpkgs-fmt git ];
      };

      formatter.x86_64-linux = let pkgs = makePkgs "x86_64-linux"; in pkgs.nixpkgs-fmt;

      # NixOS configuration
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
        pkgs = makePkgs "x86_64-linux";
      };

      # Home Manager (optional export for activation)
      homeConfigurations = {
        # Example: a home-manager generation named "user"
        user = import home-manager {
          inherit (import ./home.nix) config; # if you use a home.nix; otherwise adjust
          pkgs = makePkgs "x86_64-linux";
          system = "x86_64-linux";
        } ;
      };
    };
}