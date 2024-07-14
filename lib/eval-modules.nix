{
  system,
  prefix ? [],
  specialArgs ? {},
  modules ? [],
  osModules ? [],
  hmModules ? [],
}: let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (specialArgs) useHm;
  inherit (lib) mkOption types;

  osModule = let
    baseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  in
    types.submoduleWith {
      description = "Nixpkgs modules";
      specialArgs =
        specialArgs
        // {
          modulesPath = "${nixpkgs}/nixos/modules";
          inherit baseModules;
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
        combinedManager = import ../.;
        combinedManagerPath = ./.;
      }
      // specialArgs;
    modules =
      [
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
          };

          config = {
            _module.args = {
              pkgs =
                (lib.evalModules {
                  modules = [
                    "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
                    {nixpkgs = builtins.removeAttrs config.os.nixpkgs ["pkgs" "flake"];}
                  ];
                })
                ._module
                .args
                .pkgs;

              osConfig = config.os;
            };

            os = {
              system.nixos.versionSuffix = ".${lib.substring 0 8 (nixpkgs.lastModifiedDate or nixpkgs.lastModified or "19700101")}.${nixpkgs.shortRev or "dirty"}";
              system.nixos.revision = lib.mkIf (nixpkgs ? rev) nixpkgs.rev;
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
      ++ lib.optionals useHm
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
              extraSpecialArgs = specialArgs;
              sharedModules = hmModules;
              users.${config.hmUsername} = config.hm;
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
