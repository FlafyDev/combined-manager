# combined-manager
Nix config structure

Combined Manager allows to configure flake inputs, overlays, and home/system configuration inside modules.
The idea is to avoid separating configurations that relate to the same thing in different files.

## Module options
Like any module, but with the added options:
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

    # Adding top level system modules
    osModules = [ ];

    # Adding home modules
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

## Usage in Nix configs
- https://github.com/FlafyDev/nixos-config

## Current limitations
- Only a single users with Home Manager.
- Home Manager required.
- Nix must be patched for input evaluation. (1 line diff)
- Only for NixOS.
- Need to call `nix flake` commands with `?submodules=1`.

## Stability
As of the time of writing, stable _enough_.  
While I'll use it for my configuraiton, I have not tested everything and cannot guarantee stability.  
Expect breaking changes.

## Setup
0. Patch Nix with the patches in the `nix-patches` directory.
1. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Run `git add .`
4. Run `nix flake metadata ".?submodules=1"` twice if there is no `flake.lock` file ().

## Running
To bulid a VM: `nixos-rebuild build-vm --flake ".?submodules=1"#default`.
To swtich: `sudo nixos-rebuild switch --flake ".?submodules=1"#default`.
