let
  evalModules = import ./eval-modules.nix;

  getLib =
    lockFile:
    let
      inherit (builtins.fromJSON (builtins.readFile lockFile)) nodes;
      nixpkgsLock = nodes.nixpkgs.locked;
    in
    import (
      if (builtins.pathExists lockFile && nodes ? nixpkgs) then
        # TODO Don't download it again, just use the flake input
        (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
          sha256 = nixpkgsLock.narHash;
        })
        + "/lib"
      else
        <nixpkgs/lib>
    );

  combinedManagerSystem =
    { inputs, configuration }:
    let
      configuration' = (builtins.removeAttrs configuration [ "inputOverrides" ]) // {
        inputs = inputs // ((configuration.inputOverrides or (_: { })) inputs);
      };
      inherit ((evalModules configuration').config) osModules;

      evaluated = evalModules (configuration' // { inherit osModules; });
    in
    {
      inherit (evaluated) config;
    };
in
rec {
  nixosSystem = args: { config = (combinedManagerSystem args).config.os; };

  mkFlake =
    {
      description,
      lockFile,
      initialInputs ? { },
      configurations,
      outputs ? (_: { }),
    }:
    let
      lib = getLib lockFile;

      evalConfigInputs =
        configuration:
        (evalModules (configuration // { inputs.nixpkgs.lib = lib; }))
        .options.inputs.definitionsWithLocations;

      inputsList = [
        {
          file = "flake.nix";
          value = initialInputs;
        }
      ] ++ lib.foldl (defs: config: defs ++ evalConfigInputs config) [ ] (lib.attrValues configurations);
      inputs = (import ./input-type.nix lib.types).merge [ "inputs" ] inputsList;
    in
    {
      inherit description inputs;

      outputs =
        inputs:
        (outputs inputs)
        // {
          nixosConfigurations =
            let
              allConfigurations = builtins.mapAttrs (_host: config: config.config) (
                (lib.mapAttrs (
                  _name: config:
                  combinedManagerSystem {
                    configuration = config // {
                      specialArgs = (config.specialArgs or { }) // {
                        configs = allConfigurations;
                      };
                    };
                    inherit inputs;
                  }
                ) configurations)
                // (outputs inputs).nixosConfigurations or { }
              );
            in
            (lib.mapAttrs (
              _name: config:
              nixosSystem {
                configuration = config // {
                  specialArgs = (config.specialArgs or { }) // {
                    configs = allConfigurations;
                  };
                };
                inherit inputs;
              }
            ) configurations)
            // (outputs inputs).nixosConfigurations or { };
        };
    };
}
