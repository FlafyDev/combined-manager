# Combined Manager
Combined Manager provides a new structure for personal NixOS configurations.
###### Note: Requires patching `nix` to solve [this issue](https://github.com/NixOS/nix/issues/3966). See more in the [patching Nix section](#patching-nix).

- [Introduction](#introduction-no-separation)
- [Module structure](#module-structure)
- [Option copying](#option-copying)
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
  configs, # The results of all NixOS / Combined Manager configurations
  config,
  osConfig,
  hmConfig,
  combinedManager, # The root of Combined Manager
  combinedManagerPath, # Path to the root of Combined Manager
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

## Option copying
When declaring options for your Combined Manager modules, sometimes you just want to copy a NixOS or Home Manager option. Combined Manager makes this easy and straightforward, even when working with `attrsOf` and submodules. Below is an example impermanence module that makes use of this feature. Note that the options being copied are complex, so you wouldn't want to just copy and paste them into your option declarations.
```nix
{
  lib,
  inputs,
  osOptions,
  hmOptions,
  ...
}:
{
  inputs.impermanence.url = "github:nix-community/impermanence";

  osImports = [ inputs.impermanence.nixosModules.impermanence ];
  hmImports = [ inputs.impermanence.nixosModules.home-manager.impermanence ];

  options.impermanence =
    let
      os = osOptions.environment.persistence "/persist/system";
      hm = hmOptions.home.persistence "/persist/home";
    in
    {
      enable = lib.mkEnableOption "impermanence";
      os = {
        inherit (os) files directories; # Copy the `files` and `directories` options that you would define at `os.environment.persistence."/persist/system"`
      };
      hm = {
        inherit (hm) files directories; # Copy the `files` and `directories` options that you would define at `hm.home.persistence."/persist/home"`
      };
    };
}
```

## Current limitations
- Only a single user supported when using Home Manager
- Requires Nix to be patched
- For NixOS configurations with flakes only

## Getting started
1. Patch Nix with the `evaluable-flake.patch` patch. See more in the [patching nix section](#patching-nix).
2. Use one of our flake templates with `nix flake init -t github:FlafyDev/combined-manager#example`, or have a look at an example to see how to use Combined Manager.
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
You can use the patch provided by this project, or alternatively use [Nix Super](https://github.com/privatevoid-net/nix-super).

#### Applying the patch to Nix
To apply the Nix patch provided by this project, add the following to your NixOS configuration:
```nix
nix.package = pkgs.nix.overrideAttrs (old: {
  patches = old.patches or [ ] ++ [
    (pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/flafydev/combined-manager/main/evaluable-flake.patch";
      hash = "sha256-UZ5hXI1w1mOEe0Bp5rSfeB4jfnwxnNEXJWir4dQGyyo=";
    })
  ];
});
```
Once you're using Combined Manager, you can get the patch using the `combinedManagerPath` module arg:
```nix
nix.package = pkgs.nix.overrideAttrs (old: {
  patches = old.patches or [ ] ++ [ "${combinedManagerPath}/evaluable-flake.patch" ];
});
