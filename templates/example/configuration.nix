{
  lib,
  pkgs,
  config,
  ...
}: {
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  sysTopLevelModules = [
    ./hardware-configuration.nix
  ];
  sys = {
    nixpkgs.overlays = [
      (_final: prev: {
        customCat = prev.bat;
      })
    ];
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
  sys.programs.vim.defaultEditor = false;
  sys.environment.systemPackages = with pkgs;
    lib.mkIf (!config.sys.programs.vim.defaultEditor) [
      customCat
    ];
  home.home.username = "a";
  home.xdg.configFile."somebody.txt".text = "once told me";

  home.home.stateVersion = "23.05";
  sys.system.stateVersion = "23.05";
}
