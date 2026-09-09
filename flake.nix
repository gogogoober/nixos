{
  description = "Hugo's NixOS Config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fsel = {
      url = "github:Mjoyufull/fsel/3.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      home-manager,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem =
        { pkgs, ... }:
        {
          packages = import ./packages { inherit pkgs; };

          formatter = pkgs.nixfmt-tree;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              nil
              git
              just
            ];
          };
        };

      flake = {
        nixosConfigurations = {
          dell-old = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/dell-old
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "bak";
                home-manager.extraSpecialArgs = { inherit inputs; };
              }
            ];
          };

          surface-go-3 = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/surface-go-3
              home-manager.nixosModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "bak";
                home-manager.extraSpecialArgs = { inherit inputs; };
              }
            ];
          };
        };
      };
    };
}
