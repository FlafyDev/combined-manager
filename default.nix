{
  mkFlake = {
    description ? "NixOS configuration",
    lockFile,
    initialInputs ? {},
    useHomeManager ? true,
    globalSpecialArgs ? {},
    globalModules ? [],
    globalOsModules ? [],
    globalHmModules ? [],
    configurations,
    outputs ? (_: {}),
  } @ args: {
    inherit description;
    inputs = import ./lib/eval-inputs.nix args;
    outputs = import ./lib/eval-outputs.nix args;
  };

  nixosSystem = {
    inputs,
    inputOverrides ? (_: {}),
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
