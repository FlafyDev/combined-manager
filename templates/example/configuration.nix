{
  lib,
  pkgs,
  osConfig,
  ...
}: {
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  osModules = [
    ./hardware-configuration.nix
  ];
  os.nixpkgs.overlays = [
    (_final: prev: {
      customCat = prev.bat;
    })
  ];
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
  hm.home.username = "a";
  hm.xdg.configFile."somebody.txt".text = "once told me";

  hm.home.stateVersion = "23.05";
  os.system.stateVersion = "23.05";
}
