{
  defaultSystem ? null,
  useHomeManager ? true,
  globalSpecialArgs ? {},
  globalModules ? [],
  globalOsModules ? [],
  globalHmModules ? [],
  configurations,
  outputs ? (_: {}),
  ...
}: rawInputs:
with rawInputs.nixpkgs.lib; let
  inherit (rawInputs.nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  evalModules = import ./eval-modules.nix;

  evalModule = configs: config: let
    inputs = rawInputs // config.inputOverrides or (_: {}) rawInputs;

    configModules = modifiedLib.collectModules null "" config.modules {
      inherit lib inputs;
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

    useHm = config.useHomeManager or useHomeManager;
    module = evalModules {
      system = config.system or defaultSystem;
      prefix = config.prefix or [];
      specialArgs =
        {
          inherit inputs useHm configs;
          combinedManager = import ../.;
          combinedManagerPath = ../.;
        }
        // globalSpecialArgs
        // config.specialArgs or {};
      modules = globalModules ++ config.modules or [];
      osModules = globalOsModules ++ config.osModules or [] ++ configOsModules ++ optional useHm inputs.home-manager.nixosModules.default;
      hmModules = globalHmModules ++ config.hmModules or [] ++ configHmModules;
    };

    showWarnings = module:
      foldl (
        module: warning: builtins.trace "[1;31mwarning: ${warning}[0m" module
      )
      module
      module.config.warnings;

    showErrors = module: let
      failedAssertions = lists.map (x: x.message) (filter (x: !x.assertion) module.config.assertions);
    in
      if failedAssertions == []
      then module
      else
        throw ''

          Failed assertions:
          ${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}'';
  in
    showErrors (showWarnings module);

  explicitOutputs = outputs rawInputs;
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
in
  explicitOutputs // {nixosConfigurations = nixosConfigurations // explicitOutputs.nixosConfigurations or {};}
