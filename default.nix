let
  # TODO A proper input type
  getInputType = types: with types; attrsOf (uniq anything);

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
        configs = { }; # TODO
      };
      modules =
        [
          (
            { config, ... }:
            {
              options = {
                inputs = mkOption {
                  type = getInputType types;
                  default = { };
                  description = "Inputs";
                };

                osModules = mkOption {
                  # A proper type
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
                # A proper type
                type = with types; listOf raw;
                default = [ ];
                description = "Home Manager modules.";
              };

              hm = mkOption {
                # A proper type
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

  # TODO Correct options
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
  mkNixosSystem = args: combinedManagerToNixosConfig (evalModules args);

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

      evalConfigInputs =
        config:
        (evalModules (config // { specialArgs.inputs.nixpkgs.lib = lib; }))
        .options.inputs.definitionsWithLocations;
      inputsList = [
        ((builtins.unsafeGetAttrPos "initialInputs" args) // { value = initialInputs; })
      ] ++ lib.foldl (defs: config: defs ++ evalConfigInputs config) [ ] (lib.attrValues configurations);
      inputs = (getInputType lib.types).merge [ "inputs" ] inputsList;
    in
    {
      inherit description inputs;

      outputs =
        args:
        let
          explicitOutputs = outputs args;

          evalConfig =
            config:
            evalModules (
              config
              // {
                specialArgs = {
                  inputs = args;
                  configs = allConfigs;
                };
              }
            );
          allConfigs =
            (lib.mapAttrs (_: config: evalConfig config) configurations)
            // explicitOutputs.nixosConfigurations or { };
        in
        {
          nixosConfigurations = lib.mapAttrs (_: combinedManagerToNixosConfig) allConfigs;
        }
        // explicitOutputs;
    };
}
