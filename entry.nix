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
    };
    modules =
      [
        # TODO
        {
          os.system.nixos.versionSuffix = ".dirty";
          os.system.nixos.revision = "dirty";
        }

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

        # (_: {
        #   imports = [
        #     ({pkgs, ...}: {
        #       os.nixpkgs.overlays = [
        #         (final: prev: {
        #           customVim = prev.vim;
        #         })
        #       ];
        #     })
        #   ];
        #
        #   config = {
        #     os = builtins.trace utils {
        #       programs.hyprland.enable = true;
        #       users.users.root = {
        #         group = "root";
        #         password = "root";
        #         isSystemUser = true;
        #       };
        #       users.users.a = {
        #         group = "a";
        #         password = "a";
        #         isNormalUser = true;
        #       };
        #       users.mutableUsers = false;
        #
        #       # environment.systemPackages = [
        #       #   pkgs.customVim
        #       # ];
        #     };
        #     hm.home.stateVersion = "22.05";
        #   };
        # })

        #   ({lib, ...}: let
        #     inherit (lib) mkOption types;
        #     moreTypes = import ./types.nix {inherit lib;};
        #   in {
        #     options = {
        #       sys = mkOption {
        #         type = moreTypes.anything;
        #         default = {};
        #       };
        #
        #       sysModules = mkOption {
        #         type = with types; listOf deferredModule;
        #         default = [];
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #
        #       home = mkOption {
        #         type = moreTypes.anything;
        #         default = {};
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #
        #       homeModules = mkOption {
        #         type = with types; listOf raw;
        #         default = [];
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #
        #       inputs = mkOption {
        #         type = with types; attrs;
        #         default = {};
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #
        #       nixpkgs.config = mkOption {
        #         type = with types;
        #           if options ? nixpkgs
        #           then options.nixpkgs.config.type
        #           else attrs;
        #         default = {};
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #
        #       nixpkgs.overlays = mkOption {
        #         type = with types;
        #           if options ? nixpkgs
        #           then options.nixpkgs.overlays.type
        #           else listOf anything;
        #         default = [];
        #         # example = literalExpression "[ pkgs.vim ]";
        #         # description = "";
        #       };
        #     };
        #   })
      ]
      ++ modules;
  }
