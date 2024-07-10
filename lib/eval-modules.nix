{
  lib,
  system,
  prefix ? [ ],
  specialArgs ? { },
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}:
let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (specialArgs) useHm;
  inherit (nixpkgs.lib) mkOption types;
in
lib.evalModules {
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
              type =
                let
                  baseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
                  extraModules =
                    let
                      e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
                    in
                    lib.optional (e != "") (import e);
                in
                types.submoduleWith {
                  class = "nixos";
                  specialArgs = {
                    inherit useHm;
                    modulesPath = "${nixpkgs}/nixos/modules";
                  } // specialArgs;
                  modules =
                    baseModules
                    ++ [
                      (
                        { config, ... }:
                        {
                          _module.args = {
                            inherit baseModules extraModules;
                            modules = osModules;
                          };
                          nixpkgs = {
                            inherit system;
                            pkgs = import nixpkgs {
                              inherit (config.nixpkgs)
                                config
                                overlays
                                localSystem
                                crossSystem
                                ;
                            };
                          };
                          home-manager.sharedModules = hmModules;
                        }
                      )
                    ]
                    ++ osModules;
                };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            combinedManagerPath = ./.;
            pkgs = config.os.nixpkgs.pkgs;
            osConfig = config.os;
            # TODO Is documentation for these options generated correctly?
            osOptions =
              let
                getSubOptions =
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
                        # TODO Use specialArgs instead of _module.args.name?
                        lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
                          (lib.evalModules {
                            modules = [ { _module.args.name = name; } ] ++ self.type.nestedTypes.elemType.getSubModules;
                          }).options;
                    }
                  else
                    option;
              in
              lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions (options.os.type.getSubOptions [ ]);
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
          _module.args = rec {
            hmConfig = osConfig.home-manager.users.${config.hmUsername};

            # TODO No duplication
            hmOptions =
              let
                getSubOptions =
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
                        # TODO Use specialArgs instead of _module.args.name?
                        lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
                          (lib.evalModules {
                            modules = [ { _module.args.name = name; } ] ++ self.type.nestedTypes.elemType.getSubModules;
                          }).options;
                    }
                  else
                    option;
              in
              lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
                (lib.evalModules { modules = osOptions.home-manager.users.type.getSubModules ++ [ hmConfig ]; })
                .options;
          };

          os.home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs.inputs = inputs;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
