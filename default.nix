let
  evalModules = import ./eval-modules.nix;
in {
  evaluateInputs = {
    lockFile,
    modules,
    initialInputs,
  }: let
    inherit ((builtins.fromJSON (builtins.readFile lockFile))) nodes;
    evaluatedInputs =
      if (builtins.pathExists lockFile && nodes ? nixpkgs)
      then let
        nixpkgsLock = nodes.nixpkgs.locked;
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
        .inputs
      else builtins.trace "[1;31mInputs need to be evaluated again.[0m" {};
  in
    assert builtins.elem "nixpkgs" (builtins.attrNames initialInputs) || throw "nixpkgs input not found in initialInputs" {};
    assert builtins.elem "home-manager" (builtins.attrNames initialInputs) || throw "home-manager input not found in initialInputs" {};
      evaluatedInputs // initialInputs;

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
