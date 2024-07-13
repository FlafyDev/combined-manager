# Combined Manager
Combined Manager provides a new structure for personal NixOS configurations.
###### Note: Requires patching `nix` to solve [this issue](https://github.com/NixOS/nix/issues/3966). See more in the [Nix Patches section](#nix-patches).

- [Introduction](#introduction-no-separation)
- [Module structure](#module-options)
- [Current limitations](#current-limitations)
- [Getting started](#getting-started)
- [Stability](#stability)
- [Examples](#examples)
    - [Full configurations](#full-configurations)
    - [Modules](#modules)
- [Patching Nix](#patching-nix)

## Introduction: No separation
The main feature of Combined Manager is to break separation. Most NixOS configuration structures are designed to separate related things into multiple files.

Most prominent separations:
- Splitting your configuration into NixOS and Home Manager modules. These modules are then put into different files, even though they may be semantically related.
- All flake inputs must be in flake.nix.

Combined Manager breaks this pattern by providing modules that can add inputs, import NixOS and Home Manager modules, and define Home Manager and NixOS options.

## Module structure
```nix
{
  lib,
  inputs,
  pkgs,
  useHm, # Whether the current configuration uses Home Manager
  options,
  osOptions,
  hmOptions,
  configs, # The results of all NixOS/CombinedManager configurations
  config,
  osConfig,
  hmConfig,
  combinedManager, # The root of CombinedManager
  ...
}: {
  inputs = { name.url = "..."; }; # Add inputs

  imports = [ ];
  osImports = [ ]; # Import NixOS modules
  hmImports = [ ]; # Import Home Manager modules

  options = { }; # Declare Combined Manager options

  config = {
    inputs = { name.url = "..."; }; # You can also add inputs here

    osModules = [ ]; # You can also import NixOS modules here
    hmModules = [ ]; # You can also import Home Manager modules here

    os = { }; # Define NixOS options

    hmUsername = "myname"; # Set the Home Manager username (must be defined if Home Manager is enabled for this configuration)

    hm = { }; # Define Home Manager options
  };
}
```

## Current limitations
- Only a single user supported when using Home Manager
- Requires Nix to be patched
- For NixOS configurations with flakes only

## Getting started
1. Patch Nix with the patches in the `nix-patches` directory. See more in the [patching nix section](#nix-patches).
2. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example`.
3. Start using Combined Manager!

## Stability
At the time of writing, stable _enough_.
While I'm using it for my configuraiton, I haven't tested everything and can't guarantee stability.
There may be breaking changes.

## Examples
#### Full configurations
- https://github.com/FlafyDev/nixos-config
#### Modules
- https://github.com/FlafyDev/nixos-config/blob/main/modules/display/hyprland/default.nix

## Patching Nix
Because Combined Manager allows flake inputs to be distributed across multiple modules, which [Nix doesn't support](https://github.com/NixOS/nix/issues/3966), it requires Nix to be patched.
You can use the patches provided by this project, or alternatively use [Nix Super](https://github.com/privatevoid-net/nix-super).

#### Applying patches to Nix
You can add the following to your NixOS config:

```nix
nix = {
  package = let
    combinedManager = pkgs.fetchFromGitHub {
      owner = "flafydev";
      repo = "combined-manager";
      rev = "9474a2432b47c0e6fa0435eb612a32e28cbd99ea";
      sha256 = "";
    };
  in
    pkgs.nix.overrideAttrs (old: {
      patches =
        old.patches or []
        ++ (
          map
          (file: "${combinedManager}/nix-patches/${file}")
          (lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir "${combinedManager}/nix-patches")))
        );
    });
};
```

Once you start using Combined Manager, you'll be able to source the patches directly from your `combinedManager` module arg.
