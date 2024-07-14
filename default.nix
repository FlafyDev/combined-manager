{
  mkFlake = {
    description,
    lockFile,
    initialInputs ? {},
    system ? null,
    useHomeManager ? true,
    specialArgs ? {},
    modules ? [],
    osModules ? [],
    hmModules ? [],
    configurations,
    outputs ? (_: {}),
  } @ args: {
    inherit description;
    inputs = import ./lib/eval-inputs.nix args;
    outputs = import ./lib/eval-outputs.nix args;
  };

  nixosSystem = {
    inputs,
    system,
    useHomeManager ? true,
    prefix ? [],
    specialArgs ? {},
    modules ? [],
    osModules ? [],
    hmModules ? [],
  } @ args:
    (import ./lib/eval-outputs.nix {configurations.default = args;} inputs)
    .nixosConfigurations
    .default;
}
