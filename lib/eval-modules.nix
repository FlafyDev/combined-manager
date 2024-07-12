{
  stateVersion,
  prefix ? [ ],
  specialArgs ? { },
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}:
with specialArgs.inputs.nixpkgs.lib;
let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (specialArgs) useHm;
  inherit mkOption types;

  osSpecialArgs = specialArgs // {
    modulesPath = "${nixpkgs}/nixos/modules";
  };

  osBaseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  osExtraModules =
    let
      e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
    in
    optional (e != "") (import e);
  allOsModules = osBaseModules ++ osExtraModules ++ osModules;
in
modifiedLib.evalModules {
  inherit prefix specialArgs;
  class = "combinedManager";
  modules =
    [
      (
        { options, config, ... }:
        {
          options = {
            inputs = mkOption {
              type = with types; attrsOf raw;
              default = { };
              description = "Inputs";
            };

            osImports = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "NixOS modules.";
            };

            os = mkOption {
              type = types.submoduleWith {
                class = "nixos";
                specialArgs = osSpecialArgs;
                modules = allOsModules ++ [
                  (
                    { config, ... }:
                    {
                      _module.args = {
                        baseModules = osBaseModules;
                        extraModules = osExtraModules;
                        modules = osModules;
                      };
                      system.stateVersion = stateVersion;
                    }
                    // optionalAttrs useHm {
                      home-manager.sharedModules = hmModules ++ [ { home.stateVersion = stateVersion; } ];
                    }
                  )
                ];
              };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            combinedManagerPath = ./.;

            pkgs =
              (evalModules {
                modules = [
                  "${nixpkgs}/nixos/modules/misc/nixpkgs.nix"
                  {
                    nixpkgs = builtins.removeAttrs config.os.nixpkgs [
                      "pkgs"
                      "flake"
                    ];
                  }
                ];
              })._module.args.pkgs;

            osConfig = config.os;

            osOptions =
              let
                enhanceOption =
                  _: option:
                  # TODO Support listOf, functionTo, and standalone submodules
                  if
                    (option.type.name == "attrsOf" || option.type.name == "lazyAttrsOf")
                    && option.type.nestedTypes.elemType.name == "submodule"
                  then
                    option
                    // {
                      __functor =
                        self: name:
                        mapAttrsRecursiveCond (x: !isOption x) enhanceOption
                          (evalModules { modules = [ { _module.args.name = name; } ] ++ self.type.getSubModules; }).options;
                    }
                  else
                    option;
              in
              mapAttrsRecursiveCond (x: !isOption x) enhanceOption
                (evalModules {
                  specialArgs = osSpecialArgs;
                  modules = allOsModules ++ [
                    (
                      let
                        osOptions = options.os.type.getSubOptions [ ];
                        filteredOsOptions = (removeAttrs osOptions [ "_module" ]) // {
                          nixpkgs = removeAttrs osOptions.nixpkgs [ "pkgs" ];
                        };
                        # TODO Try relying on option.isDefined instead of the description
                        filteredOptions = filterAttrsRecursive (
                          name: x: !isOption x || !hasPrefix "Alias of" x.description or ""
                        ) filteredOsOptions;
                      in
                      mapAttrsRecursiveCond (x: !isOption x) (path: _: getAttrFromPath path config.os) filteredOptions
                    )
                  ];
                }).options;
          };
        }
      )
      "${nixpkgs}/nixos/modules/misc/assertions.nix"
      (doRename {
        from = [ "osModules" ];
        to = [ "osImports" ];
        visible = false;
        warn = false;
        use = x: x;
      })
    ]
    ++ optionals useHm [
      (
        {
          inputs,
          osOptions,
          config,
          osConfig,
          ...
        }:
        {
          options = {
            hmUsername = mkOption {
              type = types.str;
              description = "Username used for Home Manager.";
            };

            hmImports = mkOption {
              type = with types; listOf raw;
              default = [ ];
              description = "Home Manager modules.";
            };

            hm = mkOption {
              type = types.deferredModule;
              default = { };
              description = "Home Manager configuration.";
            };
          };

          config = {
            _module.args = {
              hmConfig = osConfig.home-manager.users.${config.hmUsername};
              hmOptions = osOptions.home-manager.users config.hmUsername;
            };

            os.home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = specialArgs;
              users.${config.hmUsername} = config.hm;
            };
          };
        }
      )
      (doRename {
        from = [ "hmModules" ];
        to = [ "hmImports" ];
        visible = false;
        warn = true;
        use = x: x;
      })
    ]
    ++ modules;
}
