lockFile: let
  inherit ((builtins.fromJSON (builtins.readFile lockFile))) nodes;
  nixpkgsLock = nodes.nixpkgs.locked;
  lib = import ((builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
      sha256 = nixpkgsLock.narHash;
    })
    + "/lib");
  libFixed = import ((builtins.fetchTarball {
      url = "https://github.com/nix-community/nixpkgs.lib/archive/4833b4eb30dfe3abad5a21775bc5460322c8d337.tar.gz";
      sha256 = "sha256:1ppr46pf1glp7irxcr8w4fzfffgl34cnsb0dyy8mm8khw1bzbb5z";
    })
    + "/lib");
in
  if (builtins.pathExists lockFile && nodes ? nixpkgs)
  then lib
  else libFixed
