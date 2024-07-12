args: inputs:
let
  inherit (inputs.nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  combinedManagerToNixosConfig = import ./combined-manager-to-nixos-config.nix;
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

      # TODO Good error messages?
      configOsModules = lib.foldl (
        modules: module: modules ++ findImports "osImports" module.config
      ) [ ] configModules;
      configHmModules = lib.foldl (
        modules: module: modules ++ findImports "hmImports" module.config
      ) [ ] configModules;

      useHm = args.useHomeManager or true;

      module = evalModules (
        config
        // {
          inherit (args) system stateVersion; # TODO
          specialArgs = {
            inherit inputs useHm configs;
          };
          osModules =
            config.osModules or [ ]
            ++ configOsModules
            ++ lib.optional useHm inputs.home-manager.nixosModules.default;
          hmModules = config.hmModules or [ ] ++ configHmModules;
        }
      );

      showWarnings =
        module:
        lib.foldl (
          module: warning: builtins.trace "[1;31mwarning: ${warning}[0m" module
        ) module module.config.warnings;

      showErrors =
        module:
        let
          failedAssertions = lib.lists.map (x: x.message) (
            lib.filter (x: !x.assertion) module.config.assertions
          ); # TODO Import lib gloally
        in
        if failedAssertions == [ ] then
          module
        else
          throw ''

            Failed assertions:
            ${lib.concatStringsSep "\n" (lib.map (x: "- ${x}") failedAssertions)}'';
    in
    showErrors (showWarnings module);

  explicitOutputs = (args.outputs or (_: { })) (args // { self = outputs; });
  nixosConfigurations =
    inputs:
    lib.mapAttrs (_: combinedManagerToNixosConfig) (
      let
        configs = lib.mapAttrs (_: evalModule configs) args.configurations;
      in
      configs
    );

  outputs = explicitOutputs // {
    nixosConfigurations = nixosConfigurations inputs // explicitOutputs.nixosConfigurations or { };
  };
in
outputs
