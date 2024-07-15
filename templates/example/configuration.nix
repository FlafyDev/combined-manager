{
  lib,
  pkgs,
  osConfig,
  ...
}: {
  # Adding inputs
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Adding NixOS modules
  osModules = [
    ./hardware-configuration.nix
  ];

  # Adding Home Manager modules
  hmModules = [];

  # Using `os` to set NixOS options.
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
  os.environment.systemPackages = with pkgs;
    lib.mkIf (!osConfig.programs.vim.defaultEditor) [
      customCat
    ];

  # Set the Home Manager username
  hmUsername = "a";

  # Using `hm` to set Home Manager options.
  hm.xdg.configFile."somebody.txt".text = "once told me";

  hm.home.stateVersion = "23.05";
  os.system.stateVersion = "23.05";
}
