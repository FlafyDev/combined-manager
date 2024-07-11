{
  mkFlake =
    {
      description,
      lockFile,
      system,
      stateVersion,
      initialInputs ? { },
      useHomeManager ? true,
      configurations,
      outputs ? (_: { }),
    }@args:
    let
      lib = import ./lib args;
    in
    {
      inherit description;
      inputs = import ./lib/eval-inputs.nix args;
      outputs = import ./lib/eval-outputs.nix args;
    };
}
