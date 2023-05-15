{
  mkInputs = {
    root,
    initialInputs,
    modules,
  }: let
    flakeFile = root + "/flake.lock";
    nixpkgsLock = (builtins.fromJSON (builtins.readFile flakeFile)).nodes.nixpkgs.locked;
    lib = import ((builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
        sha256 = nixpkgsLock.narHash;
      })
      + "/lib");
    additionalInputs =
      if builtins.pathExists flakeFile
      then
        (import ./entry.nix {
          pkgs = {};
          config = {};
          inherit lib modules;
          inputs = {};
        })
        .config
        .inputs
      else {};
  in
    assert builtins.elem "nixpkgs" (builtins.attrNames initialInputs) || throw "nixpkgs input not found in initialInputs" {};
    assert builtins.elem "home-manager" (builtins.attrNames initialInputs) || throw "home-manager input not found in initialInputs" {};
      additionalInputs // initialInputs;

  mkNixosSystem = {
    inputs,
    system,
    modules,
  }: let
    inherit
      ((import ./entry.nix {
          pkgs = {};
          config = {};
          inherit (inputs.nixpkgs) lib;
          inherit modules inputs;
        })
        .config)
      sysTopLevelModules
      ;
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules =
        sysTopLevelModules
        ++ [
          inputs.home-manager.nixosModules.home-manager
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
            config =
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = {inherit inputs;};
                home-manager.sharedModules = res.homeModules;
                home-manager.users.${res.home.home.username} = _: res.home;
              }
              // res.sys;
          })
        ];
    };
}
