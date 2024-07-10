args:
let
  lib = import ./lib args;

  initialInputsWithLocation = lib.singleton {
    file = (builtins.unsafeGetAttrPos "initialInputs" args).file;
    value = args.initialInputs;
  };

  directConfigModules = lib.foldlAttrs (
    modules: _: config:
    modules ++ config.modules
  ) [ ] args.configurations;
  configModules = lib.modules.collectModules null "" directConfigModules {
    inherit lib;
    options = null;
    config = null;
  };
  configInputs = lib.foldl (
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
    ++ lib.optional (inputs != [ ]) {
      file = module._file;
      value = inputs;
    }
  ) [ ] configModules;

  inputDefs = initialInputsWithLocation ++ configInputs;
  typeCheckedInputDefs =
    let
      wrongTypeDefs = lib.filter (def: builtins.typeOf def.value != "set") inputDefs;
    in
    if wrongTypeDefs == [ ] then
      inputDefs
    else
      throw "A definition for option `inputs' is not of type `attribute set of raw value'. Definition values:${lib.options.showDefs wrongTypeDefs}";

  uncheckedInputs = lib.foldl (inputs: def: inputs // def.value) { } typeCheckedInputDefs;
in
lib.foldlAttrs (
  inputs: inputName: _:
  let
    defs = lib.foldl (
      defs: def:
      defs
      ++ (lib.optional (def.value ? ${inputName}) {
        file = def.file;
        value = def.value.${inputName};
      })
    ) [ ] typeCheckedInputDefs;
    firstDef = lib.head defs;
    areDefsEqual = lib.all (def: firstDef.value == def.value) defs;
  in
  if areDefsEqual then
    inputs
  else
    throw "The input `${inputName}' has conflicting definition values:${lib.options.showDefs defs}"
) uncheckedInputs uncheckedInputs
