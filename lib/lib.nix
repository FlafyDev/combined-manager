lockFile:
let
  inherit (builtins.fromJSON (builtins.readFile lockFile)) nodes;
  useFixed = !builtins.pathExists lockFile || !nodes ? nixpkgs;
  rev = if useFixed then "4284c2b73c8bce4b46a6adf23e16d9e2ec8da4bb" else nodes.nixpkgs.locked.rev;
  sha256 = if useFixed then "" else nodes.nixpkgs.locked.narHash;

  nixpkgsSrc = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };

  pkgs = import nixpkgsSrc { };

  libDerivation = pkgs.stdenvNoCC.mkDerivation {
    name = "patched-nixpkgs";
    src = "${nixpkgsSrc}/lib";
  };

  output = import libDerivation;
in
builtins.trace (builtins.attrNames output) output
