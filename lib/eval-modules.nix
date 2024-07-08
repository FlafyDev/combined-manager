{
  lib,
  prefix ? [ ],
  specialArgs ? { },
  useHomeManager ? true,
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
            osOptions =
              let
                getSubOptions =
                  option:
		  option // lib.optionalAttrs (lib.isOption option) { __functor = 10; };
		  #lib.evalModules
		  #builtins.trace (option.type.getSubModules)
                  #(lib.mapAttrs (_: getSubOptions) (
                  #  if lib.isType "option" option then option.type.getSubOptions [ ] else option
                  #));
              in
              getSubOptions options.os;
          };
        }
      )
    ]
    ++ lib.optional useHomeManager (
      {
        inputs,
        options,
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

          hm = mkOption {
            # TODO Copy the hmModule type from https://github.com/nix-community/home-manager/blob/master/nixos/common.nix
            type = types.deferredModule;
            default = { };
            description = "Home Manager configuration.";
          };
        };

        config = {
          _module.args = {
            hmConfig = osConfig.home-manager.users.${config.hmUsername};
            hmOptions = options.hm;
          };

          osModules = [ inputs.home-manager.nixosModules.default ];

          os.home-manager = {
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
