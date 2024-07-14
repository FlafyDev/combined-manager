{
  configurations,
  outputs ? (_: {}),
  ...
}: inputs:
with inputs.nixpkgs.lib; let
  inherit (inputs.nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  evalModules = import ./eval-modules.nix;

  evalModule = configs: config: let
    configuration' = (builtins.removeAttrs config ["inputOverrides"]) // {inputs = inputs // ((config.inputOverrides or (_: {})) inputs);};

    configModules = modifiedLib.collectModules null "" config.modules {
      inherit lib;
      inherit (configuration') inputs;
      options = null;
      config = null;
    };

    findImports = name: alias: x:
      if x ? ${name} || x ? ${alias}
      then x.${name} or [] ++ x.${alias} or []
      else if x ? content
      then findImports name alias x.content
      else if x ? contents
      then lib.foldl (imports: x: imports ++ findImports name alias x) [] x.contents
      else [];

    configOsModules = lib.foldl (defs: module: defs ++ findImports "osImports" "osModules" module.config) [] configModules;
    configHmModules = lib.foldl (defs: module: defs ++ findImports "hmImports" "hmModules" module.config) [] configModules;

    module = evalModules (configuration'
      // {
        osModules = configOsModules ++ lib.optional config.useHomeManager or true inputs.home-manager.nixosModules.default;
        hmModules = configHmModules;
      });
  in
    module;

  explicitOutputs = outputs inputs;
  nixosConfigurations =
    mapAttrs
    (_: config:
      config
      // {
        class = "nixos";
        options = config.options.os;
        config = config.config.os;
      })
    (let configs = mapAttrs (_: evalModule configs) configurations; in configs);

  result =
    explicitOutputs
    // {
      nixosConfigurations = nixosConfigurations // explicitOutputs.nixosConfigurations or {};
    };
in
  result
