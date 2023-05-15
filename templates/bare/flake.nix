{
  description = "NixOS configuration";

  inputs = let
    combinedManager = import ./combined-manager;
  in
    combinedManager.mkInputs {
      root = ./.;
      initialInputs = {
        nixpkgs.url = "github:nixos/nixpkgs";
        home-manager = {
          url = "github:nix-community/home-manager";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
      modules = [];
    };

  outputs = inputs: let
    combinedManager = import ./combined-manager;
  in {
    nixosConfigurations = {
      default = combinedManager.mkNixosSystem {
        system = "x86_64-linux";
        inherit inputs;
        modules = [];
      };
    };
  };
}
