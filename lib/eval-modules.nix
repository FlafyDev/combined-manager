{
  lib,
  system,
  stateVersion,
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

  osBaseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  osExtraModules =
    let
      e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
    in
    lib.optional (e != "") (import e);
  allOsModules = osBaseModules ++ osExtraModules ++ osModules;
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
              type = types.submoduleWith {
                class = "nixos";
                specialArgs = {
                  inherit useHm;
                  modulesPath = "${nixpkgs}/nixos/modules";
                } // specialArgs;
                modules = allOsModules ++ [
                  (
                    { config, ... }:
                    {
                      _module.args = {
                        baseModules = osBaseModules;
                        extraModules = osExtraModules;
                        modules = osModules;
                      };
                      system.stateVersion = stateVersion;
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

          config = {
            _module.args = {
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
                              #++ (builtins.trace (builtins.attrNames self.value) [ self.loc ]);
                            }).options;
                      }
                    else if option.type.name == "submodule" then
                      option
                      // {
                        __functor =
                          self: name:
                          lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
                            (lib.evalModules { modules = self.getSubModules ++ [ self.loc ]; }).options;
                      }
                    else
                      option;
                in
                lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
                  (lib.evalModules {
                    modules = [
                      {
                        options =
                          let
                            allOptions = options.os.type.getSubOptions [ ];
                          in
                          lib.filterAttrs (name: value: name != "_module") allOptions;
                      }
                    ];
                  }).options;
            };

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

            # TODO No duplication
            #hmOptions =
            #  let
            #    getSubOptions =
            #      _: option:
            #      # TODO Support listOf, functionTo, and standalone submodules
            #      if
            #        (option.type.name == "attrsOf" || option.type.name == "lazyAttrsOf")
            #        && option.type.nestedTypes.elemType.name == "submodule"
            #      then
            #        option
            #        // {
            #          __functor =
            #            self: name:
            #            # TODO Use specialArgs instead of _module.args.name?
            #            lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
            #              (lib.evalModules {
            #                modules = [ { _module.args.name = name; } ] ++ self.type.nestedTypes.elemType.getSubModules;
            #              }).options;
            #        }
            #      else
            #        option;
            #  in
            #  lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions
            #    (lib.evalModules { modules = osOptions.home-manager.users.type.getSubModules ++ [ hmConfig ]; })
            #    .options;
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
