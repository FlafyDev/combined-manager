{
  # TODO Global specialArgs, modules
  mkFlake =
    {
      description,
      lockFile,
      stateVersion ? null,
      initialInputs ? { },
      useHomeManager ? true,
      configurations,
      outputs ? (_: { }),
    }@args:
    {
      inherit description;
      inputs = import ./lib/eval-inputs.nix args;
      outputs = import ./lib/eval-outputs.nix args;
    };

  nixosSystem =
    {
      inputs,
      useHomeManager ? true,
      stateVersion,
      prefix ? [ ],
      specialArgs ? { },
      modules,
      osModules ? [ ],
      hmModules ? [ ],
    }@args:
    (import ./lib/eval-outputs.nix { configurations.default = args; } inputs)
    .nixosConfigurations.default;
}
