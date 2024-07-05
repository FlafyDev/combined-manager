let
# TODO A proper input type
inputType = types: with types; attrsOf (uniq anything);
  
  evalModules =
    {
      system ? builtins.currentSystem,
      prefix ? [ ],
      specialArgs ? { },
      useHomeManager ? true,
      modules,
      osModules ? [ ],
      hmModules ? [ ],
    }@args:
    let
      inherit (specialArgs.inputs) nixpkgs;
      inherit (nixpkgs.lib)
        optional
        evalModules
        mkOption
        types
        ;
    in
    evalModules (
      args
      // {
        specialArgs = specialArgs // {
          combinedManagerPath = ./.;
        };
        modules =
          [
            (
              { config, ... }:
              {
                options = {
                  # These inputs are used when generating the flake
                  inputs = mkOption {
                    type = inputType types;
                    default = { };
                    description = "Inputs";
                  };

                  osModules = mkOption {
                    type = with types; listOf raw;
                    default = [ ];
                    description = "Top level NixOS modules.";
                  };

                  os = mkOption {
                    type = types.submoduleWith {
                      specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                      modules = import "${nixpkgs}/nixos/modules/module-list.nix" ++ config.osModules;
                    };
                    default = { };
                    visible = "shallow";
                    description = "NixOS configuration.";
                  };
                };

                config = {
                  _module.args.osConfig = config.os;
                  os.nixpkgs.system = system;
                };
              }
            )
          ]
          ++ optional useHomeManager (
            {
              inputs,
              options,
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
                _module.args.hmConfig = osConfig.home-manager.users.${config.hmUsername};

                osModules = [ inputs.home-manager.nixosModules.default ];

                os.home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs.inputs = inputs;
                  sharedModules = config.hmModules;
                  users.${config.hmUsername} = config.hm;
                };
              };
            }
          )
          ++ modules;
      }
    );

  combinedManagerToNixosConfig = config: config // { config = config.config.os; };
in
{
  #inherit mkNixosSystem;

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
        (evalModules (
          config
          // {
            specialArgs.inputs.nixpkgs.lib = lib;
            specialArgs.configs = { };
          }
        )).options.inputs.definitionsWithLocations;
      inputsList = [
        ((builtins.unsafeGetAttrPos "initialInputs" args) // { value = initialInputs; })
      ] ++ lib.foldl (defs: config: defs ++ evalConfigInputs config) [ ] (lib.attrValues configurations);
      inputs = (inputType lib.types).merge [ "inputs" ] inputsList;
    in
    {
      inherit description inputs;

      outputs =
        inputs:
        let
          explicitOutputs = outputs inputs;

          allConfigurations = lib.mapAttrs (_: config: config.config) (
            (lib.mapAttrs (
              _: config:
              builtins.trace config evalModules (
                config
                // {
                  specialArgs = {
                    inherit inputs;
                    configs = allConfigurations;
                  };
                }
              )
              #mkCombinedManagerSystem {
              #  configuration = config // {
              #    specialArgs = (config.specialArgs or { }) // {
              #      configs = allConfigurations;
              #    };
              #  };
              #  inherit inputs;
              #}
            ) configurations)
            // explicitOutputs.nixosConfigurations or { }
          );
        in
        {
          nixosConfigurations = lib.mapAttrs (_: combinedManagerToNixosConfig) allConfigurations;
        }
        // explicitOutputs;
    };
}
