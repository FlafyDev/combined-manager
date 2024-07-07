# The functions in this file have been copied from https://github.com/NixOS/nixpkgs/blob/4eb6883b860e99ecb6cd17eba63fb5a806f5f18a/lib/modules.nix to avoid a warning when using internal functions. Go there for additional comments explaining the functions.
lib:
with lib;
let
  unifyModuleSyntax =
    file: key: m:
    let
      addMeta =
        config:
        if m ? meta then
          mkMerge [
            config
            { meta = m.meta; }
          ]
        else
          config;
      addFreeformType =
        config:
        if m ? freeformType then
          mkMerge [
            config
            { _module.freeformType = m.freeformType; }
          ]
        else
          config;
    in
    if m ? config || m ? options then
      let
        badAttrs = removeAttrs m [
          "_class"
          "_file"
          "key"
          "disabledModules"
          "imports"
          "options"
          "config"
          "meta"
          "freeformType"
        ];
      in
      if badAttrs != { } then
        throw "Module `${key}' has an unsupported attribute `${head (attrNames badAttrs)}'. This is caused by introducing a top-level `config' or `options' attribute. Add configuration attributes immediately on the top level instead, or move all of them (namely: ${toString (attrNames badAttrs)}) into the explicit `config' attribute."
      else
        {
          _file = toString m._file or file;
          _class = m._class or null;
          key = toString m.key or key;
          disabledModules = m.disabledModules or [ ];
          imports = m.imports or [ ];
          options = m.options or { };
          config = addFreeformType (addMeta (m.config or { }));
        }
    else
      throwIfNot (isAttrs m) "module ${file} (${key}) does not look like a module." {
        _file = toString m._file or file;
        _class = m._class or null;
        key = toString m.key or key;
        disabledModules = m.disabledModules or [ ];
        imports = m.require or [ ] ++ m.imports or [ ];
        options = { };
        config = addFreeformType (
          removeAttrs m [
            "_class"
            "_file"
            "key"
            "disabledModules"
            "require"
            "imports"
            "freeformType"
          ]
        );
      };

  applyModuleArgsIfFunction =
    key: f: args@{ config, ... }: if isFunction f then applyModuleArgs key f args else f;

  applyModuleArgs =
    key: f:
    args@{ config, ... }:
    let
      context = name: ''while evaluating the module argument `${name}' in "${key}":'';
      extraArgs = mapAttrs (
        name: _: addErrorContext (context name) (args.${name} or config._module.args.${name})
      ) (functionArgs f);
    in
    f (args // extraArgs);
in
class:
let
  loadModule =
    args: fallbackFile: fallbackKey: m:
    if isFunction m then
      unifyModuleSyntax fallbackFile fallbackKey (applyModuleArgs fallbackKey m args)
    else if isAttrs m then
      if m._type or "module" == "module" then
        unifyModuleSyntax fallbackFile fallbackKey m
      else if m._type == "if" || m._type == "override" then
        loadModule args fallbackFile fallbackKey { config = m; }
      else
        throw (
          "Could not load a value as a module, because it is of type ${lib.strings.escapeNixString m._type}"
          + optionalString (fallbackFile != unknownModule) ", in file ${toString fallbackFile}."
          +
            optionalString (m._type == "configuration")
              " If you do intend to import this configuration, please only import the modules that make up the configuration. You may have to create a `let` binding, file or attribute to give yourself access to the relevant modules.\nWhile loading a configuration into the module system is a very sensible idea, it can not be done cleanly in practice."
        )
    else if isList m then
      let
        defs = [
          {
            file = fallbackFile;
            value = m;
          }
        ];
      in
      throw "Module imports can't be nested lists. Perhaps you meant to remove one level of lists? Definitions: ${showDefs defs}"
    else
      unifyModuleSyntax (toString m) (toString m) (
        applyModuleArgsIfFunction (toString m) (import m) args
      );

  checkModule =
    if class != null then
      m:
      if m._class != null -> m._class == class then
        m
      else
        throw "The module ${m._file or m.key} was imported into ${class} instead of ${m._class}."
    else
      m: m;

  collectStructuredModules =
    let
      collectResults = modules: {
        disabled = concatLists (catAttrs "disabled" modules);
        inherit modules;
      };
    in
    parentFile: parentKey: initialModules: args:
    collectResults (
      imap1 (
        n: x:
        let
          module = checkModule (loadModule args parentFile "${parentKey}:anon-${toString n}" x);
          collectedImports = collectStructuredModules module._file module.key module.imports args;
        in
        {
          key = module.key;
          module = module;
          modules = collectedImports.modules;
          disabled =
            (
              if module.disabledModules != [ ] then
                [
                  {
                    file = module._file;
                    disabled = module.disabledModules;
                  }
                ]
              else
                [ ]
            )
            ++ collectedImports.disabled;
        }
      ) initialModules
    );

  filterModules =
    modulesPath:
    { disabled, modules }:
    let
      moduleKey =
        file: m:
        if isString m then
          if substring 0 1 m == "/" then m else toString modulesPath + "/" + m
        else if isConvertibleWithToString m then
          if m ? key && m.key != toString m then
            throw "Module `${file}` contains a disabledModules item that is an attribute set that can be converted to a string (${toString m}) but also has a `.key` attribute (${m.key}) with a different value. This makes it ambiguous which module should be disabled."
          else
            toString m
        else if m ? key then
          m.key
        else if isAttrs m then
          throw "Module `${file}` contains a disabledModules item that is an attribute set, presumably a module, that does not have a `key` attribute. This means that the module system doesn't have any means to identify the module that should be disabled. Make sure that you've put the correct value in disabledModules: a string path relative to modulesPath, a path value, or an attribute set with a `key` attribute."
        else
          throw "Each disabledModules item must be a path, string, or a attribute set with a key attribute, or a value supported by toString. However, one of the disabledModules items in `${toString file}` is none of that, but is of type ${typeOf m}.";
      disabledKeys = concatMap ({ file, disabled }: map (moduleKey file) disabled) disabled;
      keyFilter = filter (attrs: !elem attrs.key disabledKeys);
    in
    map (attrs: attrs.module) (genericClosure {
      startSet = keyFilter modules;
      operator = attrs: keyFilter attrs.modules;
    });
in
modulesPath: initialModules: args:
filterModules modulesPath (collectStructuredModules unknownModule "" initialModules args)
