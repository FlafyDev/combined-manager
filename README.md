# Combined Manager
Combined Manager provides a new structure for personal NixOS configurations.
###### Note: Requires patching `nix` to solve [this issue](https://github.com/NixOS/nix/issues/3966). See more in the [Setup section](#setup).

## No separation
Combined Manager's main feature is to break separation. If you want, you should be able to keep everything in a single module.  
Most NixOS configuration structures are designed to separate related things into multiple files.  

Most prominent separations:  
- Dividing modules into system and home categories. These categories are then further maintained in separate files.
- All flake inputs must be in the same file in flake.nix.

Combined Manager breaks this pattern by allowing modules to add inputs, overlays and Home Manager and Nixpkgs options as if they are simple options.

## Module options
```nix
{
  lib,
  pkgs,
  osConfig,
  hmConfig,
  inputs,
  ...
}: {
  config = {
    # Adding inputs
    inputs = { name.url = "..."; };

    # Importing system modules
    osModules = [ ];

    # Importing Home Manager modules
    hmModules = [ ];

    # Setting overlays
    os.nixpkgs.overlays = [ ];

    # Using `os` to set Nixpkgs options.
    os = { };

    # Set Home Manager username
    hmUsername = username;

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
- Nix must be patched for input evaluation. (1 line diff)
- Only for NixOS.
- Need to call `nix flake` commands with `?submodules=1`.

## Stability
As of the time of writing, stable _enough_.  
While I'll use it for my configuraiton, I have not tested everything and cannot guarantee stability.  
There might be breaking changes.

## Setup
0. Patch Nix with the patches in the `nix-patches` directory. Or use [Nix Super](https://git.privatevoid.net/max/nix-super) (Nix Super was not tested with Combined Manager)
1. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Run `git add .`
4. Run `nix flake metadata ".?submodules=1"` twice if there is no `flake.lock` file ().

## Running
To bulid a VM: `nixos-rebuild build-vm --flake ".?submodules=1"#default`.
To swtich: `sudo nixos-rebuild switch --flake ".?submodules=1"#default`.
