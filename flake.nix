{
  description = "Combined Manager";

  outputs = _: {
    inherit (import ./.) NixosSystem evaluateInputs;

    templates = rec {
      bare = {
        path = ./templates/bare;
        description = "A bare nixos config using Combined Manager.";
        welcomeText = builtins.readFile ./README.md;
      };
      example = {
        path = ./templates/example;
        description = "An example nixos config using Combined Manager.";
        welcomeText = builtins.readFile ./README.md;
      };
      default = example;
    };
  };
}
