{
  system, # TODO Remove the first two
  stateVersion,
  prefix ? [ ],
  specialArgs ? { },
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}@args: # TODO Remove
let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (specialArgs) useHm;
  inherit (lib) mkOption types;

  osBaseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  osExtraModules =
    let
      e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
    in
    lib.optional (e != "") (import e);
  allOsModules = osBaseModules ++ osExtraModules ++ osModules;
in
modifiedLib.evalModules {
  inherit prefix specialArgs;
  class = "combinedManager";
  modules =
    [
      (
        { options, config, ... }:
        {
          options = {
            inputs = mkOption {
              type = with types; attrsOf raw;
              default = { };
              description = "Inputs";
            };

            osImports = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "NixOS modules.";
            };

            os = mkOption {
              type = types.submoduleWith {
                class = "nixos";
                specialArgs = {
                  inherit useHm; # TODO Why is this provided to os, but not to combinedManager?
                  modulesPath = "${nixpkgs}/nixos/modules";
                } // specialArgs;
                modules = allOsModules ++ [
                  (
                    { config, ... }:
                    {
                      _module.args = {
                        baseModules = osBaseModules;
                        extraModules = osExtraModules;
                        modules = finalOsModules;
                      };
                      system.stateVersion = stateVersion;
                    }
                    // lib.optionalAttrs useHm {
                      home-manager.sharedModules = hmModules ++ [ { home.stateVersion = stateVersion; } ];
                    }
                  )
                ];
              };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            combinedManagerPath = ./.;

            pkgs =
              (lib.evalModules {
                modules = [
                  "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
                  {
                    nixpkgs = builtins.removeAttrs config.os.nixpkgs [
                      "pkgs"
                      "flake"
                    ];
                  }
                ];
              })._module.args.pkgs;

            osConfig = config.os;

            osOptions =
              let
                enhanceOption =
                  _: option:
                  # TODO Support listOf, functionTo, and standalone submodules
                  if
                    (option.type.name == "attrsOf" || option.type.name == "lazyAttrsOf")
                    && option.type.nestedTypes.elemType.name == "submodule"
                  then
                    option
                    // {
                      __functor =
                        self: name:
                        lib.mapAttrsRecursiveCond (x: !lib.isOption x) enhanceOption
                          (lib.evalModules { modules = [ { _module.args.name = name; } ] ++ self.type.getSubModules; })
                          .options;
                    }
                  else
                    option;
              in
              lib.mapAttrsRecursiveCond (x: !lib.isOption x) enhanceOption
                (lib.evalModules {
                  modules = allOsModules ++ [
                    (
                      let
                        osOptions = options.os.type.getSubOptions [ ];
                        filteredOsOptions = (lib.removeAttrs osOptions [ "_module" ]) // {
                          nixpkgs = lib.removeAttrs osOptions.nixpkgs [ "pkgs" ];
                        };
                        filteredOptions = lib.filterAttrsRecursive (
                          name: x: !lib.isOption x || !lib.hasPrefix "Alias of" x.description or ""
                        ) filteredOsOptions;
                      in
                      lib.mapAttrsRecursiveCond (x: !lib.isOption x) (
                        path: _: lib.getAttrFromPath path config.os
                      ) filteredOptions
                    )
                  ];
                }).options;
          };
        }
      )
      "${nixpkgs}/nixos/modules/misc/assertions.nix"
    ]
    ++ lib.optional useHm (
      {
        inputs,
        osOptions,
        config,
        osConfig,
        ...
      }:
      {
        options = {
          hmUsername = mkOption {
            type = types.str;
            description = "Username used for Home Manager.";
          };

          hmImports = mkOption {
            type = with types; listOf raw;
            default = [ ];
            description = "Home Manager modules.";
          };

          hm = mkOption {
            type = types.deferredModule;
            default = { };
            description = "Home Manager configuration.";
          };
        };

        config = {
          _module.args = {
            hmConfig = osConfig.home-manager.users.${config.hmUsername};
            hmOptions = osOptions.home-manager.users config.hmUsername;
          };

          os.home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = specialArgs;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
