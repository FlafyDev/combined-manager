lockFile:
let
  inherit (builtins.fromJSON (builtins.readFile lockFile)) nodes;
  useFixed = !builtins.pathExists lockFile || !nodes ? nixpkgs;
  rev = if useFixed then "4284c2b73c8bce4b46a6adf23e16d9e2ec8da4bb" else nodes.nixpkgs.locked.rev;
  sha256 =
    if useFixed then
      "1pz8nmcqy68dhk6i1nkldfqask8yfp3k1qpb8apdq0dzblpwk2wb"
    else
      nodes.nixpkgs.locked.narHash;

  nixpkgsSrc = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };

  pkgs = import nixpkgsSrc { };

  # TODO Improve evaluation time by using the builtin derivation function and not copying the entire nixpkgs around
  # TODO Improve evaluation time by using the builtin derivation function and not copying the entire nixpkgs around
  modifiedLib = pkgs.stdenvNoCC.mkDerivation {
    pname = "patched-lib";
    version = rev;
    src = nixpkgsSrc;
    patches = [ ./lib.patch ];
    installPhase = "cp -r lib $out";
  };
in
import modifiedLib
