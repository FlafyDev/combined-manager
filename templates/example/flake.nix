let
  combinedManager = import (builtins.fetchTarball {
    url = "https://github.com/flafydev/combined-manager/archive/REV.tar.gz";
    sha256 = "";
  });
in
  combinedManager.mkFlake {
    lockFile = ./flake.lock;

    initialInputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };

    configurations = {
      default = {
        system = "x86_64-linux";
        modules = [./configuration.nix];
      };
    };
  }
