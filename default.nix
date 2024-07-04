let
  evalModules = import ./eval-modules.nix;

  getLib =
    { lockFile }:
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
    configuration: lib:
    let
      configuration' = builtins.removeAttrs configuration [ "inputOverrides" ];
    in
    (evalModules (
      configuration'
      // {
        inputs = {
          nixpkgs = {
            inherit lib;
          };
        };
      }
    )).config.inputs;

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
      lockFile,
      description,
      initialInputs,
      configurations,
      outputs ? (_: { }),
    }:
    let
      lib = getLib { inherit lockFile; };

      evaluatedInputs = lib.foldl (
        allInputs: configInputs:
        # This foldAttrs is basically `allInputs // configInputs` but with an assertion.
        lib.foldlAttrs (
          allInputs: inputName: inputValue:
          assert
            (!(builtins.elem inputName (builtins.attrNames allInputs) && allInputs.${inputName} != inputValue))
            || throw "The input \"${inputName}\" appears more than once and equals to different values!\nFirst definition: ${builtins.toJSON inputValue}\nSecond definition: ${
              builtins.toJSON allInputs.${inputName}
            }";
          allInputs // { ${inputName} = inputValue; }
        ) allInputs configInputs
      ) { } (map (config: evaluateConfigInputs config lib) (builtins.attrValues configurations));
    in
    assert
      builtins.elem "nixpkgs" (builtins.attrNames initialInputs)
      || throw "nixpkgs input not found in initialInputs" { };
    assert
      (
        (builtins.any (config: config.useHomeManager or true) (builtins.attrValues configurations))
        && (builtins.elem "home-manager" (builtins.attrNames initialInputs))
      )
      || throw "home-manager input not found in initialInputs" { };
    {
      inherit description;
      inputs = evaluatedInputs // initialInputs;
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
