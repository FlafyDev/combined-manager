{
  lib,
  prefix ? [ ],
  specialArgs ? { },
  useHm ? true,
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}:
let
  inherit (specialArgs.inputs) nixpkgs;
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
                in
                types.submoduleWith {
                  class = "nixos";
                  specialArgs = {
                    modulesPath = "${nixpkgs}/nixos/modules";
                  } // specialArgs;
                  modules =
                    baseModules ++ [ { _module.args.baseModules = baseModules; } ] ++ osModules ++ config.osImports;
                };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            combinedManagerPath = ./.;
            osConfig = config.os;
            # TODO Is documentation for these options generated correctly?
            osOptions =
              let
                getSubOptions =
                  _: option:
                  # TODO Support listOf, functionTo, and standalone submodules
                  builtins.trace (option.type.name) (
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
                      option
                  );
              in
              # TODO Handle like getSubOptions handles a standalone submodule
              lib.mapAttrsRecursiveCond (x: !lib.isOption x) getSubOptions (options.os.type.getSubOptions [ ]);
          };
        }
      )
    ]
    ++ lib.optional useHm (
      {
        inputs,
        options,
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

          hm =
            #  let
            #    result = (osOptions.home-manager.users config.hmUsername);
            #  in
            #  builtins.trace (builtins.attrNames result.description) result;
            mkOption {
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

          osImports = [ inputs.home-manager.nixosModules.default ];

          os.home-manager = builtins.trace "test" {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs.inputs = inputs;
            sharedModules = hmModules ++ config.hmImports;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
