{
  nixosSystem =
    args: import ./lib/combined-manager-to-nixos-config.nix (import ./lib/eval-modules.nix args);

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
      inputs = import ./lib/eval-inputs.nix args;
      outputs = import ./lib/eval-outputs.nix args;
    };
}
