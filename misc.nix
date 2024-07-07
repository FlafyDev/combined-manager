{
  lib =
    lockFile:
    let
      inherit (builtins.fromJSON (builtins.readFile lockFile)) nodes;
      nixpkgsLock = nodes.nixpkgs.locked;
      flake = builtins.getFlake (
        if (builtins.pathExists lockFile && nodes ? nixpkgs) then
          "github:NixOS/nixpkgs/${nixpkgsLock.rev}"
        else
          "github:Nixos/nixpkgs/4284c2b73c8bce4b46a6adf23e16d9e2ec8da4bb"
      );
    in
    flake.lib;

  combinedManagerToNixosConfig =
    config:
    config
    // {
      class = "nixos";
      options = config.options.os;
      config = config.config.os;
    };
}
