{
  modules ? [],
  inputs,
  system,
  osModules ? [],
}: let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) mkOption types evalModules;
  osModule = let
    baseModules = import "${inputs.nixpkgs}/nixos/modules/module-list.nix";
  in
    types.submoduleWith {
      description = "Home Manager module";
      specialArgs = {
        inherit baseModules;
        modulesPath = "${inputs.nixpkgs}/nixos/modules";
      };
      modules =
        baseModules
        ++ osModules
        ++ [
          {nixpkgs.system = system;}
        ];
    };
in
  evalModules {
    specialArgs = {
      inherit inputs;
      combinedManager = ./.;
    };
    modules =
      [
        ({lib, ...}: let
          self = inputs.nixpkgs;
        in {
          os.system.nixos.versionSuffix = ".${lib.substring 0 8 (self.lastModifiedDate or self.lastModified or "19700101")}.${self.shortRev or "dirty"}";
          os.system.nixos.revision = lib.mkIf (self ? rev) self.rev;
        })

        {
          options = {
            inputs = mkOption {
              type = with types; attrs;
              default = {};
              description = "Inputs";
            };
          };
        }

        # Home Manager
        ({
          options,
          config,
          osConfig,
          lib,
          ...
        }: {
          options.hm = lib.mkOption {
            type = lib.types.deferredModule;
            default = {};
            description = ''
              Home Manager configuration.
            '';
          };

          options.hmUsername = lib.mkOption {
            type = lib.types.str;
            default = "user";
            description = ''
              Username used for hm.
            '';
          };

          options.hmModules = lib.mkOption {
            type = with types; listOf raw;
            default = [];
            description = "Home Manager modules.";
          };

          config = {
            _module.args.hmConfig = osConfig.home-manager.users.${config.hmUsername};
            osModules = [inputs.home-manager.nixosModules.home-manager];
            os = {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${config.hmUsername} = config.hm;
              home-manager.sharedModules = config.hmModules;
              home-manager.extraSpecialArgs = {inherit inputs;};
            };
          };
        })

        # Nixpkgs modules
        ({
          config,
          osConfig,
          ...
        }: {
          options = {
            os = lib.mkOption {
              type = osModule;
              default = {};
              visible = "shallow";
              description = ''
                Nixpkgs configuration.
              '';
            };

            osModules = mkOption {
              type = with types; listOf raw;
              default = [];
              description = "Top level system modules.";
            };
          };

          config = {
            _module.args =
              config.os._combined-manager.args
              // {
                osConfig = config.os;
              };
            os = {pkgs, ...}: {
              options = {
                _combined-manager.args = lib.mkOption {
                  type = lib.types.attrs;
                  default = {};
                  visible = "hidden";
                };
              };
              config._combined-manager.args = {inherit pkgs;};
            };
          };
        })
      ]
      ++ modules;
  }
