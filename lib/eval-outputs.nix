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
    modules = globalModules ++ config.modules or [];

    configModules = modifiedLib.collectModules null "" modules {
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
  in
    evalModules {
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
      inherit modules;
      osModules = globalOsModules ++ config.osModules or [] ++ configOsModules ++ optional useHm inputs.home-manager.nixosModules.default;
      hmModules = globalHmModules ++ config.hmModules or [] ++ configHmModules;
    };

  explicitOutputs = outputs rawInputs;

  combinedManagerConfigurations = let configs = mapAttrs (_: config: (evalModule configs config).combinedManager) configurations; in configs;

  nixosConfigurations = let
    withExtraAttrs = config:
      config
      // {
        extraArgs = {};
        inherit (config._module.args) pkgs;
        inherit lib;
        extendModules = args: withExtraAttrs (config.extendModules args);
      };
    configs = mapAttrs (_: config: withExtraAttrs (evalModule configs config).nixos) configurations;
  in
    configs;
in
  explicitOutputs
  // {
    inherit combinedManagerConfigurations;
    nixosConfigurations = nixosConfigurations // explicitOutputs.nixosConfigurations or {};
  }
