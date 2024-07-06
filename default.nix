let
  # TODO A proper input type
  getInputType =
    lib:
    with lib.types;
    let
      inherit (lib) mkOption;
      # TODO Use the official type from nixpkgs once it gets shipped (https://github.com/NixOS/nixpkgs/pull/254790)
      taggedSubmodule =
        types:
        lib.mkOptionType {
          name = "taggedSubmodule";
          description = "submodule with type tag";
          check =
            x:
            if x ? type then
              types.${x.type}.check x
            else
              throw "No type option set in:\n${lib.generators.toPretty { } x}";
          merge = loc: foldl' (res: def: types.${def.value.type}.merge loc [ def ]) { };
          nestedTypes = types;
        };
    in
    attrsOf (
      let
        url = submodule { options.url = mkOption { type = str; }; };
        types = {
          path = submodule {
            options = {
              type = mkOption { type = str; };
              path = mkOption { };
            };
          };
          git = submodule { options.type = mkOption { type = str; }; };
          mercurial = attrsOf anything;
          tarball = attrsOf anything;
          file = attrsOf anything;
          github = submodule {
            options = {
              type = mkOption { type = str; };
              owner = mkOption { type = str; };
              repo = mkOption { type = str; };
            };
          };
          gitlab = attrsOf anything;
        };
      in
      lib.mkOptionType {
        name = "flakeInput";
        description = "flake input";
        check =
          x:
          if x ? type then
            types.${x.type}.check x
          else if x ? url then
            url.check x
          else
            throw "No type option set in:\n${lib.generators.toPretty { } x}";
        # TODO Can it be lib.foldl instead of lib.foldl'?
        merge =
          loc:
          lib.foldl' (
            res: def:
	    builtins.trace res
            (if def.value ? type then types.${def.value.type}.merge loc [ res def ] else url.merge loc [ res def ])
          ) { };
        nestedTypes = types // {inherit url;};
      }
    );

  evalModules =
    {
      prefix ? [ ],
      specialArgs ? { },
      useHomeManager ? true,
      modules,
      osModules ? [ ],
      hmModules ? [ ],
    }:
    let
      inherit (specialArgs.inputs) nixpkgs;
      inherit (nixpkgs) lib;
      inherit (nixpkgs.lib) mkOption types;
    in
    lib.evalModules {
      inherit prefix;
      class = "combinedManager";
      specialArgs = specialArgs // {
        combinedManagerPath = ./.;
      };
      modules =
        [
          (
            { config, ... }:
            {
              options = {
                inputs = mkOption {
                  type = getInputType lib;
                  default = { };
                  description = "Inputs";
                };

                osModules = mkOption {
                  # TODO A proper type
                  type = with types; listOf raw;
                  default = [ ];
                  description = "NixOS modules.";
                };

                os = mkOption {
                  type = types.submoduleWith {
                    specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                    modules = import "${nixpkgs}/nixos/modules/module-list.nix" ++ osModules ++ config.osModules;
                  };
                  default = { };
                  visible = "shallow";
                  description = "NixOS configuration.";
                };
              };

              config._module.args.osConfig = config.os;
            }
          )
        ]
        ++ lib.optional useHomeManager (
          {
            inputs,
            config,
            osConfig,
            ...
          }:
          {
            options = {
              hmUsername = mkOption {
                type = types.str;
                default = "user";
                description = "Username used for Home Manager.";
              };

              hmModules = mkOption {
                # TODO A proper type
                type = with types; listOf raw;
                default = [ ];
                description = "Home Manager modules.";
              };

              hm = mkOption {
                # TODO A proper type
                type = types.deferredModule;
                default = { };
                description = "Home Manager configuration.";
              };
            };

            config = {
              _module.args.hmConfig = osConfig.home-manager.users.${config.hmUsername};

              osModules = [ inputs.home-manager.nixosModules.default ];

              os.home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs.inputs = inputs;
                sharedModules = hmModules ++ config.hmModules;
                users.${config.hmUsername} = config.hm;
              };
            };
          }
        )
        ++ modules;
    };

  combinedManagerToNixosConfig =
    config:
    config
    // {
      class = "nixos";
      options = config.options.os;
      config = config.config.os;
    };
in
{
  mkNixosConfig = args: combinedManagerToNixosConfig (evalModules args);

  mkFlake =
    {
      description,
      lockFile,
      initialInputs ? { },
      configurations,
      outputs ? (_: { }),
    }@args:
    let
      lib =
        let
          inherit (builtins.fromJSON (builtins.readFile lockFile)) nodes;
          nixpkgsLock = nodes.nixpkgs.locked;
        in
        import (
          if (builtins.pathExists lockFile && nodes ? nixpkgs) then
            (builtins.fetchTarball {
              url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
              sha256 = nixpkgsLock.narHash;
            })
            + "/lib"
          else
            <nixpkgs/lib>
        );

      evalConfig =
        {
          config,
          inputs,
          configs,
        }:
        evalModules (
          config
          // {
            specialArgs = {
              inherit inputs configs;
            };
          }
        );
      evalAllConfigs =
        inputs:
        let
          configs = lib.mapAttrs (_: config: evalConfig { inherit config inputs configs; }) configurations;
        in
        configs;

      inputs = (getInputType lib).merge [ "inputs" ] (
        [ ((builtins.unsafeGetAttrPos "initialInputs" args) // { value = initialInputs; }) ]
        ++
          lib.foldlAttrs
            (
              defs: _: config:
              defs ++ config.options.inputs.definitionsWithLocations
            )
            [ ]
            (evalAllConfigs {
              nixpkgs.lib = lib;
            })
      );
    in
    {
      inherit description inputs;

      outputs =
        inputs:
        let
          explicitOutputs = outputs args;
        in
        explicitOutputs
        // {
          nixosConfigurations =
            (lib.mapAttrs (_: combinedManagerToNixosConfig) (evalAllConfigs inputs))
            // explicitOutputs.nixosConfigurations;
        };
    };
}
