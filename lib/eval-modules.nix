{
  modules ? [],
  inputs,
  system,
  useHomeManager ? true,
  specialArgs ? {},
  osModules ? [],
  hmModules ? [],
  prefix ? [],
}: let
  inherit (inputs.nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (lib) mkOption types evalModules;
  osModule = let
    baseModules = import "${inputs.nixpkgs}/nixos/modules/module-list.nix";
  in
    types.submoduleWith {
      description = "Nixpkgs modules";
      specialArgs = {
        inherit baseModules;
        modulesPath = "${inputs.nixpkgs}/nixos/modules";
        modules = osModules; # TODO: figure out if this is really what it should be equal to.
      };
      modules =
        baseModules
        ++ osModules
        ++ [
          {nixpkgs.system = system;}
        ];
    };
in
  modifiedLib.evalModules {
    inherit prefix;
    specialArgs =
      {
        inherit inputs;
        combinedManager = ./.;
      }
      // specialArgs;
    modules =
      [
        ({lib, ...}: let
          self = inputs.nixpkgs;
        in {
          os.system.nixos.versionSuffix = ".${lib.substring 0 8 (self.lastModifiedDate or self.lastModified or "19700101")}.${self.shortRev or "dirty"}";
          os.system.nixos.revision = lib.mkIf (self ? rev) self.rev;
        })

        ({config, ...}: {
          options = {
            inputs = mkOption {
              type = with types; attrs;
              default = {};
              description = "Inputs";
            };

            osImports = mkOption {
              type = with types; listOf raw;
              default = [];
              description = "NixOS modules.";
            };

            os = lib.mkOption {
              type = osModule;
              default = {};
              visible = "shallow";
              description = "NixOS configuration.";
            };

            combinedManager = {
              osPassedArgs = lib.mkOption {
                type = types.attrs;
                default = {
                  osOptions = "options";
                  pkgs = "pkgs";
                };
                visible = "hidden";
              };
              osExtraPassedArgs = lib.mkOption {
                type = types.attrs;
                default = {};
                visible = "hidden";
              };
            };
          };

          config = {
            _module.args =
              config.os._combinedManager.args
              // {
                osConfig = config.os;
              };

            os = let
              cmConfig = config;
            in
              {config, ...} @ args: {
                options = {
                  _combinedManager.args = mkOption {
                    type = types.attrs;
                    default = {};
                    visible = "hidden";
                  };
                };
                config._combinedManager.args =
                  lib.mapAttrs (
                    _name: value: config._module.args.${value} or args.${value}
                  )
                  (
                    cmConfig.combinedManager.osExtraPassedArgs
                    // cmConfig.combinedManager.osPassedArgs
                  );
              };
          };
        })
        (lib.doRename {
          from = ["osModules"];
          to = ["osImports"];
          visible = true;
          warn = false;
          use = x: x;
        })
      ]
      ++ lib.optionals useHomeManager
      [
        ({
          options,
          config,
          osConfig,
          lib,
          ...
        }: {
          options = {
            hmUsername = lib.mkOption {
              type = types.str;
              default = "user";
              description = "Username used for Home Manager.";
            };

            hmImports = lib.mkOption {
              type = with types; listOf raw;
              default = [];
              description = "Home Manager modules.";
            };

            hm = lib.mkOption {
              type = types.deferredModule;
              default = {};
              description = "Home Manager configuration.";
            };
          };

          config = {
            _module.args.hmConfig = osConfig.home-manager.users.${config.hmUsername};

            os.home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.${config.hmUsername} = config.hm;
              sharedModules = hmModules;
              extraSpecialArgs = {inherit inputs;};
            };
          };
        })
        (lib.doRename {
          from = ["hmModules"];
          to = ["hmImports"];
          visible = true;
          warn = false;
          use = x: x;
        })
      ]
      ++ modules;
  }
