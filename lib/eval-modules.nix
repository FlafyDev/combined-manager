{
  system,
  prefix ? [],
  specialArgs ? {},
  modules ? [],
  osModules ? [],
  hmModules ? [],
}:
with specialArgs.inputs.nixpkgs.lib; let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (specialArgs) useHm;
  inherit mkOption types;

  osBaseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  osExtraModules = let
    e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
  in
    optional (e != "") (import e);
  allOsModules = osBaseModules ++ osExtraModules ++ osModules;

  osSpecialArgs =
    {
      modulesPath = "${nixpkgs}/nixos/modules";
      baseModules = osBaseModules;
      extraModules = osExtraModules;
      modules = osModules;
    }
    // specialArgs;

  evalOsModules = options:
    evalModules {
      class = "nixos";
      specialArgs = osSpecialArgs;
      modules =
        options.os.type.getSubModules
        ++ map ({
          value,
          file,
        }: {
          _file = file;
          imports = [value];
        })
        options.os.definitionsWithLocations;
    };

  evaluatedModules = modifiedLib.evalModules {
    inherit prefix specialArgs;
    class = "combinedManager";
    modules =
      [
        (
          {
            options,
            config,
            ...
          }: {
            options = {
              inputs = mkOption {
                type = with types; attrsOf raw;
                default = {};
                description = "Inputs";
              };

              hmUsername = mkOption {
                type = types.str;
                description = "Username used for Home Manager.";
              };

              osImports = mkOption {
                type = with types; listOf raw;
                default = [];
                description = "NixOS modules.";
              };

              hmImports = mkOption {
                type = with types; listOf raw;
                default = [];
                description = "Home Manager modules.";
              };

              os = mkOption {
                type = types.submoduleWith {
                  class = "nixos";
                  specialArgs = osSpecialArgs;
                  modules = allOsModules;
                };
                default = {};
                visible = "shallow";
                description = "NixOS configuration.";
              };

              hm = mkOption {
                type = types.deferredModule;
                default = {};
                description = "Home Manager configuration.";
              };
            };

            config = {
              _module.args = {
                pkgs =
                  (evalModules {
                    modules = [
                      "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
                      {nixpkgs = builtins.removeAttrs config.os.nixpkgs ["pkgs" "flake"];}
                    ];
                  })
                  ._module
                  .args
                  .pkgs;

                osOptions = let
                  enhanceOption = _: option:
                  # TODO Support listOf, functionTo, and standalone submodules
                    if
                      (option.type.name == "attrsOf" || option.type.name == "lazyAttrsOf")
                      && option.type.nestedTypes.elemType.name == "submodule"
                    then
                      option
                      // {
                        __functor = self: name:
                          mapAttrsRecursiveCond (x: !isOption x) enhanceOption
                          (evalModules {modules = [{_module.args.name = name;}] ++ self.type.getSubModules;}).options;
                      }
                    else option;
                in
                  mapAttrsRecursiveCond (x: !isOption x) enhanceOption (evalOsModules options).options;

                osConfig = config.os;
              };

              os = {
                system.nixos.versionSuffix = ".${lib.substring 0 8 (nixpkgs.lastModifiedDate or nixpkgs.lastModified or "19700101")}.${nixpkgs.shortRev or "dirty"}";
                system.nixos.revision = lib.mkIf (nixpkgs ? rev) nixpkgs.rev;
              };
            };
          }
        )
        "${nixpkgs}/nixos/modules/misc/assertions.nix"
        (doRename {
          from = ["osModules"];
          to = ["osImports"];
          visible = true;
          warn = false;
          use = x: x;
        })
      ]
      ++ optionals useHm [
        (
          {
            osOptions,
            config,
            osConfig,
            ...
          }: {
            config = {
              _module.args = {
                hmOptions = osOptions.home-manager.users config.hmUsername;
                hmConfig = osConfig.home-manager.users.${config.hmUsername};
              };

              os.home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = specialArgs;
                sharedModules = hmModules;
                users.${config.hmUsername} = config.hm;
              };
            };
          }
        )
        (doRename {
          from = ["hmModules"];
          to = ["hmImports"];
          visible = true;
          warn = false;
          use = x: x;
        })
      ]
      ++ modules;
  };

  showWarnings = module: foldl (module: warning: builtins.trace "[1;31mwarning: ${warning}[0m" module) module module.config.warnings;

  showErrors = module: let
    failedAssertions = lists.map (x: x.message) (filter (x: !x.assertion) module.config.assertions);
  in
    if failedAssertions == []
    then module
    else
      throw ''

        Failed assertions:
        ${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}'';
in rec {
  combinedManager = showErrors (showWarnings evaluatedModules);
  nixos = evalOsModules combinedManager.options;
}
