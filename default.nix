let
  evalModules = import ./eval-modules.nix;

  getLib = {lockFile}: let
    inherit ((builtins.fromJSON (builtins.readFile lockFile))) nodes;
    nixpkgsLock = nodes.nixpkgs.locked;
    lib = import ((builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
        sha256 = nixpkgsLock.narHash;
      })
      + "/lib");
    libFixed = import ((builtins.fetchTarball {
        url = "https://github.com/nix-community/nixpkgs.lib/archive/4833b4eb30dfe3abad5a21775bc5460322c8d337.tar.gz";
        sha256 = "sha256:1ppr46pf1glp7irxcr8w4fzfffgl34cnsb0dyy8mm8khw1bzbb5z";
      })
      + "/lib");
  in
    if (builtins.pathExists lockFile && nodes ? nixpkgs)
    then lib
    else libFixed;
  # else builtins.trace "[1;31mInputs need to be evaluated again.[0m" null;

  combinedManagerSystem = {
    inputs,
    configuration,
  }: let
    configuration' = (builtins.removeAttrs configuration ["inputOverrides"]) // {inputs = inputs // ((configuration.inputOverrides or (_: {})) inputs);};
    inherit ((evalModules configuration').config) osModules;

    evaluated = evalModules (configuration'
      // {
        inherit osModules;
      });
  in {inherit (evaluated) config;};

  nixosSystem = args: {config = (combinedManagerSystem args).config.os;};

  mkFlake = {
    lockFile,
    description,
    initialInputs ? {},
    configurations,
    outputs ? (_: {}),
  }: let
    lib = getLib {inherit lockFile;};
  in {
    inherit description;
    inputs = import ./eval-inputs.nix {inherit lib initialInputs configurations;};
    outputs = inputs:
      (outputs inputs)
      // {
        nixosConfigurations = let
          allConfigurations = builtins.mapAttrs (_host: config: config.config) (
            (lib.mapAttrs (_name: config:
              combinedManagerSystem {
                configuration = config // {specialArgs = (config.specialArgs or {}) // {configs = allConfigurations;};};
                inherit inputs;
              })
            configurations)
            // (outputs inputs).nixosConfigurations or {}
          );
        in
          (lib.mapAttrs (_name: config:
            nixosSystem {
              configuration = config // {specialArgs = (config.specialArgs or {}) // {configs = allConfigurations;};};
              inherit inputs;
            })
          configurations)
          // (outputs inputs).nixosConfigurations or {};
      };
  };
in {inherit mkFlake nixosSystem;}
