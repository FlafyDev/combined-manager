let
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
                  type = with types; attrsOf anything;
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

      evalAllConfigs =
        inputs:
        let
          configs = lib.mapAttrs (
            _: config:
            evalModules (
              config
              // {
                specialArgs = {
                  inherit inputs configs;
                };
              }
            )
          ) configurations;
        in
        configs;

      # TODO Handle mkDefault etc.

      initialInputsWithLocation = [
        {
          value = initialInputs;
          file = (builtins.unsafeGetAttrPos "initialInputs" args).file;
        }
      ];
      configsForInputs = evalAllConfigs { nixpkgs.lib = lib; };
      configInputs = lib.foldlAttrs (
        result: _: config:
        result ++ config.options.inputs.definitionsWithLocations
      ) [ ] configsForInputs;
      inputs = lib.foldl (
        inputs:
        { file, value }:
        let
          checkedInputs = lib.foldlAttrs (
            inputs: name: value:
            assert
              !(inputs ? ${name} && inputs.${name} != value)
              || throw "The input `${name}` has conflicting definition values:\n- In ``: \n- In `${file}`: ${
                lib.generators.toPretty { } value
              }";
            inputs
          ) inputs value;
        in
        checkedInputs // value
      ) { } (initialInputsWithLocation ++ configInputs);

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
            // explicitOutputs.nixosConfigurations or { };
        };
    };
}
