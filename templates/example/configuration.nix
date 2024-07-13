{
  lib,
  inputs,
  pkgs,
  osConfig,
  ...
}:
{
  # Adding inputs
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Adding top level system modules
  osImports = [ ./hardware-configuration.nix ];

  # Adding home modules
  hmImports = [ ];

  # Setting overlays
  os.nixpkgs.overlays = [ (_final: prev: { customCat = prev.bat; }) ];

  # Using `os` to set Nixpkgs options.
  os = {
    users.users.root = {
      group = "root";
      password = "root";
      isSystemUser = true;
    };
    users.users.a = {
      group = "a";
      password = "a";
      isNormalUser = true;
    };
    users.mutableUsers = false;
  };
  os.programs.vim.defaultEditor = false;
  os.environment.systemPackages =
    with pkgs;
    lib.mkIf (!osConfig.programs.vim.defaultEditor) [ customCat ];

  # Set Home Manager username
  hmUsername = "a";

  # Using `hm` to set Home Manager options.
  hm.xdg.configFile."somebody.txt".text = "once told me";
}
