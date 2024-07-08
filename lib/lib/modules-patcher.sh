#!/bin/sh
$cp -r $src/. .
$patch -p2 < $patchFile
$cp -r . $out
