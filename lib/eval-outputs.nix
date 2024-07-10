args: inputs:
let
  lib = import ./lib args;
  combinedManagerToNixosConfig = import ./combined-manager-to-nixos-config.nix;
  evalModules = import ./eval-modules.nix;

  explicitOutputs = (args.outputs or (_: { })) (args // { self = outputs; });
  nixosConfigurations =
    inputs:
    lib.mapAttrs (_: combinedManagerToNixosConfig) (
      let
        configs = lib.mapAttrs (
          _: config:
          evalModules (
            {
              inherit lib;
	      system = args.system;
              specialArgs = {
                inherit inputs configs;
              };
              useHm = args.useHomeManager or true;
            }
            // config
          )
        ) args.configurations;
      in
      configs
    );

  outputs = explicitOutputs // {
    nixosConfigurations = nixosConfigurations inputs // explicitOutputs.nixosConfigurations or { };
  };
in
outputs
