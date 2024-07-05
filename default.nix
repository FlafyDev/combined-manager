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
      config = evalModules (configuration // { inherit inputs; });
    in
    configuration // { inherit config; };
in
rec {
  # TODO Also provide other NixOS stuff like options (also do that for mkFlake)
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
        let
          explicitOutputs = outputs inputs;

          allConfigurations = lib.mapAttrs (_: config: config.config) (
            (lib.mapAttrs (
              _: config:
              combinedManagerSystem {
                configuration = config // {
                  specialArgs = (config.specialArgs or { }) // {
                    configs = allConfigurations;
                  };
                };
                inherit inputs;
              }
            ) configurations)
            // explicitOutputs.nixosConfigurations or { }
          );
        in
        explicitOutputs
        // {
          nixosConfigurations = lib.mapAttrs (_: config: { config = config.config.os; }) allConfigurations;
        };
    };
}
