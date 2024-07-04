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

  evaluateConfigInputs =
    configuration: lib: (evalModules (configuration // { inputs.nixpkgs.lib = lib; })).config.inputs;

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

      evaluatedInputsList = lib.map (config: evaluateConfigInputs config lib) (
        lib.attrValues configurations
      );
      inputsList = [ initialInputs ] ++ evaluatedInputsList;
      # TODO Provide the file locations for the error message
      inputsModules = lib.map (inputs: { inherit inputs; }) inputsList;
      inputs =
        (evalModules {
          inputs.nixpkgs.lib = lib;
          modules = inputsModules;
        }).config.inputs;
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
