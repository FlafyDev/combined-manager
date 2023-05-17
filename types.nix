{lib}: let
  inherit
    (lib)
    isAttrs
    mkOptionType
    ;
  inherit
    (lib.lists)
    foldl'
    head
    ;
  inherit
    (lib.options)
    getFiles
    mergeEqualOption
    mergeOneOption
    showFiles
    showOption
    ;
  inherit
    (lib.types)
    attrsOf
    listOf
    ;
  inherit (lib.strings) isStringLike;
in rec {
  anything = mkOptionType {
    name = "anything";
    description = "anything";
    descriptionClass = "noun";
    check = value: true;
    merge = loc: defs: let
      getType = value:
        if isAttrs value && isStringLike value
        then "stringCoercibleSet"
        else builtins.typeOf value;

      # Returns the common type of all definitions, throws an error if they
      # don't have the same type
      commonType =
        foldl' (
          type: def:
            if getType def.value == type
            then type
            else throw "The option `${showOption loc}' has conflicting option types in ${showFiles (getFiles defs)}"
        ) (getType (head defs).value)
        defs;

      mergeFunction =
        {
          # Recursively merge attribute sets
          set = (attrsOf anything).merge;
          # Safe and deterministic behavior for lists is to only accept one definition
          # listOf only used to apply mkIf and co.
          list = (listOf anything).merge;
          # This is the type of packages, only accept a single definition
          stringCoercibleSet = mergeOneOption;
          lambda = loc: defs: arg:
            anything.merge
            (loc ++ ["<function body>"])
            (map (def: {
                file = def.file;
                value = def.value arg;
              })
              defs);
          # Otherwise fall back to only allowing all equal definitions
        }
        .${commonType}
        or mergeEqualOption;
    in
      mergeFunction loc defs;
  };
}
