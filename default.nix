let
  evalModules = import ./eval-modules.nix;

  getLib = {lockFile}: let
    inherit ((builtins.fromJSON (builtins.readFile lockFile))) nodes;
    nixpkgsLock = nodes.nixpkgs.locked;
    lib = import ((builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgsLock.rev}.tar.gz";
        sha256 = nixpkgsLock.narHash;
      })
      + "/lib");
  in
    if (builtins.pathExists lockFile && nodes ? nixpkgs)
    then lib
    else builtins.trace "[1;31mInputs need to be evaluated again.[0m" null;

  evaluateConfigInputs = configuration: lib:
    (evalModules {
      inherit (configuration) modules system;
      inputs = {
        nixpkgs = {
          inherit lib;
        };
      };
    })
    .config
    .inputs;

  nixosSystem = {
    inputs,
    system,
    modules,
  }: let
    inherit ((evalModules {inherit modules inputs system;}).config) osModules;

    evaluated = evalModules {
      inherit modules inputs osModules system;
    };
  in {config = evaluated.config.os;};

  mkFlake = {
    lockFile,
    description,
    initialInputs,
    configurations,
    outputs ? (_: {}),
  }: let
    lib = getLib {inherit lockFile;};

    evaluatedInputs =
      lib.foldl
      (
        allInputs: configInputs:
        # This foldAttrs is basically `allInputs // configInputs` but with an assertion.
          lib.foldlAttrs (
            allInputs: inputName: inputValue:
              assert (!(builtins.elem inputName (builtins.attrNames allInputs) && allInputs.${inputName} != inputValue)) || throw "The input \"${inputName}\" appears more than once and equals to different values!\nFirst definition: ${builtins.toJSON inputValue}\nSecond definition: ${builtins.toJSON allInputs.${inputName}}";
                allInputs // {${inputName} = inputValue;}
          )
          allInputs
          configInputs
      ) {}
      (map (config: evaluateConfigInputs config lib)
        (builtins.attrValues configurations));
  in
    assert builtins.elem "nixpkgs" (builtins.attrNames initialInputs) || throw "nixpkgs input not found in initialInputs" {};
    assert builtins.elem "home-manager" (builtins.attrNames initialInputs) || throw "home-manager input not found in initialInputs" {}; {
      inherit description;
      inputs = evaluatedInputs // initialInputs;
      outputs = inputs:
        (outputs inputs)
        // {
          nixosConfigurations =
            (lib.mapAttrs (_name: config:
              nixosSystem {
                inherit (config) system modules;
                inherit inputs;
              })
            configurations)
            // (outputs inputs).nixosConfigurations or {};
        };
    };
in {inherit mkFlake nixosSystem;}
