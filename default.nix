let
  evalModules = import ./eval-modules.nix;
in {
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
        (evalModules {
          inherit modules;
          inputs = {
            nixpkgs = {
              inherit lib;
              inherit (nixpkgsLock) rev;
              lastModified = toString nixpkgsLock.lastModified;
              shortRev = builtins.substring 0 7 nixpkgsLock.rev;
            };
          };
          system = builtins.currentSystem;
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
    inherit ((evalModules {inherit modules inputs system;}).config) osModules;

    evaluated = evalModules {
      inherit modules inputs osModules system;
    };
  in {config = evaluated.config.os;};
}
