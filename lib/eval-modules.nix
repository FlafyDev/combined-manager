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

            osModules = mkOption {
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
                    baseModules ++ [ { _module.args.baseModules = baseModules; } ] ++ osModules ++ config.osModules;
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
                  option:
                  if lib.isType "option" option then
                    # option // { __functor = self: name: lib.mapAttrs (_: getSubOptions) (self.type.getSubOptions [ ]); }
                    option
                    // {
                      __functor =
                        self: name:
                        lib.mapAttrs (_: getSubOptions)
                          (lib.evalModules {
                            modules = [
                              { _module.args.name = name; }
                            ] ++ self.type.nestedTypes.elemType.getSubModules; # TODO
                          }).options;
                    }
                  else
                    lib.mapAttrs (_: getSubOptions) option;
              in
              getSubOptions (options.os.type.getSubOptions [ ]);
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

          hmModules = mkOption {
            type = with types; listOf raw;
            default = [ ];
            description = "Home Manager modules.";
          };

          hm = osOptions.home-manager.users config.hmUsername;
          #mkOption {
          #type = types.deferredModule;
          #default = { };
          #description = "Home Manager configuration.";
          #};
        };

        config = {
          _module.args = {
            hmConfig = osConfig.home-manager.users.${config.hmUsername};
            hmOptions = osOptions.home-manager.users config.hmUsername;
          };

          osModules = [ inputs.home-manager.nixosModules.default ];

          os.home-manager = builtins.trace "test" {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs.inputs = inputs;
            sharedModules = hmModules ++ config.hmModules;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
