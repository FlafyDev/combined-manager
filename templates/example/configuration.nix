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
        customVim = prev.neovim;
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
  sys.programs.vim.defaultEditor = true;
  sys.environment.systemPackages = with pkgs;
    lib.mkIf config.sys.programs.vim.defaultEditor [
      customVim
    ];
  home.home.username = "a";
  home.xdg.configFile."somebody.txt".text = "once told me";

  home.home.stateVersion = "23.05";
  sys.system.stateVersion = "23.05";
}
