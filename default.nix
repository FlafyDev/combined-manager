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
                  type = with types; attrsOf raw;
                  default = { };
                  description = "Inputs";
                };

                osModules = mkOption {
                  type = with types; listOf raw;
                  default = [ ];
                  description = "NixOS modules.";
                };

                os = mkOption {
                  type = types.submoduleWith {
                    specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                    modules =
                      import "${nixpkgs}/nixos/modules/module-list.nix"
                      ++ osModules
                      ++ config.osModules
                      ++ [ { nixpkgs.hostPlatform = lib.mkDefault builtins.currentSystem; } ];
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
                type = with types; listOf raw;
                default = [ ];
                description = "Home Manager modules.";
              };

              hm = mkOption {
                # TODO Copy the hmModule type from https://github.com/nix-community/home-manager/blob/master/nixos/common.nix
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

      initialInputsWithLocation = lib.singleton {
        file = (builtins.unsafeGetAttrPos "initialInputs" args).file;
        value = initialInputs;
      };
      configsForInputs = evalAllConfigs { nixpkgs.lib = lib; };
      configInputs = lib.foldlAttrs (
        result: _: config:
        result ++ config.options.inputs.definitionsWithLocations
      ) [ ] configsForInputs;
      inputDefs = initialInputsWithLocation ++ configInputs;
      typeCheckedInputDefs =
        let
          wrongTypeDefs = lib.filter (def: lib.typeOf def.value != "set") inputDefs;
        in
        if wrongTypeDefs == [ ] then
          inputDefs
        else
          throw "A definition for option `inputs' is not of type `attribute set of raw value'. Definition values:${lib.options.showDefs wrongTypeDefs}";

      uncheckedInputs = lib.foldl (inputs: def: inputs // def.value) { } typeCheckedInputDefs;
      inputs = lib.foldlAttrs (
        inputs: inputName: _:
        let
          defs = lib.foldl (
            defs: def:
            defs
            ++ (lib.optional (def.value ? ${inputName}) {
              file = def.file;
              value = def.value.${inputName};
            })
          ) [ ] typeCheckedInputDefs;
          firstDef = lib.head defs;
          areDefsEqual = lib.all (def: firstDef.value == def.value) (lib.drop 1 defs);
        in
        if areDefsEqual then
          inputs
        else
          throw "The input `${inputName}' has conflicting definition values:${lib.options.showDefs defs}"
      ) uncheckedInputs uncheckedInputs;
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
