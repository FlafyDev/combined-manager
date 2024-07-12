{
  system,
  stateVersion,
  prefix ? [ ],
  specialArgs ? { },
  modules,
  osModules ? [ ],
  hmModules ? [ ],
}@args: # TODO Remove
let
  inherit (specialArgs.inputs) nixpkgs;
  inherit (nixpkgs) lib;
  modifiedLib = import ./modified-lib.nix lib;
  inherit (specialArgs) useHm;
  inherit (lib) mkOption types;

  osBaseModules = import "${nixpkgs}/nixos/modules/module-list.nix";
  osExtraModules =
    let
      e = builtins.getEnv "NIXOS_EXTRA_MODULE_PATH";
    in
    lib.optional (e != "") (import e);
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
              type =
                let
                  class = "nixos";
                  specialArgs = {
                    inherit useHm;
                    modulesPath = "${nixpkgs}/nixos/modules";
                  } // args.specialArgs;
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
                      // lib.optionalAttrs useHm {

                        home-manager.sharedModules = hmModules ++ [ { home.stateVersion = stateVersion; } ];
                      }
                    )
                  ];

                  inherit (lib.modules) evalModules;

                  allModules =
                    defs:
                    map (
                      { value, file }:
                      {
                        _file = file;
                        imports = [ value ];
                      }
                    ) defs;

                  base = evalModules {
                    inherit class specialArgs;
                    modules = [
                      {

                      }
                    ] ++ modules;
                  };

                  freeformType = base._module.freeformType;

                  name = "osSubmodule";
                in
                lib.mkOptionType {
                  inherit name;
                  description = freeformType.description or name;
                  check = x: lib.isAttrs x || lib.isFunction x || lib.path.check x;
                  merge =
                    loc: defs:
                    (base.extendModules {
                      modules = allModules defs;
                      prefix = loc;
                    }).config;
                  getSubOptions =
                    prefix:
                    (base.extendModules { inherit prefix; }).options
                    // lib.optionalAttrs (freeformType != null) {
                      # Expose the sub options of the freeform type. Note that the option
                      # discovery doesn't care about the attribute name used here, so this
                      # is just to avoid conflicts with potential options from the submodule
                      _freeformOptions = freeformType.getSubOptions prefix;
                    };
                  getSubModules = modules;
                  substSubModules =
                    m:
                    types.submoduleWith {
                      modules = m;
                      inherit specialArgs class;
                    };
                  nestedTypes = lib.optionalAttrs (freeformType != null) { freeformType = freeformType; };
                };
              default = { };
              visible = "shallow";
              description = "NixOS configuration.";
            };
          };

          config._module.args = {
            combinedManagerPath = ./.;

            pkgs =
              (lib.evalModules {
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
                        lib.mapAttrsRecursiveCond (x: !lib.isOption x) enhanceOption
                          (lib.evalModules { modules = [ { _module.args.name = name; } ] ++ self.type.getSubModules; })
                          .options;
                    }
                  else
                    option;
              in
              lib.mapAttrsRecursiveCond (x: !lib.isOption x) enhanceOption
                (lib.evalModules {
                  modules =
                    allOsModules
                    #lib.lists.filter (
                    #  e:
                    #  if builtins.typeOf e == "path" then
                    #    #p = /. + builtins.toPath "${nixpkgs.outPath}/nixos/modules/system/activation/top-level.nix";
                    #    #p = (builtins.trace (builtins.typeOf (/. + nixpkgs.outPath)) nixpkgs.outPath) + ./nixos/modules/system/activation/top-level.nix;
                    #    (builtins.toString e) != "${nixpkgs.outPath}/nixos/modules/system/activation/top-level.nix"
                    #  else
                    #    true
                    #) allOsModules
                    ++ [
                      (
                        let
                          osOptions = options.os.type.getSubOptions [ ];
                          #          #x = [ (options.os.value // { nixpkgs = builtins.removeAttrs config.os.nixpkgs [ "pkgs" ]; }) ];
                          #          filteredOptions = (builtins.removeAttrs osOptions [ "_module" ]) // {
                          #            nixpkgs = builtins.removeAttrs osOptions.nixpkgs [ "pkgs" ];
                          #          };
                          #          x = lib.mapAttrsRecursiveCond (x: !lib.isOption x) (_: x: x.value) (
                          #            lib.filterAttrsRecursive (name: value: true) filteredOptions
                          #          );
                          unfilteredConfig = (builtins.removeAttrs config.os [ "assertions" ]) // {
                            nixpkgs = builtins.removeAttrs config.os.nixpkgs [ "pkgs" ];
                          };
                          filter =
                            option: config:
                            builtins.trace config (
                              if lib.isOption option then
                                # TODO Does this make problems? Null is not the same as not defined
                                if lib.hasPrefix "Alias of" option.description then null else config
                              else
                                lib.foldlAttrs (
                                  result: name: value:
                                  let
                                    filterResult = filter option.${name} value;
                                  in
                                  #	builtins.trace name
                                  #(result // { ${name} = filterResult; })
                                  (if filterResult == null then result else result // { ${name} = filterResult; })
                                ) { } config
                              # 			   lib.mapAttrs ()
                            );
                        in
                        #lib.attrsets.filterAttrsRecursive (_: x: if lib.isOption x then !lib.hasPrefix "Alias of" x.description else true) unfilteredConfig
                        #        #lib.filterAttrsRecursive (
                        #        #  name: x: builtins.trace name (!lib.hasPrefix "Alias of" (x.description or ""))
                        #             #        #) unfilteredConfig
                        builtins.trace ("a") (filter osOptions unfilteredConfig)
                        #config.os // { nixpkgs = builtins.removeAttrs config.os.nixpkgs [ "pkgs" ]; }
                      )
                    ];
                }).options;
          };
        }
      )
      "${nixpkgs}/nixos/modules/misc/assertions.nix"
    ]
    ++ lib.optional useHm (
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
            extraSpecialArgs.inputs = inputs;
            users.${config.hmUsername} = config.hm;
          };
        };
      }
    )
    ++ modules;
}
