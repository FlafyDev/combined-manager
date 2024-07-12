{
  lockFile,
  initialInputs ? { },
  configurations,
  ...
}@args:
let
  lib = import ./lib.nix lockFile;
in
with lib;
let
  modifiedLib = import ./modified-lib.nix lib;

  initialInputsWithLocation = optional (initialInputs != { }) {
    file = (builtins.unsafeGetAttrPos "initialInputs" args).file;
    value = initialInputs;
  };

  directConfigModules = foldlAttrs (
    modules: _: config:
    modules ++ config.modules
  ) [ ] configurations;
  configModules = modifiedLib.collectModules "combinedManager" "" directConfigModules {
    inherit lib;
    options = null;
    config = null;
  };
  configInputs = foldl (
    modules: module:
    let
      findInputs =
        x:
        if x ? inputs then
          x.inputs
        else if x ? content then
          findInputs x.content
        else
          [ ];
      inputs = findInputs module.config;
    in
    modules
    ++ optional (inputs != [ ]) {
      file = module._file;
      value = inputs;
    }
  ) [ ] configModules;

  inputDefs = initialInputsWithLocation ++ configInputs;
  typeCheckedInputDefs =
    let
      wrongTypeDefs = filter (def: builtins.typeOf def.value != "set") inputDefs;
    in
    if wrongTypeDefs == [ ] then
      inputDefs
    else
      throw "A definition for option `inputs' is not of type `attribute set of raw value'. Definition values:${options.showDefs wrongTypeDefs}";

  uncheckedInputs = foldl (inputs: def: inputs // def.value) { } typeCheckedInputDefs;
in
foldlAttrs (
  inputs: inputName: _:
  let
    defs = foldl (
      defs: def:
      defs
      ++ (optional (def.value ? ${inputName}) {
        file = def.file;
        value = def.value.${inputName};
      })
    ) [ ] typeCheckedInputDefs;
    firstDef = head defs;
    areDefsEqual = all (def: firstDef.value == def.value) defs;
  in
  if areDefsEqual then
    inputs
  else
    throw "The input `${inputName}' has conflicting definition values:${options.showDefs defs}"
) uncheckedInputs uncheckedInputs
