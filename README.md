# combined-manager
**VERY WIP** Nix config structure

## Current limitations
- Only a single users with home-manager.
- home-manager required.
- Need to patch nix. (1 line diff)
- Only NixOS.
- Need to call `nix flake` commands with `?submodules=1`.

## Setup
0. Patch Nix with the patches in the `nix-patches` directory.
1. Generate a template with `nix flake init -t github:FlafyDev/combined-manager#example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Run `git add .`
4. Run `nix flake metadata ".?submodules=1"` twice if there is no `flake.lock` file ().

## Running
To bulid a VM: `nixos-rebuild build-vm --flake ".?submodules=1"#default`.
