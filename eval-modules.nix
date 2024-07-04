{
  system,
  inputs,
  prefix ? [ ],
  specialArgs ? { },
  useHomeManager ? true,
  modules ? [ ],
  osModules ? [ ],
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
  inherit (lib)
    evalModules
    mkIf
    mkOption
    types
    ;
in
evalModules {
  inherit prefix;
  specialArgs = {
    inherit inputs;
    combinedManager = ./.;
  } // specialArgs;
  modules =
    [
      # TODO What is this for?
      (
        let
          self = nixpkgs;
        in
        {
          os.system.nixos.versionSuffix = ".${
            lib.substring 0 8 (self.lastModifiedDate or self.lastModified or "19700101")
          }.${self.shortRev or "dirty"}";
          os.system.nixos.revision = mkIf (self ? rev) self.rev;
        }
      )

      (
        { config, ... }:
        {
          options = {
            inputs = mkOption {
              type = types.attrs;
              default = { };
              description = "Inputs";
            };

            # TODO Why does this exist?
            combinedManager = {
              osPassedArgs = mkOption {
                type = types.attrs;
                default = {
                  osOptions = "options";
                  pkgs = "pkgs";
                };
                visible = "hidden";
              };
              osExtraPassedArgs = mkOption {
                type = types.attrs;
                default = { };
                visible = "hidden";
              };
            };

            os = mkOption {
              type =
                let
                  baseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
                in
                types.submoduleWith {
                  description = "NixOS modules";
                  # TODO Why specify the modules special arg? Is modulesPath provided by default?
                  specialArgs = {
                    modulesPath = "${nixpkgs}/nixos/modules";
                    modules = osModules; # TODO: figure out if this is really what it should be equal to.
                  };
                  modules = baseModules ++ osModules ++ [ { nixpkgs.system = system; } ];
                };
              default = { };
              visible = "shallow";
              description = "Nixpkgs configuration.";
            };

            osModules = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "Top level NixOS modules.";
            };
          };

          config = {
            # TODO Replace config with the os config, args with the os args, and cmConfig with config
            _module.args =
              builtins.mapAttrs (_: value: config._module.args.${value} or args.${value}) (
                cmConfig.combinedManager.osExtraPassedArgs // cmConfig.combinedManager.osPassedArgs
              )
              // {
                osConfig = config.os;
              };
          };
        }
      )
    ]
    ++ lib.optional useHomeManager (
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
          osModules = [ inputs.home-manager.nixosModules.home-manager ];
          os.home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${config.hmUsername} = config.hm;
            sharedModules = config.hmModules;
            extraSpecialArgs = {
              inherit inputs;
            };
          };
        };
      }
    )
    ++ modules;
}
