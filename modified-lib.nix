# The following functions have been copied and modified from nixpkgs, which is licensed under:
#
# Copyright (c) 2003-2024 Eelco Dolstra and the Nixpkgs/NixOS contributors
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
lib:
with lib; let
  inherit (lib.options) showDefs;

  /*
  See https://nixos.org/manual/nixpkgs/unstable/#module-system-lib-evalModules
    or file://./../doc/module-system/module-system.chapter.md

    !!! Please think twice before adding to this argument list! The more
    that is specified here instead of in the modules themselves the harder
    it is to transparently move a set of modules to be a submodule of another
    config (as the proper arguments need to be replicated at each call to
    evalModules) and the less declarative the module set is.
  */
  evalModules = evalModulesArgs @ {
    modules,
    prefix ? [],
    # This should only be used for special arguments that need to be evaluated
    # when resolving module structure (like in imports). For everything else,
    # there's _module.args. If specialArgs.modulesPath is defined it will be
    # used as the base path for disabledModules.
    specialArgs ? {},
    # `class`:
    # A nominal type for modules. When set and non-null, this adds a check to
    # make sure that only compatible modules are imported.
    class ? null,
    # This would be remove in the future, Prefer _module.args option instead.
    args ? {},
    # This would be remove in the future, Prefer _module.check option instead.
    check ? true,
  }: let
    withWarnings = x:
      warnIf (evalModulesArgs ? args)
      "The args argument to evalModules is deprecated. Please set config._module.args instead."
      warnIf
      (evalModulesArgs ? check)
      "The check argument to evalModules is deprecated. Please set config._module.check instead."
      x;

    legacyModules =
      optional (evalModulesArgs ? args) {
        config = {
          _module.args = args;
        };
      }
      ++ optional (evalModulesArgs ? check) {
        config = {
          _module.check = mkDefault check;
        };
      };
    regularModules = modules ++ legacyModules;

    # This internal module declare internal options under the `_module'
    # attribute.  These options are fragile, as they are used by the
    # module system to change the interpretation of modules.
    #
    # When extended with extendModules or moduleType, a fresh instance of
    # this module is used, to avoid conflicts and allow chaining of
    # extendModules.
    internalModule = rec {
      _file = "lib/modules.nix";

      key = _file;

      options = {
        _module.args = mkOption {
          # Because things like `mkIf` are entirely useless for
          # `_module.args` (because there's no way modules can check which
          # arguments were passed), we'll use `lazyAttrsOf` which drops
          # support for that, in turn it's lazy in its values. This means e.g.
          # a `_module.args.pkgs = import (fetchTarball { ... }) {}` won't
          # start a download when `pkgs` wasn't evaluated.
          type = types.lazyAttrsOf types.raw;
          # Only render documentation once at the root of the option tree,
          # not for all individual submodules.
          # Allow merging option decls to make this internal regardless.
          ${
            if prefix == []
            then null # unset => visible
            else "internal"
          } =
            true;
          # TODO: Change the type of this option to a submodule with a
          # freeformType, so that individual arguments can be documented
          # separately
          description = ''
            Additional arguments passed to each module in addition to ones
            like `lib`, `config`,
            and `pkgs`, `modulesPath`.

            This option is also available to all submodules. Submodules do not
            inherit args from their parent module, nor do they provide args to
            their parent module or sibling submodules. The sole exception to
            this is the argument `name` which is provided by
            parent modules to a submodule and contains the attribute name
            the submodule is bound to, or a unique generated name if it is
            not bound to an attribute.

            Some arguments are already passed by default, of which the
            following *cannot* be changed with this option:
            - {var}`lib`: The nixpkgs library.
            - {var}`config`: The results of all options after merging the values from all modules together.
            - {var}`options`: The options declared in all modules.
            - {var}`specialArgs`: The `specialArgs` argument passed to `evalModules`.
            - All attributes of {var}`specialArgs`

              Whereas option values can generally depend on other option values
              thanks to laziness, this does not apply to `imports`, which
              must be computed statically before anything else.

              For this reason, callers of the module system can provide `specialArgs`
              which are available during import resolution.

              For NixOS, `specialArgs` includes
              {var}`modulesPath`, which allows you to import
              extra modules from the nixpkgs package tree without having to
              somehow make the module aware of the location of the
              `nixpkgs` or NixOS directories.
              ```
              { modulesPath, ... }: {
                imports = [
                  (modulesPath + "/profiles/minimal.nix")
                ];
              }
              ```

            For NixOS, the default value for this option includes at least this argument:
            - {var}`pkgs`: The nixpkgs package set according to
              the {option}`nixpkgs.pkgs` option.
          '';
        };

        _module.check = mkOption {
          type = types.bool;
          internal = true;
          default = true;
          description = "Whether to check whether all option definitions have matching declarations.";
        };

        _module.freeformType = mkOption {
          type = types.nullOr types.optionType;
          internal = true;
          default = null;
          description = ''
            If set, merge all definitions that don't have an associated option
            together using this type. The result then gets combined with the
            values of all declared options to produce the final `
            config` value.

            If this is `null`, definitions without an option
            will throw an error unless {option}`_module.check` is
            turned off.
          '';
        };

        _module.specialArgs = mkOption {
          readOnly = true;
          internal = true;
          description = ''
            Externally provided module arguments that can't be modified from
            within a configuration, but can be used in module imports.
          '';
        };
      };

      config = {
        _module.args = {
          inherit extendModules;
          moduleType = type;
        };
        _module.specialArgs = specialArgs;
      };
    };

    merged = let
      collected =
        collectModules class (specialArgs.modulesPath or "") (regularModules ++ [internalModule])
        (
          {
            inherit
              lib
              options
              config
              specialArgs
              ;
          }
          // specialArgs
        );
    in
      mergeModules prefix (reverseList collected);

    options = merged.matchedOptions;

    config = let
      # For definitions that have an associated option
      declaredConfig = mapAttrsRecursiveCond (v: !isOption v) (_: v: v.value) options;

      # If freeformType is set, this is for definitions that don't have an associated option
      freeformConfig = let
        defs =
          map (def: {
            file = def.file;
            value = setAttrByPath def.prefix def.value;
          })
          merged.unmatchedDefns;
      in
        if defs == []
        then {}
        else declaredConfig._module.freeformType.merge prefix defs;
    in
      if declaredConfig._module.freeformType == null
      then declaredConfig
      # Because all definitions that had an associated option ended in
      # declaredConfig, freeformConfig can only contain the non-option
      # paths, meaning recursiveUpdate will never override any value
      else recursiveUpdate freeformConfig declaredConfig;

    checkUnmatched =
      if config._module.check && config._module.freeformType == null && merged.unmatchedDefns != []
      then let
        firstDef = head merged.unmatchedDefns;
        baseMsg = let
          optText = showOption (prefix ++ firstDef.prefix);
          defText =
            addErrorContext
            "while evaluating the error message for definitions for `${optText}', which is an option that does not exist"
            (addErrorContext "while evaluating a definition from `${firstDef.file}'" (showDefs [firstDef]));
        in "The option `${optText}' does not exist. Definition values:${defText}";
      in
        if attrNames options == ["_module"]
        # No options were declared at all (`_module` is built in)
        # but we do have unmatched definitions, and no freeformType (earlier conditions)
        then let
          optionName = showOption prefix;
        in
          if optionName == ""
          then
            throw ''
              ${baseMsg}

              It seems as if you're trying to declare an option by placing it into `config' rather than `options'!
            ''
          else
            throw ''
              ${baseMsg}

              However there are no options defined in `${showOption prefix}'. Are you sure you've
              declared your options properly? This can happen if you e.g. declared your options in `types.submodule'
              under `config' rather than `options'.
            ''
        else throw baseMsg
      else null;

    checked = seq checkUnmatched;

    extendModules = extendArgs @ {
      modules ? [],
      specialArgs ? {},
      prefix ? [],
    }:
      evalModules (
        evalModulesArgs
        // {
          inherit class;
          modules = regularModules ++ modules;
          specialArgs = evalModulesArgs.specialArgs or {} // specialArgs;
          prefix = extendArgs.prefix or evalModulesArgs.prefix or [];
        }
      );

    type = types.submoduleWith {inherit modules specialArgs class;};

    result = withWarnings {
      _type = "configuration";
      options = checked options;
      config = checked (removeAttrs config ["_module"]);
      _module = checked (config._module);
      inherit extendModules type;
      class = class;
    };
  in
    result;

  # collectModules :: (class: String) -> (modulesPath: String) -> (modules: [ Module ]) -> (args: Attrs) -> [ Module ]
  #
  # Collects all modules recursively through `import` statements, filtering out
  # all modules in disabledModules.
  collectModules = class: let
    # Like unifyModuleSyntax, but also imports paths and calls functions if necessary
    loadModule = args: fallbackFile: fallbackKey: m:
      if isFunction m
      then unifyModuleSyntax fallbackFile fallbackKey (applyModuleArgs fallbackKey m args)
      else if isAttrs m
      then
        if m._type or "module" == "module"
        then unifyModuleSyntax fallbackFile fallbackKey m
        else if m._type == "if" || m._type == "override"
        then loadModule args fallbackFile fallbackKey {config = m;}
        else
          throw (
            "Could not load a value as a module, because it is of type ${lib.strings.escapeNixString m._type}"
            + optionalString (fallbackFile != unknownModule) ", in file ${toString fallbackFile}."
            + optionalString (m._type == "configuration")
            " If you do intend to import this configuration, please only import the modules that make up the configuration. You may have to create a `let` binding, file or attribute to give yourself access to the relevant modules.\nWhile loading a configuration into the module system is a very sensible idea, it can not be done cleanly in practice."
            # Extended explanation: That's because a finalized configuration is more than just a set of modules. For instance, it has its own `specialArgs` that, by the nature of `specialArgs` can't be loaded through `imports` or the the `modules` argument. So instead, we have to ask you to extract the relevant modules and use those instead. This way, we keep the module system comparatively simple, and hopefully avoid a bad surprise down the line.
          )
      else if isList m
      then let
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
      if class != null
      then
        m:
          if m._class != null -> m._class == class
          then m
          else throw "The module ${m._file or m.key} was imported into ${class} instead of ${m._class}."
      else m: m;

    /*
    Collects all modules recursively into the form

      {
        disabled = [ <list of disabled modules> ];
        # All modules of the main module list
        modules = [
          {
            key = <key1>;
            module = <module for key1>;
            # All modules imported by the module for key1
            modules = [
              {
                key = <key1-1>;
                module = <module for key1-1>;
                # All modules imported by the module for key1-1
                modules = [ ... ];
              }
              ...
            ];
          }
          ...
        ];
      }
    */
    collectStructuredModules = let
      collectResults = modules: {
        disabled = concatLists (catAttrs "disabled" modules);
        inherit modules;
      };
    in
      parentFile: parentKey: initialModules: args:
        collectResults (
          imap1 (
            n: x: let
              module = checkModule (loadModule args parentFile "${parentKey}:anon-${toString n}" x);
              collectedImports = collectStructuredModules module._file module.key module.imports args;
            in {
              key = module.key;
              module = module;
              modules = collectedImports.modules;
              disabled =
                (
                  if module.disabledModules != []
                  then [
                    {
                      file = module._file;
                      disabled = module.disabledModules;
                    }
                  ]
                  else []
                )
                ++ collectedImports.disabled;
            }
          )
          initialModules
        );

    # filterModules :: String -> { disabled, modules } -> [ Module ]
    #
    # Filters a structure as emitted by collectStructuredModules by removing all disabled
    # modules recursively. It returns the final list of unique-by-key modules
    filterModules = modulesPath: {
      disabled,
      modules,
    }: let
      moduleKey = file: m:
        if isString m
        then
          if substring 0 1 m == "/"
          then m
          else toString modulesPath + "/" + m
        else if isConvertibleWithToString m
        then
          if m ? key && m.key != toString m
          then throw "Module `${file}` contains a disabledModules item that is an attribute set that can be converted to a string (${toString m}) but also has a `.key` attribute (${m.key}) with a different value. This makes it ambiguous which module should be disabled."
          else toString m
        else if m ? key
        then m.key
        else if isAttrs m
        then throw "Module `${file}` contains a disabledModules item that is an attribute set, presumably a module, that does not have a `key` attribute. This means that the module system doesn't have any means to identify the module that should be disabled. Make sure that you've put the correct value in disabledModules: a string path relative to modulesPath, a path value, or an attribute set with a `key` attribute."
        else throw "Each disabledModules item must be a path, string, or a attribute set with a key attribute, or a value supported by toString. However, one of the disabledModules items in `${toString file}` is none of that, but is of type ${typeOf m}.";

      disabledKeys = concatMap ({
        file,
        disabled,
      }:
        map (moduleKey file) disabled)
      disabled;
      keyFilter = filter (attrs: !elem attrs.key disabledKeys);
    in
      map (attrs: attrs.module) (genericClosure {
        startSet = keyFilter modules;
        operator = attrs: keyFilter attrs.modules;
      });
  in
    modulesPath: initialModules: args:
      filterModules modulesPath (collectStructuredModules unknownModule "" initialModules args);

  /*
  Massage a module into canonical form, that is, a set consisting
  of ‘options’, ‘config’ and ‘imports’ attributes.
  */
  unifyModuleSyntax = file: key: m: let
    addMeta = config:
      if m ? meta
      then
        mkMerge [
          config
          {meta = m.meta;}
        ]
      else config;
    addFreeformType = config:
      if m ? freeformType
      then
        mkMerge [
          config
          {_module.freeformType = m.freeformType;}
        ]
      else config;
  in
    if m ? config || m ? options
    then let
      badAttrs = removeAttrs m [
        "_class"
        "_file"
        "key"
        "disabledModules"
        "inputs"
        "imports"
        "options"
        "config"
        "meta"
        "freeformType"
      ];
      duplicateInputs = builtins.intersectAttrs (m.inputs or {}) (m.config.inputs or {});
    in
      if badAttrs != {}
      then throw "Module `${key}' has an unsupported attribute `${head (attrNames badAttrs)}'. This is caused by introducing a top-level `config' or `options' attribute. Add configuration attributes immediately on the top level instead, or move all of them (namely: ${toString (attrNames badAttrs)}) into the explicit `config' attribute."
      else if duplicateInputs != {}
      then throw "Module `${key}' defines the input `${head (attrNames duplicateInputs)}' twice, once in the top-level `inputs' attribute and once in the `config.inputs' attribute. Rename or remove one of these definitions."
      else let
        additionalConfig = optionalAttrs (m ? inputs || (m.config or {}) ? inputs) {
          inputs = (m.inputs or {}) // (m.config.inputs or {});
        };
      in {
        _file = toString m._file or file;
        _class = m._class or null;
        key = toString m.key or key;
        disabledModules = m.disabledModules or [];
        imports = m.imports or [];
        options = m.options or {};
        config = addFreeformType (addMeta (m.config or {} // additionalConfig));
      }
    else
      # shorthand syntax
      throwIfNot (isAttrs m) "module ${file} (${key}) does not look like a module." {
        _file = toString m._file or file;
        _class = m._class or null;
        key = toString m.key or key;
        disabledModules = m.disabledModules or [];
        imports = m.require or [] ++ m.imports or [];
        options = {};
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

  applyModuleArgsIfFunction = key: f: args @ {config, ...}:
    if isFunction f
    then applyModuleArgs key f args
    else f;

  applyModuleArgs = key: f: args @ {config, ...}: let
    # Module arguments are resolved in a strict manner when attribute set
    # deconstruction is used.  As the arguments are now defined with the
    # config._module.args option, the strictness used on the attribute
    # set argument would cause an infinite loop, if the result of the
    # option is given as argument.
    #
    # To work-around the strictness issue on the deconstruction of the
    # attributes set argument, we create a new attribute set which is
    # constructed to satisfy the expected set of attributes.  Thus calling
    # a module will resolve strictly the attributes used as argument but
    # not their values.  The values are forwarding the result of the
    # evaluation of the option.
    context = name: ''while evaluating the module argument `${name}' in "${key}":'';
    extraArgs = mapAttrs (
      name: _: addErrorContext (context name) (args.${name} or config._module.args.${name})
    ) (functionArgs f);
  in
    # Note: we append in the opposite order such that we can add an error
    # context on the explicit arguments of "args" too. This update
    # operator is used to make the "args@{ ... }: with args.lib;" notation
    # works.
    f (args // extraArgs);

  /*
  Merge a list of modules.  This will recurse over the option
    declarations in all modules, combining them into a single set.
    At the same time, for each option declaration, it will merge the
    corresponding option definitions in all machines, returning them
    in the ‘value’ attribute of each option.

    This returns a set like
      {
        # A recursive set of options along with their final values
        matchedOptions = {
          foo = { _type = "option"; value = "option value of foo"; ... };
          bar.baz = { _type = "option"; value = "option value of bar.baz"; ... };
          ...
        };
        # A list of definitions that weren't matched by any option
        unmatchedDefns = [
          { file = "file.nix"; prefix = [ "qux" ]; value = "qux"; }
          ...
        ];
      }
  */
  mergeModules = prefix: modules:
    mergeModules' prefix modules (
      concatMap (
        m:
          map (config: {
            file = m._file;
            inherit config;
          }) (pushDownProperties m.config)
      )
      modules
    );

  mergeModules' = prefix: modules: configs: let
    # an attrset 'name' => list of submodules that declare ‘name’.
    declsByName = zipAttrsWith (n: concatLists) (
      map (
        module: let
          subtree = module.options;
        in
          if !(isAttrs subtree)
          then
            throw ''
              An option declaration for `${concatStringsSep "." prefix}' has type
              `${typeOf subtree}' rather than an attribute set.
              Did you mean to define this outside of `options'?
            ''
          else
            mapAttrs (n: option: [
              {
                inherit (module) _file;
                pos = unsafeGetAttrPos n subtree;
                options = option;
              }
            ])
            subtree
      )
      modules
    );

    # The root of any module definition must be an attrset.
    checkedConfigs = assert all (
      c:
      # TODO: I have my doubts that this error would occur when option definitions are not matched.
      #       The implementation of this check used to be tied to a superficially similar check for
      #       options, so maybe that's why this is here.
        isAttrs c.config
        || throw ''
          In module `${c.file}', you're trying to define a value of type `${typeOf c.config}'
          rather than an attribute set for the option
          `${concatStringsSep "." prefix}'!

          This usually happens if `${concatStringsSep "." prefix}' has option
          definitions inside that are not matched. Please check how to properly define
          this option by e.g. referring to `man 5 configuration.nix'!
        ''
    )
    configs; configs;

    # an attrset 'name' => list of submodules that define ‘name’.
    pushedDownDefinitionsByName = zipAttrsWith (n: concatLists) (
      map (
        module:
          mapAttrs (
            n: value:
              map (config: {
                inherit (module) file;
                inherit config;
              }) (pushDownProperties value)
          )
          module.config
      )
      checkedConfigs
    );
    # extract the definitions for each loc
    rawDefinitionsByName = zipAttrsWith (n: concatLists) (
      map (
        module:
          mapAttrs (n: value: [
            {
              inherit (module) file;
              inherit value;
            }
          ])
          module.config
      )
      checkedConfigs
    );

    # Convert an option tree decl to a submodule option decl
    optionTreeToOption = decl:
      if isOption decl.options
      then decl
      else
        decl
        // {
          options = mkOption {
            type = types.submoduleWith {
              modules = [{options = decl.options;}];
              # `null` is not intended for use by modules. It is an internal
              # value that means "whatever the user has declared elsewhere".
              # This might become obsolete with https://github.com/NixOS/nixpkgs/issues/162398
              shorthandOnlyDefinesConfig = null;
            };
          };
        };

    resultsByName =
      mapAttrs (
        name: decls:
        # We're descending into attribute ‘name’.
        let
          loc = prefix ++ [name];
          defns = pushedDownDefinitionsByName.${name} or [];
          defns' = rawDefinitionsByName.${name} or [];
          optionDecls =
            filter (
              m:
                m.options
                ? _type
                && (m.options._type == "option" || throwDeclarationTypeError loc m.options._type m._file)
            )
            decls;
        in
          if length optionDecls == length decls
          then let
            opt = fixupOptionType loc (mergeOptionDecls loc decls);
          in {
            matchedOptions = lib.modules.evalOptionValue loc opt defns';
            unmatchedDefns = [];
          }
          else if optionDecls != []
          then
            if all (x: x.options.type.name or null == "submodule") optionDecls
            # Raw options can only be merged into submodules. Merging into
            # attrsets might be nice, but ambiguous. Suppose we have
            # attrset as a `attrsOf submodule`. User declares option
            # attrset.foo.bar, this could mean:
            #  a. option `bar` is only available in `attrset.foo`
            #  b. option `foo.bar` is available in all `attrset.*`
            #  c. reject and require "<name>" as a reminder that it behaves like (b).
            #  d. magically combine (a) and (c).
            # All of the above are merely syntax sugar though.
            then let
              opt = fixupOptionType loc (mergeOptionDecls loc (map optionTreeToOption decls));
            in {
              matchedOptions = lib.modules.evalOptionValue loc opt defns';
              unmatchedDefns = [];
            }
            else let
              nonOptions = filter (m: !isOption m.options) decls;
            in
              throw "The option `${showOption loc}' in module `${(head optionDecls)._file}' would be a parent of the following options, but its type `${
                (head optionDecls).options.type.description or "<no description>"
              }' does not support nested options.\n${showRawDecls loc nonOptions}"
          else mergeModules' loc decls defns
      )
      declsByName;

    matchedOptions = mapAttrs (n: v: v.matchedOptions) resultsByName;

    # an attrset 'name' => list of unmatched definitions for 'name'
    unmatchedDefnsByName =
      # Propagate all unmatched definitions from nested option sets
      mapAttrs (n: v: v.unmatchedDefns) resultsByName
      # Plus the definitions for the current prefix that don't have a matching option
      // removeAttrs rawDefinitionsByName (attrNames matchedOptions);
  in {
    inherit matchedOptions;

    # Transforms unmatchedDefnsByName into a list of definitions
    unmatchedDefns =
      if configs == []
      then
        # When no config values exist, there can be no unmatched config, so
        # we short circuit and avoid evaluating more _options_ than necessary.
        []
      else
        concatLists (
          mapAttrsToList (
            name: defs:
              map (
                def:
                  def
                  // {
                    # Set this so we know when the definition first left unmatched territory
                    prefix = [name] ++ (def.prefix or []);
                  }
              )
              defs
          )
          unmatchedDefnsByName
        );
  };

  throwDeclarationTypeError = loc: actualTag: file: let
    name = lib.strings.escapeNixIdentifier (lib.lists.last loc);
    path = showOption loc;
    depth = length loc;

    paragraphs =
      [
        "In module ${file}: expected an option declaration at option path `${path}` but got an attribute set with type ${actualTag}"
      ]
      ++ optional (actualTag == "option-type") ''
        When declaring an option, you must wrap the type in a `mkOption` call. It should look somewhat like:
            ${comment}
            ${name} = lib.mkOption {
              description = ...;
              type = <the type you wrote for ${name}>;
              ...
            };
      '';

    # Ideally we'd know the exact syntax they used, but short of that,
    # we can only reliably repeat the last. However, we repeat the
    # full path in a non-misleading way here, in case they overlook
    # the start of the message. Examples attract attention.
    comment = optionalString (depth > 1) "\n    # ${showOption loc}";
  in
    throw (concatStringsSep "\n\n" paragraphs);

  /*
  Given a config set, expand mkMerge properties, and push down the
  other properties into the children.  The result is a list of
  config sets that do not have properties at top-level.  For
  example,

    mkMerge [ { boot = set1; } (mkIf cond { boot = set2; services = set3; }) ]

  is transformed into

    [ { boot = set1; } { boot = mkIf cond set2; services = mkIf cond set3; } ].

  This transform is the critical step that allows mkIf conditions
  to refer to the full configuration without creating an infinite
  recursion.
  */
  pushDownProperties = cfg:
    if cfg._type or "" == "merge"
    then concatMap pushDownProperties cfg.contents
    else if cfg._type or "" == "if"
    then map (mapAttrs (n: v: mkIf cfg.condition v)) (pushDownProperties cfg.content)
    else if cfg._type or "" == "override"
    then map (mapAttrs (n: v: mkOverride cfg.priority v)) (pushDownProperties cfg.content)
    # FIXME: handle mkOrder?
    else [cfg];
in {
  inherit evalModules;
}
