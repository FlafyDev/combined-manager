{
  mkFlake =
    {
      description,
      lockFile,
      system, # Required for evaluating flake inputs
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
}
