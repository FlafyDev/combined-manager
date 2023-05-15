{
  lib,
  pkgs,
  config,
  modules,
  inputs,
}:
lib.evalModules {
  # description = "Combined Manager module";
  specialArgs = {
    inherit pkgs lib inputs;
    sysConfig = config;
    modulesPath = builtins.toString ./modules;
  };
  modules =
    [
      ({
        lib,
        config,
        ...
      }: let
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
          inputs = mkOption {
            type = with types; attrs;
            default = {};
            # example = literalExpression "[ pkgs.vim ]";
            # description = "";
          };
        };

        config = {
        };
      })
    ]
    ++ modules;
}
