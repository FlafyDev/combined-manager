{
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
    additionalInputs // initialInputs
