{
  lib,
  pkgs,
  config,
  options ? {},
  modules,
  inputs,
}:
lib.evalModules {
  specialArgs = {
    inherit pkgs lib inputs;
    modulesPath = builtins.toString ./modules;
  };
  modules =
    [
      ({lib, ...}: let
        inherit (lib) mkOption types;
      in {
        options = {
          sys = mkOption {
            type = with types; anything;
            default = {};
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };
          sysModules = mkOption {
            type = with types; listOf deferredModule;
            default = [];
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };
          sysTopLevelModules = mkOption {
            type = with types; listOf deferredModule;
            default = [];
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };

          home = mkOption {
            type = with types; attrsOf anything;
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
