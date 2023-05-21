{
  mkInputs = {
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
    assert builtins.elem "home-manager" (builtins.attrNames initialInputs) || throw "home-manager input not found in initialInputs" {};
      additionalInputs // initialInputs;

  mkNixosSystem = {
    inputs,
    system,
    modules,
  }: let
    inherit (inputs.nixpkgs) lib;
    inherit
      ((inputs.nixpkgs.lib.evalModules {
        specialArgs = {
          pkgs =
            inputs.nixpkgs.legacyPackages.${system};
        };
        modules = import "${inputs.nixpkgs}/nixos/modules/module-list.nix";
      }))
      options
      ;
    inherit
      ((import ./entry.nix {
          pkgs = {};
          config = {};
          inherit modules inputs lib;
        })
        .config)
      sysModules
      homeModules
      ;
    recursiveSetIfDefined = attrs: prevName:
      lib.mapAttrs (
        name: value: let
          newName = "${prevName}.${name}";
        in
          if (value ? "isDefined")
          then (lib.mkIf value.isDefined value.value)
          else recursiveSetIfDefined value newName
      )
      (lib.filterAttrs (name: value: (!(value ? "readOnly" && value.readOnly))) attrs);
    recursivePrintIfDefined = attrs: prevName:
      lib.mapAttrs (
        name: value: let
          newName = "${prevName}.${name}";
        in
          if (value ? "isDefined")
          then
            (
              if value.isDefined
              then builtins.trace "setting ${newName} to '${toString value.value}'" value.value
              else null
            )
          else recursiveSetIfDefined value newName
      )
      (lib.filterAttrs (name: value: (!(value ? "readOnly" && value.readOnly))) attrs);
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules =
        sysModules
        ++ [
          inputs.home-manager.nixosModules.home-manager
          ({
            pkgs,
            lib,
            config,
            ...
          }: let
            res = import ./entrytest.nix {
              inherit pkgs lib config inputs modules options;
            };
          in
            builtins.trace
            # ((recursiveSetIfDefined res.options.sys "root")
            #   // {
            #     _module.args = {
            #       pkgs = lib.mkForce (import inputs.nixpkgs (
            #         (builtins.removeAttrs config.nixpkgs ["localSystem"])
            #         // {
            #           overlays = config.nixpkgs.overlays ++ res.config.nixpkgs.overlays;
            #           config = config.nixpkgs.config // res.config.nixpkgs.config;
            #         }
            #       ));
            #     };
            #     # home-manager.useGlobalPkgs =  recursivePrintIfDefined res.options.sys "root" == {};
            #     home-manager.useGlobalPkgs = true;
            #     home-manager.useUserPackages = true;
            #     home-manager.sharedModules = homeModules;
            #     home-manager.users.${res.config.home.home.username} = _: {config = res.config.home;};
            #     # users.users.root.uid = null;
            #     # system.build = lib.mkIf false null;
            #     # users.users.root.group = lib.mkIf false null;
            #     # users.users.root.password = lib.mkIf false null;
            #     # users.users.root.isSystemUser = lib.mkIf false null;
            #   }).users.users.content.root.password
              ( options.users.users.type.getSubOptions []).root
              {
              config =
                (recursiveSetIfDefined res.options.sys "root")
                // {
                  _module.args = {
                    pkgs = lib.mkForce (import inputs.nixpkgs (
                      (builtins.removeAttrs config.nixpkgs ["localSystem"])
                      // {
                        overlays = config.nixpkgs.overlays ++ res.config.nixpkgs.overlays;
                        config = config.nixpkgs.config // res.config.nixpkgs.config;
                      }
                    ));
                  };
                  # home-manager.useGlobalPkgs =  recursivePrintIfDefined res.options.sys "root" == {};
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.sharedModules = homeModules;
                  home-manager.users.${res.config.home.home.username} = _: {config = res.config.home;};
                  # users.users.root.uid = null;
                  # system.build = lib.mkIf false null;
                  # users.users.root.group = lib.mkIf false null;
                  # users.users.root.password = lib.mkIf false null;
                  # users.users.root.isSystemUser = lib.mkIf false null;
                };
            })
        ];
    };
}
