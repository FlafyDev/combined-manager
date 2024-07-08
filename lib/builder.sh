#!/bin/sh
$mkdir $out
$patch -p1 -d $nixpkgsSrc -i $patchFile -o $out/modules.nix
