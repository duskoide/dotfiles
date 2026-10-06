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
      mkHome = linkDotfiles: home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = {
          inherit superfile linkDotfiles;
        };
        modules = [
          vicinae.homeManagerModules.default
          ./home.nix
          ./shell.nix
        ];
      };
    in {
      # Same as `pn` but without symlinking repo dotfiles into ~ (see nolinks.sh)
      homeConfigurations."${username}-nolinks" = mkHome false;

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
