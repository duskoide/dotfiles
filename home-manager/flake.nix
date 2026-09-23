{
  description = "Home Manager configuration for pn";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    superfile = {
      url = "github:yorukot/superfile";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Provides Vicinae's Home Manager module; home.nix selects the cached nixpkgs package.
    vicinae.url = "github:vicinaehq/vicinae";
  };

  outputs = { nixpkgs, home-manager, superfile, vicinae, ... }:
    let
      system = "x86_64-linux";
      username = "pn";
    in {
      # Standalone home-manager for non-NixOS machines (Fedora laptop, etc.)
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit superfile;
        };
        modules = [
          vicinae.homeManagerModules.default
          ./home.nix
          ./shell.nix
        ];
      };

    };
}
