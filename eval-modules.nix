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
            inputs = mkOption {
              # TODO A proper input type
              type = with types; attrsOf (uniq anything);
              default = { };
              description = "Inputs";
            };

            os = mkOption {
              type = types.submoduleWith {
                specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                modules =
                  import "${nixpkgs}/nixos/modules/module-list.nix" ++ osModules ++ [ { nixpkgs.system = system; } ];
              };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };

            osModules = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "Top level NixOS modules.";
            };
          };

          config._module.args.osConfig = config.os;
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
          hm = mkOption {
            type = types.deferredModule;
            default = { };
            description = "Home Manager configuration.";
          };

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
