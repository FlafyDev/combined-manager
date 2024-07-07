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
            { options, config, ... }:
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
                    # TODO Are the other specialArgs (like inputs) provided?
                    specialArgs.modulesPath = "${nixpkgs}/nixos/modules";
                    modules =
                      import "${nixpkgs}/nixos/modules/module-list.nix"
                      ++ [ { nixpkgs.hostPlatform = lib.mkDefault builtins.currentSystem; } ]
                      ++ osModules
                      ++ config.osModules;
                  };
                  default = { };
                  visible = "shallow";
                  description = "NixOS configuration.";
                };
              };

              config._module.args = {
                osConfig = config.os;
                # TODO Provide a simplified option tree to make it easy to copy option definitions from (maybe exclude the value property of each option).
                osOptions = options.os.type.getSubOptions [ ];
              };
            }
          )
        ]
        ++ lib.optional useHomeManager (
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
                # TODO Copy the hmModule type from https://github.com/nix-community/home-manager/blob/master/nixos/common.nix
                type = types.deferredModule;
                default = { };
                description = "Home Manager configuration.";
              };
            };

            config = {
              _module.args = {
                hmConfig = osConfig.home-manager.users.${config.hmUsername};
                hmOptions = options.hm;
              };

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
          flake = builtins.getFlake (
            if (builtins.pathExists lockFile && nodes ? nixpkgs) then
              "github:NixOS/nixpkgs/${nixpkgsLock.rev}"
            else
              "github:Nixos/nixpkgs/4284c2b73c8bce4b46a6adf23e16d9e2ec8da4bb"
          );
        in
        flake.lib;

      initialInputsWithLocation = lib.singleton {
        file = (builtins.unsafeGetAttrPos "initialInputs" args).file;
        value = initialInputs;
      };

      directConfigModules = lib.foldlAttrs (
        modules: _: config:
        modules ++ config.modules
      ) [ ] configurations;
      configModules = lib.modules.collectModules "" directConfigModules {
        inherit lib;
        config = null;
      };
      configInputs = lib.foldl (
        modules: module:
        let
          findInputs =
            x:
            if x ? inputs then
              x.inputs
            else if x ? content then
              findInputs x.content
            else
              [ ];
          inputs = findInputs module.config;
        in
        modules
        ++ lib.optional (inputs != [ ]) {
          file = module._file;
          value = inputs;
        }
      ) [ ] configModules;

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

      explicitOutputs = outputs args;
      nixosConfigurations = lib.mapAttrs (_: combinedManagerToNixosConfig) (
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
        configs
      );
      outputs =
        inputs:
        explicitOutputs
        // {
          nixosConfigurations = nixosConfigurations // explicitOutputs.nixosConfigurations or { };
        };
    in
    {
      inherit description inputs outputs;
    };
}
