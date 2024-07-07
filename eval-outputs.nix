args:
let
  lib = (import ./misc.nix).lib args.lockFile;
  inherit (import ./misc.nix) combinedManagerToNixosConfig;
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
