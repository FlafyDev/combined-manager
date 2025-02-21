# Combined Manager
Combined Manager provides a new structure for personal NixOS configurations.
###### Note: Requires patching `nix` to solve [this issue](https://github.com/NixOS/nix/issues/3966). See more in the [Nix Patches section](#nix-patches).

- [Introduction](#introduction-no-separation)  
- [Module options](#module-options)  
- [Examples](#examples)  
    - [Full configurations](#full-configurations)  
    - [Modules](#modules)  
- [Current limitations](#examples)  
- [Stability](#stability)  
- [Setup](#setup)  
- [Nix Patches](#nix-patches)
  - [evaluable-flake.patch](#required-evaluable-flakepatch-2-line-diff)
- [FAQ](#faq)
  - [I want to get started, but don’t know how to patch Nix.](#i-want-to-get-started-but-dont-know-how-to-patch-nix)
  - [Why does Combined Manager need to evaluate inputs?](#why-does-combined-manager-need-to-evaluate-inputs)

## Introduction: No separation
Combined Manager's main feature is to break separation. If you want, you should be able to keep everything in a single module.  
Most NixOS configuration structures are designed to separate related things into multiple files.  

Most prominent separations:  
- Dividing modules into system and home categories. These categories are then further maintained in separate files.
- All flake inputs must be in the same file in flake.nix.

Combined Manager breaks this pattern by allowing modules to add inputs, overlays and Home Manager and Nixpkgs options as if they are simple options.

## Module Options
```nix
{
  lib,
  pkgs,
  config,
  osConfig,
  hmConfig,
  inputs,
  combinedManager, # Path to the root of combinedManager
  configs, # The results of all NixOS/CombinedManager configurations
  ...
}: {
  imports = [ ];

  options = { };

  config = {
    # Adding inputs.
    inputs = { name.url = "..."; };

    # Importing system modules.
    osModules = [ ];

    # Importing Home Manager modules.
    hmModules = [ ];

    # Setting overlays.
    os.nixpkgs.overlays = [ ];

    # Using `os` to set Nixpkgs options.
    os = { };

    # Set Home Manager username (Required to be set in at least one of the modules).
    hmUsername = "myname";

    # Using `hm` to set Home Manager options.
    hm = { };
  };
}
```

## Examples
#### Full configurations
- https://github.com/FlafyDev/nixos-config
#### Modules
- https://github.com/FlafyDev/nixos-config/blob/main/modules/display/hyprland/default.nix


## Current limitations
- Home Manager required and only a single user with Home Manager.
- Nix must be patched. 
- Only for NixOS.

## Stability
As of the time of writing, stable _enough_.  
While I'll use it for my configuraiton, I have not tested everything and cannot guarantee stability.  
There might be breaking changes.

## Setup
1. Patch Nix with the patches in the `nix-patches` directory. See more in the [Nix Patches section](#nix-patches).
2. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example`.
3. Run `nix flake metadata`. You might need to run it twice if there is no `flake.lock` file(A message will appear).

##### Running
To bulid a VM: `nixos-rebuild build-vm --flake .#default`.  
To swtich: `sudo nixos-rebuild switch --flake .#default`.  


## Nix Patches 
Combined Manager requires applying certain patches to Nix in order to work.  
Alternatively, you can use [Nix Super](https://forge.privatevoid.net/max/nix-super).  

#### Required: evaluable-flake.patch (2 line diff)
This patch enables inputs(and the entire flake) to be evaluable. Solves [issue #3966](https://github.com/NixOS/nix/issues/3966).  
Combined Manager requires this since it evaluates `inputs` from all the modules.  

See [line 9 of the example flake](https://github.com/FlafyDev/combined-manager/blob/9474a2432b47c0e6fa0435eb612a32e28cbd99ea/templates/example/flake.nix#L9).  

## FAQ

#### I want to get started, but don't know how to patch Nix.
You can add the following to your config:

```nix
nix = {
  enable = true;
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
        (old.patches or [])
        ++ (
          map
          (file: "${combinedManager}/nix-patches/${file}")
          (lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir "${combinedManager}/nix-patches")))
        );
    });
};
```

Once you start using Combined Manager, you'll be able to source the patches directly from your `combinedManager` module arg.

#### Why does Combined Manager need to evaluate inputs?
Each Combined Manager module has an `inputs` option. That option will eventually be merged and set as the inputs of the NixOS configuration.

