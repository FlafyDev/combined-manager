{
  lib,
  pkgs,
  config,
  options ? {},
  modules,
  inputs,
  osConfig ? {},
}:
lib.evalModules {
  specialArgs = {
    inherit pkgs lib inputs;
    sysConfig = config;
    modulesPath = builtins.toString ./modules;
  };
  modules =
    [
      ({lib, ...}: let
        inherit (lib) mkOption types;
        moreTypes = import ./types.nix {inherit lib;};
      in {
        options = {
          sys = mkOption {
            type = moreTypes.anything;
            default = {};
          };

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
