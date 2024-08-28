{
  description = "Combined Manager";

  outputs = _: {
    inherit (import ./.) mkFlake nixosSystem;

    templates = let
      buildWelcomeText = template: ''
        # ${template} Combined Manager template
        Replace `REV` in `flake.nix` with the latest revision of Combined Manager and specify the appropriate hash to get started.

        For more information on Combined Manager, see the `README.md` of the project.
      '';
    in rec {
      default = example;
      bare = {
        path = ./templates/bare;
        description = "A bare NixOS config using Combined Manager";
        welcomeText = buildWelcomeText "Bare";
      };
      example = {
        path = ./templates/example;
        description = "An example NixOS config using Combined Manager";
        welcomeText = buildWelcomeText "Example";
      };
    };
  };
}
