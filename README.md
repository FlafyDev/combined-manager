# combined-manager
**VERY WIP** Nix config structure

## Current limitations
- Only a single users with home-manager.
- home-manager required.
- Need to patch nix. (1 line diff)
- Only NixOS.
- Need to call `nix flake` commands with `?submodules=1`.

## Setup
1. Generate a template with `nix flake init -t TODO#templates.example` into a git repository.
2. Run `git submodule add git@github.com:FlafyDev/combined-manager.git`
3. Patch Nix with the Combined Manager patchset.
4. Run `nix flake metadata "git+file://$(pwd)?submodules=1"` twice if there is no `flake.lock` file ().

## Running
To bulid a VM: `nixos-rebuild build-vm --flake "git+file://$(pwd)?submodules=1"#default`.
