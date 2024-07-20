# Combined Manager
Combined Manager provides a new structure for personal NixOS configurations.
###### Note: Requires patching `nix` to solve [this issue](https://github.com/NixOS/nix/issues/3966). See more in the [patching Nix section](#patching-nix).

- [Introduction](#introduction-no-separation)
- [Module structure](#module-structure)
- [Accessing option declarations](#accessing-option-declarations)
- [Flake structure](#flake-structure)
- [Automatic updates](#automatic-updates)
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
  osOptions, # For [accessing NixOS option declarations](#accessing-option-declarations)
  hmOptions, # For [accessing Home Manager option declarations](#accessing-option-declarations)
  configs, # The results of all NixOS / Combined Manager configurations
  config,
  osConfig, # NixOS config
  hmConfig, # Home Manager config
  combinedManager, # The root of Combined Manager
  combinedManagerPath, # Path to the root of Combined Manager
  ...
}: {
  inputs = {name.url = "...";}; # Add inputs

  imports = [];
  osImports = []; # Import NixOS modules
  hmImports = []; # Import Home Manager modules

  options = {}; # Declare Combined Manager options

  config = {
    inputs = {name.url = "...";}; # You can also add inputs here

    osModules = []; # You can also import NixOS modules here
    hmModules = []; # You can also import Home Manager modules here

    os = {}; # Define NixOS options

    hmUsername = "myname"; # Set the Home Manager username (must be defined if Home Manager is enabled for this configuration)

    hm = {}; # Define Home Manager options
  };
}
```

## Accessing option declarations
The module system supports creating renamed options or creating aliases of options using functions like `mkRenamedOptionModule` or `mkAliasOptionModule`, but otherwise it is very hard to access option types or default values for more advanced use cases, as extracting them from the `options` arg is quite hard. An example of such a use case would be copying an option and changing the description, adding a default value, or slightly changing the type. If you need to conditionally include definitions, or generally reuse parts of an option declaration without simply forwarding definitions, you are out of luck using the module system.
Combined Manager makes it easy and straightforward to access option declarations, even when working with types like `attrsOf` and submodules. It does this through the `osOptions` and `hmOptions` args. For example, the declaration for the option whose configuration you would access with `os.some.option.path.submodule.name.option` can be accessed with `(osOptions.some.option.path"name").option`.

## Flake structure
```nix
let
  combinedManager = import (builtins.fetchTarball {
    url = "https://github.com/flafydev/combined-manager/archive/REV.tar.gz"; # Replace REV with the current revision of Combined Manager.
    sha256 = "HASH"; # Replace HASH with the corresponding hash.
  });
in
  combinedManager.mkFlake {
    description = "My flake description"; # Optional, defaults to "NixOS configuration"
    lockFile = ./flake.lock;

    initialInputs = {}; # Optional

    # These set defaults that can be overridden per config.
    defaultSystem = "x86_64-linux"; # Must be specifieed either here or once per config.
    useHomeManager = true; # Defaults to true.

    # These are merged with the attributes specified per config. They are all optional.
    globalSpecialArgs = {};
    globalModules = [];
    globalOsModules = [];
    globalHmModules = [];

    # The NixOS configurations managed by Combined Manager.
    configurations = {
      primary = {
        # Attributes from the attrset created by this function override the normal inputs.
        # This can be used to override an input for a shared module on a per-configuration basis.
        inputOverrides = inputs: {}; # Optional

        system = "x86_64-linux"; # Only optional if defaultSystem is defined.
        useHomeManager = true; # If undefined, the mkFlake useHomeManager attribute is used, which defaults to true.

        specialArgs = {}; # The attributes defined in this attrset are passed to all Combined Manager, NixOS and Home Manager modules, in addition to the default args.

        # Add root Combined Manager, NixOS and home manager modules. These attributes are all optional.
        modules = [];
        osModules = [];
        hmModules = [];
      };

      # You can define as many configurations as you like.
      other = {};
    };

    outputs = {self, ...} @ inputs: {}; # Like normal flake outputs. They're optional, but if they are defined, they'll be merged with the nixosConfigurations created by Combined Manager.
  }
```

## Automatic updates
The following is an example of a `flake.nix` that automatically updates Combined Manager by specifying it as a flake input.
Note that you must already have Combined Manager in your `flake.lock` for this to work, so make sure you add it as an input and run `nix flake metadata` before updating your `flake.nix`.
If you accidentally delete `flake.lock`, you will need to hardcode `rev` and `narHash` before regenerating it, as the input evaluation relies on Combined Manager.
```nix
let
  inherit ((builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.combined-manager.locked) rev narHash;
  combinedManager = import (
    builtins.fetchTarball {
      url = "https://github.com/Noah765/combined-manager/archive/${rev}.tar.gz";
      sha256 = narHash;
    }
  );
in
  combinedManager.mkFlake {
    lockFile = ./flake.lock;
    configurations = {};
  }
```

## Current limitations
- Only a single user supported when using Home Manager
- Requires Nix to be patched
- For NixOS configurations with flakes only

## Getting started
1. Patch Nix with one of the patches in the `nix-patches` directory. See more in the [patching nix section](#patching-nix).
2. Use one of our flake templates with `nix flake init -t github:FlafyDev/combined-manager#example`, create your own using the docs, or take a look at an example to see a complete configuration using Combined Manager.
3. See how Combined Manager can make your configuration cleaner!

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
You can use one of the patches provided by this project, or alternatively use [Nix Super](https://github.com/privatevoid-net/nix-super).

#### Applying a patch to Nix
To apply the correct patch for the version of Nix on the unstable branch, add the following to your NixOS configuration:
```nix
nix.package = pkgs.nix.overrideAttrs (old: {
  patches =
    old.patches
    or []
    ++ [
      (pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/flafydev/combined-manager/main/nix-patches/evaluable-flake.patch";
        hash = "HASH"; # Replace HASH with the hash of the patch you patch you want to apply.
      })
    ];
});
```
Once you're using Combined Manager, you can get the patch using the `combinedManagerPath` module arg:
```nix
nix.package = pkgs.nix.overrideAttrs (old: {
  patches = old.patches or [] ++ ["${combinedManagerPath}/nix-patches/evaluable-flake.patch"];
});
```
