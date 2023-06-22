let
  combinedManager = import (builtins.fetchTarball {
    url = "https://github.com/flafydev/combined-manager/archive/72e48d8eb0580c1c81ade98bdba3d0bb30d9fcfd.tar.gz";
    sha256 = "sha256:1xns8yfy7hwdjqdvaj2kqrwykmy61jhdfs8rn2dqm6pq35bgf3ah";
  });
in {
  description = "NixOS configuration";

  inputs = combinedManager.evaluateInputs {
    lockFile = ./flake.lock;
    modules = [./configuration.nix];
    initialInputs = {
      nixpkgs.url = "github:nixos/nixpkgs";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs: {
    nixosConfigurations = {
      default = combinedManager.nixosSystem {
        system = "x86_64-linux";
        inherit inputs;
        modules = [./configuration.nix];
      };
    };
  };
}
