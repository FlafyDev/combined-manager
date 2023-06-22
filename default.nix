let
  evalModules = import ./eval-modules.nix;
in {
  evaluateInputs = {
    lockFile,
    modules,
  }: let
    nixpkgsLock = (builtins.fromJSON (builtins.readFile lockFile)).nodes.nixpkgs.locked;
    lib = import ((builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
        sha256 = nixpkgsLock.narHash;
      })
      + "/lib");
  in
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
    .inputs;

  nixosSystem = {
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
