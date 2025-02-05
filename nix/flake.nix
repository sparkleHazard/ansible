{
  description = "Home Manager configuration for my system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    home-manager.url = "github:nix-community/home-manager";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      homeConfiguration = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          { config, pkgs, ... }: {
              home.username = "yourusername";
              home.homeDirectory = "/home/yourusername";
              programs.zsh.enable = true;
              # add further Home Manager settings here
          }
        ];
      };
    in {
      homeConfigurations.yourusername = homeConfiguration;
    };
}
