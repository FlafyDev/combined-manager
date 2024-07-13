let
  combinedManager = import (
    builtins.fetchTarball {
      url = "https://github.com/flafydev/combined-manager/archive/225a5d918f8c600adc374e634aab02aed9e406ab.tar.gz";
      sha256 = "sha256:052q2q30nrxjci0s5ck81r563yz1zcd5abb7gb3qg1yamwpxxgra";
    }
  );
in
combinedManager.mkFlake {
  description = "NixOS configuration";

  lockFile = ./flake.lock;

  stateVersion = "24.11";

  initialInputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  configurations = { };
}
