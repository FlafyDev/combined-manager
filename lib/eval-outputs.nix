{
  stateVersion,
  useHomeManager ? true,
  configurations,
  outputs ? (_: { }),
  ...
}@args:
inputs:
with inputs.nixpkgs.lib;
let
  inherit (inputs.nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  evalModules = import ./eval-modules.nix;

  evalModule =
    configs: config:
    let
      configModules = modifiedLib.collectModules null "" config.modules {
        inherit lib inputs;
        options = null;
        config = null;
      };

      findImports =
        name: x:
        if x ? ${name} then
          x.${name}
        else if x ? content then
          findImports name x.content
        else
          [ ];

      configOsModules = foldl (
        modules: module: modules ++ findImports "osImports" module.config
      ) [ ] configModules;
      configHmModules = foldl (
        modules: module: modules ++ findImports "hmImports" module.config
      ) [ ] configModules;

      useHm = config.useHm or useHomeManager;

      module = evalModules {
        inherit stateVersion;
        prefix = config.prefix or [ ];
        specialArgs = {
          inherit inputs useHm configs;
        };
        modules = config.modules;
        osModules =
          config.osModules or [ ]
          ++ configOsModules
          ++ optional useHm inputs.home-manager.nixosModules.default;
        hmModules = config.hmModules or [ ] ++ configHmModules;
      };

      showWarnings =
        module:
        foldl (
          module: warning: builtins.trace "[1;31mwarning: ${warning}[0m" module
        ) module module.config.warnings;

      showErrors =
        module:
        let
          failedAssertions = lists.map (x: x.message) (filter (x: !x.assertion) module.config.assertions);
        in
        if failedAssertions == [ ] then
          module
        else
          throw ''

            Failed assertions:
            ${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}'';
    in
    showErrors (showWarnings module);

  explicitOutputs = outputs (args // { self = result; });
  nixosConfigurations =
    inputs:
    mapAttrs
      (
        _: config:
        config
        // {
          class = "nixos";
          options = config.options.os;
          config = config.config.os;
        }
      )
      (
        let
          configs = mapAttrs (_: evalModule configs) configurations;
        in
        configs
      );

  result = explicitOutputs // {
    nixosConfigurations = nixosConfigurations inputs // explicitOutputs.nixosConfigurations or { };
  };
in
result
