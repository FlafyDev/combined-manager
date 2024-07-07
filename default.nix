{
  mkNixosConfig = args: (import ./misc).combinedManagerToNixosConfig (import ./eval-modules.nix args);

  mkFlake =
    {
      description,
      lockFile,
      initialInputs ? { },
      configurations,
      outputs ? (_: { }),
    }@args:
    {
      inherit description;
      inputs = import ./eval-inputs.nix args;
      outputs = import ./eval-outputs.nix args;
    };
}
