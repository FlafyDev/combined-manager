{
  description = "Combined Manager";

  outputs = {self}: {
    templates = {
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
    };

    templates.default = self.templates.example;
  };
}
