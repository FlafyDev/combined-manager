# combined-manager
**VERY WIP** Nix config structure

Combined Manager allows to configure flake inputs, overlays, and home/system configuration inside modules.
The idea is to avoid separating configurations that relate to the same thing in different files.

## Usage in Nix configs
- 

## Current limitations
- Only a single users with home-manager.
- home-manager required.
- Need to patch nix. (1 line diff)
- Only NixOS.
- Need to call `nix flake` commands with `?submodules=1`.

## Stability
As of the time of writing, not very stable.  
I've creating this a few days ago and have encountered many weird behaviours(that I've already fixed them).  
So while I'll use it for my configuraiton, I have not tested everything and cannot guarantee stability.  

Expect breaking changes often.

## Setup
0. Patch Nix with the patches in the `nix-patches` directory.
1. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Run `git add .`
4. Run `nix flake metadata ".?submodules=1"` twice if there is no `flake.lock` file ().

## Running
To bulid a VM: `nixos-rebuild build-vm --flake ".?submodules=1"#default`.
