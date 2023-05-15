{
  lib,
  pkgs,
  config,
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
            type = with types; attrs;
            default = {};
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };
          sysModules = mkOption {
            type = with types; listOf path;
            default = [];
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };
          sysTopLevelModules = mkOption {
            type = with types; listOf path;
            default = [];
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };

          home = mkOption {
            type = with types; attrs;
            default = {};
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };

          homeModules = mkOption {
            type = with types; listOf path;
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
        };
      })
    ]
    ++ modules;
}
