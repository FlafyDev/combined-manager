args:
let
  lib = import ./lib.nix args.lockFile;
  combinedManagerToNixosConfig = import ./combined-manager-to-nixos-config.nix;
  evalModules = import ./eval-modules.nix;

  explicitOutputs = (args.outputs or (_: { })) args;
  nixosConfigurations =
    inputs:
    lib.mapAttrs (_: combinedManagerToNixosConfig) (
      let
        configs = lib.mapAttrs (
          _: config:
          evalModules (
            config
            // {
	      inherit lib;
              specialArgs = {
                inherit inputs configs;
              };
            }
          )
        ) args.configurations;
      in
      configs
    );
in
inputs:
explicitOutputs
// {
  nixosConfigurations = nixosConfigurations inputs // explicitOutputs.nixosConfigurations or { };
}
