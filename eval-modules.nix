{
  prefix ? [ ],
  specialArgs ? { },
  useHomeManager ? true,
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}:
let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  inherit (nixpkgs.lib) mkOption types;
in
lib.evalModules {
  inherit prefix;
  class = "combinedManager";
  specialArgs = specialArgs // {
    combinedManagerPath = ./.;
  };
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
              type = types.submoduleWith {
                # TODO Are the other specialArgs (like inputs) provided?
                specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                modules =
                  import "${nixpkgs}/nixos/modules/module-list.nix"
                  ++ [ { nixpkgs.hostPlatform = lib.mkDefault builtins.currentSystem; } ]
                  ++ osModules
                  ++ config.osModules;
              };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            osConfig = config.os;
            # TODO Provide a simplified option tree to make it easy to copy option definitions from (maybe exclude the value property of each option).
            osOptions = options.os.type.getSubOptions [ ];
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
            default = "user";
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
