{
  description = "NixOS configuration";

  inputs = let
    evaluatedInputs = let
      cmLock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.combined-manager.locked;
      combinedManager = import (builtins.fetchTarball {
        url = "https://github.com/${cmLock.owner}/${cmLock.repo}/archive/${cmLock.rev}.tar.gz";
        sha256 = cmLock.narHash;
      });
    in
      if (builtins.pathExists ./flake.lock)
      then
        combinedManager.evaluateInputs {
          lockFile = ./flake.lock;
          modules = [./configuration.nix];
        }
      else {};
  in
    evaluatedInputs
    // {
      nixpkgs.url = "github:nixos/nixpkgs";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      combined-manager.url = "github:flafydev/combined-manager";
    };

  outputs = {combined-manager, ...} @ inputs: {
    nixosConfigurations = {
      default = combined-manager.nixosSystem {
        system = "x86_64-linux";
        inherit inputs;
        modules = [./configuration.nix];
      };
    };
  };
}
