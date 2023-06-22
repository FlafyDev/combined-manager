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
  - [evaluable-inputs.patch](#required-evaluable-inputspatch-1-line-diff)
  - [default-submodules-flag.patch](#recommended-default-submodules-flagpatch-1-line-diff)
- [FAQ](#faq)
  - [I want to get started, but don’t know how to patch Nix.](#i-want-to-get-started-but-dont-know-how-to-patch-nix)
  - [Why does Combined Manager need to evaluate inputs?](#why-does-combined-manager-need-to-evaluate-inputs)
  - [Why does Combined Manager need to be added as a submodules? Why not import it as a flake?](#why-does-combined-manager-need-to-be-added-as-a-submodules-why-not-import-it-as-a-flake)

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
0. Patch Nix with the patches in the `nix-patches` directory. See more in the [Nix Patches section](#nix-patches).
1. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Run `git add .`
4. Run `nix flake metadata ".?submodules=1"` twice if there is no `flake.lock` file.

##### Running
To bulid a VM: `nixos-rebuild build-vm --flake ".?submodules=1"#default`.  
To swtich: `sudo nixos-rebuild switch --flake ".?submodules=1"#default`.  


## Nix Patches 
Combined Manager requires applying certain patches to Nix in order to work.  
You can also use use [Nix Super](https://git.privatevoid.net/max/nix-super), but it doesn't have `default-submodules-flag.patch`.  

#### Required: evaluable-inputs.patch (1 line diff)
This patch makes enabled inputs to be evaluable. Solves [issue #3966](https://github.com/NixOS/nix/issues/3966).  
Combined Manager requires this since it evaluates `inputs` from all the modules.  

See [line 4 of the example flake](https://github.com/FlafyDev/combined-manager/blob/cf13c190cd51cb2d2e408c8bb3ba8398bc9c568c/templates/example/flake.nix#L4).  

This patch is available in nix-super.

#### Recommended: default-submodules-flag.patch (1 line diff)
This patch enables the submodules flag for flake git urls by default.  

If your config uses Combined Manager, you have to add it as a submodule to your config's repository.  
That means that for every nix flake command you do on the repository, you have to append `".?submodules=1"`.  

This patch removes the need to append that.

This patch is NOT available in nix-super.
You'll have to add this patch to nix-super yourself if you want to enable the submodules flag by default.

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
      rev = "8553bc2051f8228a881b186ce5bb73b5bdbfadf1";
      sha256 = "sha256-LmIYSpDNBBax5wA0QWYN0lPzULOoA8mIa5I7HGoZNdE=";
    };
  in
    pkgs.nix.overrideAttrs (old: {
      patches =
        (old.patches or [])
        ++ (
          map
          (file: "${combinedManager}/nix-patches/${file}")
          (lib.attrNames (builtins.readDir "${combinedManager}/nix-patches"))
        );
    });
};
```

Once you start using Combined Manager, you'll be able to source the patches directly from the submodule.
```nix
nix = {
  enable = true;
  package = pkgs.nix.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ (
        map
        (file: "${../../combined-manager/nix-patches}/${file}")
        (lib.attrNames (builtins.readDir ../../combined-manager/nix-patches))
      );
  });
};
```

#### Why does Combined Manager need to evaluate inputs?
Each Combined Manager module has an `inputs` option. That option will eventually be merged and set as the inputs of the NixOS configuration.

#### Why does Combined Manager need to be added as a submodules? Why not import it as a flake?
Combined Manager's functions need to also be called in the flake's `inputs`.
If Combined Manager was to be imported as a flake input, it wouldn't be possible to call its functions from the flake's `inputs`.  

See [line 7 of the example flake](https://github.com/FlafyDev/combined-manager/blob/cf13c190cd51cb2d2e408c8bb3ba8398bc9c568c/templates/example/flake.nix#LL7C4-L7C4).

#### Can't `nix flake show` a Combined Manager config from Github.
`nix flake show "github:flafydev/nixos-config"` will download an archive of the nixos-config repository from Github.  
And because [Github archives do not provide submodules](https://github.com/dear-github/dear-github/issues/214), nix will not be able to evaluate this repository as it is missing the combined-manager submodule.

As a workaround, do `nix flake show "git+https://github.com/FlafyDev/nixos-config.git?submodules=1"` instead.

#### I don't want to add combined-manager as a submodule, are there any other options?
Yes.  
One option would be to add combined-manager as a git subtree instead.
