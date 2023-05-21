{
  lib,
  pkgs,
  config,
  options,
  modules,
  inputs,
}: let
  removeDefaultRecur = attrs:
    lib.mapAttrs (name: value:
      if (builtins.isAttrs value)
      then removeDefaultRecur value
      else value) (builtins.removeAttrs attrs ["default"]);
in
  lib.evalModules {
    specialArgs = {
      inherit pkgs lib inputs;
      modulesPath = builtins.toString ./modules;
    };
    modules =
      [
        ({lib, ...}: let
          inherit (lib) mkOption types;
          moreTypes = import ./types.nix {inherit lib;};
        in {
          options = {
            # sys = builtins.trace ((builtins.removeAttrs options [
            #     ])).programs.hyprland.enable (removeDefaultRecur (builtins.removeAttrs options [
            #     ]));
            # sys = lib.filterAttrs (name: value: name == "boot" || name == "hardware") (removeDefaultRecur options);
            sys = lib.filterAttrs (name: value: name == "boot" || name == "hardware" || name == "users" || name == "system") (removeDefaultRecur options);
            # sys.boot.kernelPackages  = (builtins.trace options options.boot.kernelPackages );
            # sys.hardware.nvidia.package = options.hardware.nvidia.package;
            # sys = mkOption {
            #   type = moreTypes.anything;
            #   default = {};
            # };

            sysModules = mkOption {
              type = with types; listOf deferredModule;
              default = [];
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };

            home = mkOption {
              type = moreTypes.anything;
              default = {};
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };

            homeModules = mkOption {
              type = with types; listOf raw;
              default = [];
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };

            inputs = mkOption {
              type = with types; attrs;
              default = {};
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };

            nixpkgs.config = mkOption {
              type = with types;
                if options ? nixpkgs
                then options.nixpkgs.config.type
                else attrs;
              default = {};
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };

            nixpkgs.overlays = mkOption {
              type = with types;
                if options ? nixpkgs
                then options.nixpkgs.overlays.type
                else listOf anything;
              default = [];
              # example = literalExpression "[ pkgs.vim ]";
              # description = "";
            };
          };
        })
      ]
      ++ modules;
  }
