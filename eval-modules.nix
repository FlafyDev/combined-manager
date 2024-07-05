{
  system ? builtins.currentSystem,
  inputs,
  prefix ? [ ],
  specialArgs ? { },
  useHomeManager ? true,
  modules,
  osModules ? [ ],
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs.lib)
    optional
    evalModules
    mkOption
    types
    ;
in
evalModules {
  inherit prefix;
  specialArgs = {
    inherit inputs;
    combinedManagerPath = ./.;
  } // specialArgs;
  modules =
    [
      (
        { config, ... }:
        {
          options = {
            # These inputs are used when generating the flake
            inputs = mkOption {
              type = import ./input-type.nix types;
              default = { };
              description = "Inputs";
            };

            osModules = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "Top level NixOS modules.";
            };

            os = mkOption {
              type = types.submoduleWith {
                specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                modules = import "${nixpkgs}/nixos/modules/module-list.nix" ++ config.osModules;
              };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config = {
            _module.args.osConfig = config.os;
            os.nixpkgs.system = system;
          };
        }
      )
    ]
    ++ optional useHomeManager (
      {
        options,
        config,
        osConfig,
        ...
      }:
      {
        options = {
          hmUsername = mkOption {
            type = types.str;
            default = "user";
            description = "Username used for Home Manager.";
          };

          hmModules = mkOption {
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
          _module.args.hmConfig = osConfig.home-manager.users.${config.hmUsername};

          osModules = [ inputs.home-manager.nixosModules.default ];

          os.home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs.inputs = inputs;
            sharedModules = config.hmModules;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
