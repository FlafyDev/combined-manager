{
  inputs,
  system,
  modules,
}: let
  inherit
    ((import ./entry.nix {
        pkgs = {};
        config = {};
        inherit (inputs.nixpkgs) lib;
        inherit modules;
        inputs = {};
      })
      .config)
    sysTopLevelModules
    ;
in
  inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit inputs;
    };
    modules =
      sysTopLevelModules
      ++ [
        ({
          pkgs,
          lib,
          config,
          inputs,
          ...
        }: let
          res =
            (import ./entry.nix {
              inherit pkgs lib config inputs modules;
            })
            .config;
        in {
          imports = res.sysModules;
          config = res.sys;
        })
      ];
  }
