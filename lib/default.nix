{ inputs, ... }:
let
  contributed =
    {
      pkgs,
      flake ? null,
    }:
    modules: moduleName:
    let
      baseline =
        (lib.evalModules {
          modules = [
            harness
            metaOptions
          ];
          specialArgs = moduleArgs;
        }).options;
      declaredBy =
        option: lib.any (declared: lib.elem (toString declared) moduleFiles) (option.declarations or [ ]);
      declaresMeta =
        let
          probed = builtins.tryEval (
            (lib.evalModules {
              modules = [
                harness
                modules.${moduleName}
              ];
              specialArgs = moduleArgs;
            }).options
              ? meta.description
          );
        in
        probed.success && probed.value;
      evaluated = lib.evalModules {
        modules = modulesFor;
        specialArgs = moduleArgs;
      };
      filesOf =
        value:
        if builtins.isString value || builtins.isPath value then
          [ (toString value) ]
        else if builtins.isAttrs value then
          lib.optional (value ? _file) (toString value._file)
          ++ lib.concatMap filesOf (lib.toList (value.imports or [ ]))
        else
          [ ];
      moduleArgs = {
        inherit pkgs;
      }
      // lib.optionalAttrs (flake != null) {
        inherit flake;
        inputs = flake.inputs // {
          self = flake;
        };
      };
      moduleFiles = lib.remove (toString metaOptions) (filesOf modules.${moduleName});
      modulesFor = [ harness ] ++ lib.optional (!declaresMeta) metaOptions ++ [ modules.${moduleName} ];
      ownMeta =
        attribute:
        let
          entries =
            let
              values = evaluated.config.meta.${attribute} or [ ];
            in
            if builtins.isList values then values else [ ];
          matching = lib.filter (entry: lib.elem (toString (entry.file or "")) moduleFiles) entries;
        in
        if matching != [ ] then
          (lib.last matching).value
        else if builtins.length entries == 1 then
          (lib.head entries).value
        else
          null;
      scoped = scopedIn evaluated.options baseline;
      scopedIn =
        tree: inherited:
        lib.listToAttrs (
          lib.concatMap (
            name:
            let
              above = inherited.${name} or null;
              value = tree.${name};
            in
            if value ? _type && value._type == "option" then
              lib.optional (above == null || declaredBy value) { inherit name value; }
            else
              let
                kept = scopedIn value (if above == null then { } else above);
              in
              lib.optional (kept != { }) {
                inherit name;
                value = kept;
              }
          ) (builtins.attrNames tree)
        );
    in
    {
      inherit modulesFor;
      description =
        let
          described = ownMeta "description";
        in
        if described == null then "" else described;
      example = ownMeta "example";
      names = builtins.attrNames scoped;
      options = scoped;
    };
  descriptionBody =
    description:
    let
      rest = lib.drop 1 (lib.splitString "\n" description);
      withoutLeadingBlanks = dropWhile (line: line == "") rest;
      withoutTrailingBlanks = lib.reverseList (
        dropWhile (line: line == "") (lib.reverseList withoutLeadingBlanks)
      );
    in
    lib.concatStringsSep "\n" withoutTrailingBlanks;
  dropWhile = predicate: list: lib.drop (firstFalse predicate list) list;
  everything = rec {
    buildDocumented =
      let
        buildDocumentedFunctionImpl =
          { name, value }:
          let
            checked =
              spec: argument:
              let
                submodules = (spec.type or { }).getSubModules or null;
              in
              if !(spec ? type) || !(spec.type ? check) then
                argument
              else if !(spec.type.check argument) then
                throw "${name}: argument `${spec.name}` is not ${describe spec}"
              else if submodules != null then
                builtins.deepSeq
                  (lib.evalModules {
                    modules = submodules ++ [ { config = argument; } ];
                  }).config
                  argument
              else
                argument;
            curried =
              let
                arity = lib.length specs;
                at = index: checked (lib.elemAt specs index);
              in
              if arity == 0 then
                functor
              else if arity == 1 then
                a: functor (at 0 a)
              else if arity == 2 then
                a: b: functor (at 0 a) (at 1 b)
              else if arity == 3 then
                a: b: c:
                functor (at 0 a) (at 1 b) (at 2 c)
              else if arity == 4 then
                a: b: c: d:
                functor (at 0 a) (at 1 b) (at 2 c) (at 3 d)
              else
                throw "${name}: more than four positional arguments are not supported by the mixin";
            describe = spec: spec.type.description or "of the declared type";
            functor = value.__functor value;
            named =
              argument:
              let
                missing = lib.filter (
                  specName: !(builtins.elem specName (builtins.attrNames argument)) && !(specs.${specName} ? default)
                ) (builtins.attrNames specs);
                unknown = lib.subtractLists (builtins.attrNames specs) (builtins.attrNames argument);
              in
              if unknown != [ ] then
                throw "${name}: unexpected argument `${builtins.head unknown}`"
              else if missing != [ ] then
                throw "${name}: missing argument `${builtins.head missing}`"
              else
                functor (
                  lib.mapAttrs (specName: spec: checked (spec // { name = specName; }) argument.${specName}) specs
                );
            specs = value.meta.args or [ ];
          in
          if builtins.isList specs then
            curried
          else if builtins.isAttrs specs then
            named
          else
            throw "${name}: meta.args must be a list of positional arguments or a set of named ones";
        buildDocumentedFunctionsImpl =
          surface:
          lib.mapAttrs (
            name: value:
            if builtins.isAttrs value && value ? meta && value ? value then
              value.value
            else if builtins.isAttrs value && value ? __functor then
              buildDocumentedFunctionImpl {
                inherit name value;
              }
            else if declarationNamespaceImpl 8 value then
              # a namespace of declarations at any depth, such as lib.types.strings
              buildDocumentedFunctionsImpl value
            else
              value
          ) surface;
        declarationNamespaceImpl =
          depth: value:
          depth > 0
          && builtins.isAttrs value
          && !(value ? meta)
          && !(value ? __functor)
          && !(value ? outPath)
          && !(value ? _type)
          && builtins.attrNames value != [ ]
          && lib.any (
            member:
            let
              child = value.${member};
            in
            (builtins.isAttrs child && (child ? meta || child ? __functor))
            || declarationNamespaceImpl (depth - 1) child
          ) (builtins.attrNames value);
      in
      {
        function = {
          __functor = _self: buildDocumentedFunctionImpl;
          meta = {
            args = {
              name = {
                description = "attribute name the function is exported under, used in the type error it raises";
                type = lib.types.str;
              };
              value = {
                description = "declaration carrying meta.args and __functor, the source of the rendered arguments";
                type = lib.types.attrs;
              };
            };
            description = "Builds a real curried function from a documented declaration, so consumers get a plain lambda instead of a functor attribute set and every argument is checked against the type its meta.args entry states.";
          };
        };
        functions = {
          __functor = _self: buildDocumentedFunctionsImpl;
          meta = {
            args.surface = {
              description = "attribute set of library exports to build, usually the flake's lib output";
              type = lib.types.attrs;
            };
            description = "Builds every documented declaration in a surface into a real function, and recurses into a namespace of declarations to any depth, leaving exports that declare no meta and hold no declarations untouched.";
          };
        };
        namespace = {
          __functor = _self: declarationNamespaceImpl 8;
          meta = {
            args.value = {
              description = "an attribute set that may be a namespace of documented declarations";
              type = lib.types.attrs;
            };
            description = "Reports whether an attribute set is a namespace of declarations: at least one member, at any depth, is a declaration carrying meta or __functor.";
          };
        };
      };
    descriptions =
      let
        problemsImpl =
          {
            components,
            options,
            allowComponents ? [ ],
          }:
          let
            description = entry: entry.value.description or "";
            flat = lib.filter (
              entry: !(lib.hasPrefix "_" (lib.head entry.path)) && !(entry.value.internal or false)
            ) (flattenOptions [ ] options);
            foreignComponents = lib.filter (entry: unmentioned entry != [ ]) flat;
            mentionedIn =
              text:
              lib.unique (
                lib.concatMap (
                  token: lib.filter (component: token == component || lib.hasPrefix "${component}-" token) components
                ) (words (lib.toLower text))
              );
            missing = lib.filter (entry: description entry == "") flat;
            shared = lib.filter (
              entry:
              description entry != ""
              && lib.any (other: other.path != entry.path && description other == description entry) flat
            ) flat;
            short = lib.filter (
              entry: description entry != "" && builtins.stringLength (description entry) < 40
            ) flat;
            unmentioned =
              entry:
              lib.filter (component: !(lib.elem component allowComponents)) (mentionedIn (description entry));
          in
          map (entry: "${renderPath entry.path}: has no description") missing
          ++ map (
            entry:
            "${renderPath entry.path}: description is ${toString (builtins.stringLength (description entry))} characters, at least 40 are required"
          ) short
          ++ map (
            entry:
            "${renderPath entry.path}: repeats the description of ${
              renderPath
                (lib.head (
                  lib.filter (other: other.path != entry.path && description other == description entry) flat
                )).path
            }"
          ) shared
          ++ map (
            entry:
            "${renderPath entry.path}: mentions ${lib.concatStringsSep ", " (unmentioned entry)}, which is another component of this flake and has no bearing on this option's contract"
          ) foreignComponents;
      in
      {
        problems = {
          __functor = _self: problemsImpl;
          meta = {
            args = {
              allowComponents = {
                description = "component names that may be mentioned without being reported";
                type = lib.types.listOf lib.types.str;
              };
              components = {
                description = "names of the components this flake is built from, whose mention is reported";
                type = lib.types.listOf lib.types.str;
              };
              options = {
                description = "evaluated option set whose descriptions are inspected";
                type = lib.types.attrs;
              };
            };
            description = "Reports descriptions that are missing, too short to state a contract, repeated, or that name another component of the flake.";
          };
        };
      };
    dev =
      let
        preCommitImpl =
          {
            pkgs,
            src,
            docs ? inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.docs,
            extraHooks ? { },
            formatter ? inputs.self.formatter.${pkgs.stdenv.hostPlatform.system},
          }:
          let
            docsHook = pkgs.writeShellScript "docs-hook" ''
              if [ ! -d "$PWD/.git" ]; then
                exit 0
              fi
              if ! command -v nix > /dev/null 2>&1; then
                echo "docs: nix is not available in this environment, skipping the documentation check"
                exit 0
              fi
              exec ${lib.getExe docs} --check
            '';
            result = inputs.git-hooks.lib.${system}.run {
              inherit src;
              hooks = {
                docs = {
                  enable = true;
                  entry = "${docsHook}";
                  language = "system";
                  name = "docs";
                  pass_filenames = false;
                };
                treefmt = {
                  enable = true;
                  packageOverrides.treefmt = formatter;
                };
              }
              // extraHooks;
            };
            system = pkgs.stdenv.hostPlatform.system;
          in
          result
          // {
            meta = (result.meta or { }) // {
              description = "Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.";
            };
          };
      in
      {
        preCommit = {
          __functor = _self: preCommitImpl;
          meta = {
            args = {
              docs = {
                description = "the docs app the docs hook runs to check that the documentation is current and staged";
                type = lib.types.package;
              };
              extraHooks = {
                description = "additional git-hooks definitions merged into the hook set";
                type = lib.types.attrs;
              };
              formatter = {
                description = "the derivation the treefmt hook runs, so the hook formats with this flake's formatter";
                type = lib.types.package;
              };
              pkgs = {
                description = "nixpkgs package set the hooks are taken from";
                type = lib.types.attrs;
              };
              src = {
                description = "the tree the hooks are run against";
                type = lib.types.path;
              };
            };
            description = "Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.";
          };
        };
      };
    docs =
      let
        appImpl =
          { pkgs }:
          (pkgs.writeShellScriptBin "docs" ''
            set -eu
            export PATH="${
              pkgs.lib.makeBinPath (
                with pkgs;
                [
                  coreutils
                  diffutils
                  findutils
                  git
                  gnugrep
                  gnused
                  jq
                  nix
                ]
              )
            }"
            DOCS_DESCRIPTION=$(nix flake metadata --json "path:$PWD" 2>/dev/null | jq -r '.description')
            export DOCS_DESCRIPTION
            expression=$(
              cat <<'EXPR'
            let
              base = builtins.getFlake "path:${inputs.self.outPath}";
              flake = builtins.getFlake ("path:" + builtins.getEnv "PWD");
              pkgs = base.inputs.nixpkgs.legacyPackages.''${builtins.currentSystem};
              description = builtins.getEnv "DOCS_DESCRIPTION";
              args = base.lib.internal.flake.args { inherit description flake pkgs; };
            in
            base.lib.internal.docs.tree args
            EXPR
            )
            tree=$(nix build --no-link --print-out-paths --impure --expr "$expression")
            if [ "''${1:-}" = "--check" ]; then
              status=0
              while read -r target; do
                if [ ! -f "$PWD/$target" ]; then
                  echo "not written: $target (run: nix run .#docs)"
                  status=1
                elif ! diff -q "$tree/$target" "$PWD/$target" > /dev/null; then
                  echo "out of date: $target (run: nix run .#docs)"
                  status=1
                elif [ -d "$PWD/.git" ] && ! git -C "$PWD" ls-files --error-unmatch "$target" > /dev/null 2>&1; then
                  echo "not staged: $target (run: git add $target)"
                  status=1
                elif [ -d "$PWD/.git" ] && ! git -C "$PWD" diff --quiet -- "$target"; then
                  echo "not staged: $target (run: git add $target)"
                  status=1
                fi
              done < <(cd "$tree" && find . -type f -name '*README*.md' | sed -e 's|^\./||')
              if [ "$status" -ne 0 ]; then
                exit 1
              fi
              echo "documentation is up to date and staged"
              exit 0
            fi
            if [ $# -eq 0 ]; then
              cd "$tree"
              find . -type f -name '*README*.md' | sed -e 's|^\./||' | while read -r target; do
                install -D -m 644 "$tree/$target" "$OLDPWD/$target"
                echo "wrote $target"
              done
              exit 0
            fi
            case "$1" in
              *)
                echo "usage: docs [--check]" >&2
                exit 2
                ;;
            esac
          '')
          // {
            meta.description = "Writes the generated documentation into the working tree, or checks that it is current and staged.";
          };
        treeImpl =
          {
            pkgs,
            description,
            root,
            system,
            apps ? { },
            checks ? { },
            configurations ? { },
            flake ? null,
            formatter ? null,
            internalLibrary ? { },
            library ? { },
            modules ? { },
            packages ? { },
            requireInternalDocumentation ? false,
            templates ? { },
            url ? "",
          }:
          let
            documentation' = documentation.build {
              inherit
                pkgs
                root
                system
                description
                requireInternalDocumentation
                apps
                checks
                configurations
                flake
                formatter
                internalLibrary
                library
                modules
                packages
                templates
                url
                ;
            };
          in
          pkgs.stdenv.mkDerivation {
            buildCommand = ''
              mkdir -p $out
              install -m 644 ${documentation'.root}/README.md $out/README.md
              ${lib.concatMapStrings (
                entry: "install -D -m 644 ${entry.doc}/README.md $out/${entry.relative}\n"
              ) documentation'.files}
            '';
            meta.description = "Documentation tree: the repository README plus one README per output kind.";
            name = "docs-tree";
          };
      in
      {
        app = {
          __functor = _self: appImpl;
          meta = {
            args.pkgs = {
              description = "nixpkgs package set the wrapper script runs with; the flake it documents is read from the working directory";
              type = lib.types.attrs;
            };
            description = "Writes one generated README into the working tree, for the repository or for one named module.";
          };
        };
        tree = {
          __functor = _self: treeImpl;
          meta = {
            args = {
              apps = {
                description = "attrset of apps to document, empty when the flake exports none";
                type = lib.types.attrs;
              };
              checks = {
                description = "attrset of checks to document, empty when the flake exports none";
                type = lib.types.attrs;
              };
              configurations = {
                description = "attrset of NixOS configurations to document";
                type = lib.types.attrs;
              };
              description = {
                description = "sentence saying what this flake is for";
                type = lib.types.str;
              };
              flake = {
                description = "the flake whose modules are documented, supplying the module arguments a blueprint system provides";
                type = lib.types.nullOr lib.types.attrs;
              };
              formatter = {
                description = "the derivation exposed as the flake formatter for this system";
                type = lib.types.nullOr lib.types.package;
              };
              internalLibrary = {
                description = "attrset of functions documented only in lib/README.md";
                type = lib.types.attrs;
              };
              library = {
                description = "attrset of functions to document in the index";
                type = lib.types.attrs;
              };
              modules = {
                description = "attrset of NixOS modules to document";
                type = lib.types.attrs;
              };
              packages = {
                description = "attrset of packages to document";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set used to render option documentation";
                type = lib.types.attrs;
              };
              requireInternalDocumentation = {
                description = "whether an internal export must state meta.description too, false when the internal surface may stay opaque";
                type = lib.types.bool;
              };
              root = {
                description = "path to the repository root, used to locate module files";
                type = lib.types.path;
              };
              system = {
                description = "system string selecting the packages, apps and checks to document";
                type = lib.types.str;
              };
              templates = {
                description = "attrset of templates to document";
                type = lib.types.attrs;
              };
              url = {
                description = "flake reference the templates are published under, empty when the flake states none";
                type = lib.types.str;
              };
            };
            description = "Builds the documentation tree: the repository README plus one README per output kind, ready to install.";
          };
        };
      };
    document =
      let
        appImpl =
          { app, name }:
          section.make {
            description = app.meta.description or "";
            language = "sh";
            title = name;
            type = "app";
            usage = "nix run .#${name}";
          };
        checkImpl =
          {
            check,
            name,
            system,
          }:
          section.make {
            description = check.meta.description or "";
            language = "sh";
            title = name;
            type = "derivation";
            usage = "nix build .#checks.${system}.${name}";
          };
        configurationImpl =
          {
            configuration,
            name,
            source ? null,
          }:
          let
            hostName = toString (configuration.config.networking.hostName or "nixos");
            stated =
              let
                entries =
                  let
                    value = configuration.config.meta.description or [ ];
                  in
                  if builtins.isList value then value else [ ];
                matching = lib.filter (entry: source != null && toString (entry.file or "") == source) entries;
              in
              if matching != [ ] then
                (lib.last matching).value
              else if builtins.length entries == 1 then
                (lib.head entries).value
              else
                null;
            system = configuration.pkgs.stdenv.hostPlatform.system;
          in
          section.make {
            description =
              if stated != null then
                "${stated} (hostName ${hostName}, system ${system})"
              else
                "hostName ${hostName}, system ${system}";
            language = "sh";
            title = name;
            type = "NixOS configuration";
            usage = "nix build .#nixosConfigurations.${name}.config.system.build.toplevel";
          };
        functionImpl =
          {
            fn,
            name,
            internal ? false,
            namespace ? "lib",
            position ? null,
            sections ? [ ],
          }:
          let
            declared = if builtins.isAttrs fn then fn.meta or null else null;
            describe = spec: if builtins.isAttrs (spec.type or null) then spec.type.description or "" else "";
            metaArguments =
              if declared == null then
                [ ]
              else if builtins.isList (declared.args or null) then
                map (spec: {
                  argument = spec.name;
                  argumentDescription = spec.description or "";
                  argumentType = describe spec;
                }) declared.args
              else if builtins.isAttrs (declared.args or null) then
                lib.mapAttrsToList (argument: spec: {
                  inherit argument;
                  argumentDescription = spec.description or "";
                  argumentType = describe spec;
                }) declared.args
              else
                [ ];
            signature =
              if declared == null then
                ""
              else if builtins.isList (declared.args or null) then
                lib.concatStringsSep " " (map (spec: spec.name) declared.args)
              else if builtins.isAttrs (declared.args or null) then
                "{ ${lib.concatStringsSep ", " (builtins.attrNames declared.args)} }"
              else
                "";
          in
          section.make {
            inherit internal sections;
            arguments = metaArguments;
            description = declared.description or "";
            documented = declared != null && declared ? description;
            kind = "function";
            language = "nix";
            source = position;
            title = name;
            type = "function";
            usage = "${namespace}.${name}${lib.optionalString (signature != "") " ${signature}"}";
          };
        packageImpl =
          {
            name,
            package,
            checks ? [ ],
            formatter ? null,
          }:
          section.make {
            description = (package.meta or { }).description or "";
            language = "sh";
            tests = map (test: {
              inherit test;
              documented = lib.elem test checks;
            }) (builtins.attrNames (package.passthru.tests or { }));
            title = name;
            type = "derivation";
            usage =
              if formatter != null && (package.outPath or "") == (formatter.outPath or "^") then
                "nix fmt"
              else if ((package.meta or { }).mainProgram or null) != null then
                "nix run .#${name}"
              else
                "nix build .#${name}";
          };
        templateImpl =
          {
            name,
            template,
            url ? "",
          }:
          section.make {
            description = template.description or "";
            language = "sh";
            title = name;
            type = "template";
            usage = "nix flake init -t ${if url == "" then "." else url}#${name}";
          };
        valueImpl =
          {
            name,
            internal ? false,
            namespace ? "lib",
            position ? null,
            sections ? [ ],
            value ? null,
          }:
          let
            declared = if builtins.isAttrs value then value.meta or null else null;
          in
          section.make {
            inherit internal sections;
            description = declared.description or "";
            documented = declared != null && declared ? description;
            kind = "value";
            language = "nix";
            source = position;
            title = name;
            type =
              if builtins.isAttrs (declared.type or null) then
                declared.type.description or ""
              else
                declared.type or "";
            usage = "${namespace}.${name}";
          };
      in
      {
        app = {
          __functor = _self: appImpl;
          meta = {
            args = {
              app = {
                description = "the app record being documented";
                type = lib.types.attrs;
              };
              name = {
                description = "attribute name of the app";
                type = lib.types.str;
              };
            };
            description = "Documents one app: how to run it and what its meta.description says.";
          };
        };
        check = {
          __functor = _self: checkImpl;
          meta = {
            args = {
              check = {
                description = "the check derivation being documented";
                type = lib.types.package;
              };
              name = {
                description = "attribute name of the check";
                type = lib.types.str;
              };
              system = {
                description = "system string selecting the check set";
                type = lib.types.str;
              };
            };
            description = "Documents one check: how to build it and the assertions it makes.";
          };
        };
        configuration = {
          __functor = _self: configurationImpl;
          meta = {
            args = {
              configuration = {
                description = "the evaluated configuration being documented";
                type = lib.types.attrs;
              };
              name = {
                description = "attribute name of the configuration";
                type = lib.types.str;
              };
              source = {
                description = "path of the configuration file whose `meta.description` is read, null when the location is unknown";
                type = lib.types.nullOr lib.types.str;
              };
            };
            description = "Documents one NixOS configuration: how to build it, the description the host states for itself and its host name and system.";
          };
        };
        function = {
          __functor = _self: functionImpl;
          meta = {
            args = {
              fn = {
                description = "the declaration being documented, carrying meta.description and, when callable, meta.args";
                type = lib.types.anything;
              };
              internal = {
                description = "whether the function is outside the public surface, whose documentation may be omitted";
                type = lib.types.bool;
              };
              name = {
                description = "attribute name of the function, used to find its doc block";
                type = lib.types.str;
              };
              namespace = {
                description = "attribute path the function is reachable from, `lib` by default";
                type = lib.types.str;
              };
              position = {
                description = "{ file, line, path } where the function is bound, null when it is not bound in a source file";
                type = lib.types.nullOr lib.types.attrs;
              };
              sections = {
                description = "child sections already rendered for the function, such as the options of an exported type";
                type = lib.types.listOf lib.types.attrs;
              };
            };
            description = "Documents one exported function from the metadata it declares: how to call it, what it is for and what each argument is.";
          };
        };
        package = {
          __functor = _self: packageImpl;
          meta = {
            args = {
              checks = {
                description = "names of the checks this document links to, so passthru.tests entries become links";
                type = lib.types.listOf lib.types.str;
              };
              formatter = {
                description = "the flake's formatter for this system, so it is documented as `nix fmt` instead of a build";
                type = lib.types.nullOr lib.types.package;
              };
              name = {
                description = "attribute name of the package";
                type = lib.types.str;
              };
              package = {
                description = "the derivation being documented";
                type = lib.types.package;
              };
            };
            description = "Documents one package: how to run it when it has a mainProgram, how to build it otherwise, what its meta.description says, and which checks it is tested by.";
          };
        };
        template = {
          __functor = _self: templateImpl;
          meta = {
            args = {
              name = {
                description = "attribute name of the function, used to find its doc block";
                type = lib.types.str;
              };
              template = {
                description = "the template record, carrying the description its flake states";
                type = lib.types.attrs;
              };
              url = {
                description = "flake reference the templates are published under, `.` when the flake states none";
                type = lib.types.str;
              };
            };
            description = "Documents one template: how to initialise a flake from it and the description its flake states.";
          };
        };
        value = {
          __functor = _self: valueImpl;
          meta = {
            args = {
              internal = {
                description = "whether the value is part of the internal surface";
                type = lib.types.bool;
              };
              name = {
                description = "attribute name of the value";
                type = lib.types.str;
              };
              namespace = {
                description = "how the value is reached from the flake's library";
                type = lib.types.str;
              };
              position = {
                description = "{ file, line, path } where the value is bound, null when it is not bound in a source file";
                type = lib.types.nullOr lib.types.attrs;
              };
              sections = {
                description = "child sections already rendered for the value, such as the options of an exported type";
                type = lib.types.listOf lib.types.attrs;
              };
              value = {
                description = "the export being documented, carrying meta.description and meta.type";
                type = lib.types.anything;
              };
            };
            description = "Documents one exported value from the metadata it declares: what it is, the type label it states and where it is defined.";
          };
        };
      };
    documentation =
      let
        buildImpl =
          {
            pkgs,
            description,
            root,
            system,
            apps ? { },
            checks ? { },
            configurations ? { },
            flake ? null,
            formatter ? null,
            internalLibrary ? { },
            library ? { },
            modules ? { },
            packages ? { },
            requireInternalDocumentation ? false,
            templates ? { },
            url ? "",
          }:
          let
            contributedFor = contributed { inherit flake pkgs; };
            documentSurface =
              {
                namespace,
                surface,
                depth ? 2,
                internal ? false,
              }:
              map (
                n:
                let
                  position =
                    if rawPosition == null then null else rawPosition // { path = relativeOf rawPosition.file; };
                  rawPosition =
                    if builtins.isAttrs value && value ? meta then
                      builtins.unsafeGetAttrPos "meta" value
                    else
                      builtins.unsafeGetAttrPos n surface;
                  sections =
                    let
                      shape = shapeOf value;
                    in
                    lib.optional (shape != null) (
                      section.make {
                        bodyFile = optionsDoc pkgs (depth + 2) shape;
                        title = "Options";
                        usage = "";
                      }
                    );
                  value = surface.${n};
                in
                if isNamespace value then
                  section.make {
                    sections = documentSurface {
                      inherit internal;
                      depth = depth + 1;
                      namespace = "${namespace}.${n}";
                      surface = value;
                    };
                    title = n;
                    usage = "";
                  }
                else if builtins.isFunction value || (builtins.isAttrs value && value ? __functor) then
                  let
                    argumentSections = lib.filter (child: child != null) (map argumentShape specList);
                    argumentShape =
                      spec:
                      let
                        submodules = (spec.type or { }).getSubModules or null;
                      in
                      if submodules == null then
                        null
                      else
                        section.make {
                          sections = [
                            (section.make {
                              bodyFile = optionsDoc pkgs (depth + 3) (
                                lib.removeAttrs (lib.evalModules { modules = submodules; }).options [ "_module" ]
                              );
                              title = "Options";
                              usage = "";
                            })
                          ];
                          title = spec.name;
                          usage = "";
                        };
                    documented = document.function {
                      inherit
                        internal
                        namespace
                        position
                        sections
                        ;
                      fn = value;
                      name = n;
                    };
                    specList =
                      if builtins.isList specs then
                        specs
                      else if builtins.isAttrs specs then
                        lib.mapAttrsToList (specName: spec: spec // { name = specName; }) specs
                      else
                        [ ];
                    specs = if builtins.isAttrs value then value.meta.args or [ ] else [ ];
                  in
                  documented // { sections = documented.sections ++ argumentSections; }
                else
                  document.value {
                    inherit
                      internal
                      namespace
                      position
                      sections
                      value
                      ;
                    name = n;
                  }
              ) (exportsOf surface);
            documentedChecks = lib.filterAttrs (
              checkName: _:
              !(documentedPackages ? ${checkName})
              && !(lib.hasPrefix "devshell-" checkName)
              && !(lib.hasPrefix "pkgs-" checkName)
            ) checks;
            documentedPackages = lib.filterAttrs (_name: package: !(package.meta.internal or false)) packages;
            exportsOf = surface: lib.sort (a: b: a < b) (builtins.attrNames surface);
            files = map (group: {
              inherit (group) relative;
              doc = section.write {
                inherit pkgs;
                description = "${firstLine description} — ${lib.toLower group.title}";
                fromDir =
                  let
                    parent = lib.dirOf group.relative;
                  in
                  if parent == "." then "" else parent;
                name = group.title;
                sections = group.entries;
              };
              sections = group.entries;
            }) groupDocuments;
            groupDocuments =
              let
                declared = [
                  {
                    entries = lib.mapAttrsToList (
                      n: c:
                      document.configuration {
                        configuration = c;
                        name = n;
                        source = "${toString root}/hosts/${n}/configuration.nix";
                      }
                    ) configurations;
                    relative = "systems/README.md";
                    title = "Systems";
                  }
                  {
                    entries = map moduleSection moduleNames;
                    kind = "modules";
                    relative = "modules/README.md";
                    title = "Modules";
                  }
                  {
                    entries = lib.mapAttrsToList (
                      n: template:
                      document.template {
                        inherit template url;
                        name = n;
                      }
                    ) templates;
                    kind = "templates";
                    relative = "templates/README.md";
                    title = "Templates";
                  }
                  {
                    entries = lib.mapAttrsToList (
                      n: p:
                      document.package {
                        inherit formatter;
                        checks = builtins.attrNames documentedChecks;
                        name = n;
                        package = p;
                      }
                    ) documentedPackages;
                    kind = "packages";
                    relative = "packages/README.md";
                    title = "Packages";
                  }
                  {
                    entries = lib.mapAttrsToList (
                      n: a:
                      document.app {
                        app = a;
                        name = n;
                      }
                    ) apps;
                    kind = "apps";
                    relative = "apps/README.md";
                    title = "Apps";
                  }
                  {
                    entries = librarySections;
                    relative = "lib/README.md";
                    summary = libraryPublicSections;
                    title = "Library";
                    unsorted = true;
                  }
                  {
                    entries = lib.mapAttrsToList (
                      n: c:
                      document.check {
                        inherit system;
                        check = c;
                        name = n;
                      }
                    ) documentedChecks;
                    kind = "checks";
                    relative = "checks/README.md";
                    title = "Checks";
                  }
                ];
              in
              lib.filter (group: group.entries != [ ]) (
                map (
                  group:
                  group
                  // {
                    entries =
                      let
                        injected =
                          if group ? kind then
                            map (
                              entry:
                              entry
                              // {
                                source = if entry.source != null then entry.source else sourceOf group.kind entry.title;
                              }
                            ) group.entries
                          else
                            group.entries;
                      in
                      if group.unsorted or false then injected else lib.sort (a: b: a.title < b.title) injected;
                  }
                ) declared
              );
            groupEntries = group: group.summary or group.entries;
            groupSummary =
              group:
              section.group {
                inherit (group) title;
                body = lib.concatStringsSep "\n" (
                  map (
                    entry:
                    "- [${entry.title}](${group.relative}#${slug entry.title})"
                    + lib.optionalString (
                      (group.showDescriptions or true) && entry.description != ""
                    ) " — ${firstLine entry.description}"
                  ) (groupEntries group)
                );
              };
            groupSummaryOf =
              title:
              let
                group = lib.findFirst (each: each.title == title) null groupDocuments;
              in
              lib.optional (group != null && groupEntries group != [ ]) (groupSummary group);
            isNamespace =
              value:
              builtins.isAttrs value
              && !(value ? _type)
              && !(value ? meta)
              && !(value ? __functor)
              && !(value ? outPath)
              && builtins.attrNames value != [ ]
              && lib.all (n: builtins.isFunction value.${n} || builtins.isAttrs value.${n}) (
                builtins.attrNames value
              );
            libraryInternalSections = documentSurface {
              internal = true;
              namespace = "lib.internal";
              surface = internalLibrary;
            };
            libraryPublicSections = documentSurface {
              namespace = "lib";
              surface = library;
            };
            librarySections =
              if libraryPublicSections != [ ] && libraryInternalSections != [ ] then
                [
                  (section.group {
                    sections = libraryPublicSections;
                    title = "Public";
                  })
                  (section.group {
                    sections = libraryInternalSections;
                    title = "Internal";
                  })
                ]
              else
                libraryPublicSections ++ libraryInternalSections;
            moduleNames = lib.sort (a: b: a < b) (builtins.attrNames modules);
            moduleSection =
              moduleName:
              let
                info = contributedFor modules moduleName;
                inspectExample =
                  if info.example == null || !(builtins.isAttrs info.example) then
                    [ ]
                  else
                    let
                      checked = lib.evalModules {
                        modules = info.modulesFor ++ [ { config = info.example; } ];
                        specialArgs = { inherit pkgs; };
                      };
                      failures = lib.filter (
                        path: !(builtins.tryEval (lib.attrByPath path null checked.config)).success
                      ) (leaves [ ] info.example);
                      leaves =
                        path: value:
                        if builtins.isAttrs value then
                          builtins.concatMap (name: leaves (path ++ [ name ]) value.${name}) (builtins.attrNames value)
                        else
                          [ path ];
                    in
                    map (
                      path:
                      "the example sets ${lib.concatStringsSep "." path}, which is not a declared option of the module or does not match its declared type"
                    ) failures;
              in
              section.make {
                description = if info.description != "" then info.description else summary info;
                language = "nix";
                problems = inspectExample;
                sections =
                  lib.optional (info.names != [ ]) (
                    section.make {
                      bodyFile = optionsDoc pkgs 4 info.options;
                      title = "Options";
                      usage = "";
                    }
                  )
                  ++ lib.optional (info.example != null) (
                    section.make {
                      description = "A configuration that satisfies the interface above.";
                      language = "nix";
                      title = "example";
                      type = "example configuration";
                      usage =
                        if builtins.isString info.example then info.example else lib.generators.toPretty { } info.example;
                    }
                  );
                source = sourceOf "modules" moduleName;
                title = moduleName;
                type = "NixOS module";
                usage = "imports = [ inputs.<flake>.nixosModules.${moduleName} ];";
              };
            relativeOf =
              file:
              if lib.hasPrefix (toString root + "/") (toString file) then
                lib.removePrefix (toString root + "/") (toString file)
              else
                toString file;
            sections =
              groupSummaryOf "Templates"
              ++ groupSummaryOf "Apps"
              ++ groupSummaryOf "Systems"
              ++ groupSummaryOf "Modules"
              ++ groupSummaryOf "Packages"
              ++ groupSummaryOf "Library"
              ++ groupSummaryOf "Checks";
            shapeOf =
              value:
              let
                applied =
                  if builtins.isFunction subject then
                    if lib.all (argument: argument) (lib.attrValues arguments) then
                      builtins.tryEval (subject { })
                    else
                      { success = false; }
                  else
                    builtins.tryEval subject;
                arguments = if builtins.isFunction subject then builtins.functionArgs subject else { };
                evaluated =
                  if submodules == null then
                    null
                  else
                    builtins.tryEval (lib.evalModules { modules = lib.toList submodules; }).options;
                subject = if builtins.isAttrs value && value ? meta && value ? value then value.value else value;
                submodules =
                  if applied.success && builtins.isAttrs applied.value && applied.value ? getSubModules then
                    applied.value.getSubModules
                  else
                    null;
              in
              if evaluated != null && evaluated.success then
                lib.removeAttrs evaluated.value [ "_module" ]
              else
                null;
            slug = text: lib.replaceStrings [ " " ] [ "-" ] (lib.toLower text);
            sourceOf =
              kind: name:
              let
                file =
                  {
                    apps = "apps/${name}.nix";
                    checks = "checks/${name}.nix";
                    modules = "modules/nixos/${name}.nix";
                    packages = "packages/${name}.nix";
                    templates = "templates/${name}/flake.nix";
                  }
                  .${kind};
              in
              if builtins.pathExists (root + "/" + file) then
                {
                  inherit file;
                  line = null;
                }
              else
                null;
            summary = info: lib.concatStringsSep ", " (map (group: "${group}.*") info.names);
          in
          {
            inherit sections;
            inherit files;
            problems = problemsImpl {
              inherit description requireInternalDocumentation;
              sections = sections ++ lib.concatMap (group: group.entries) groupDocuments;
            };
            root = section.write {
              inherit description pkgs;
              inherit sections;
            };
          };
        problemsImpl =
          {
            description,
            sections,
            requireInternalDocumentation ? false,
          }:
          let
            all = lib.concatMap (flatten "") sections;
            flatten =
              prefix: section:
              [
                {
                  inherit prefix section;
                  path = if prefix == "" then section.title else "${prefix} / ${section.title}";
                }
              ]
              ++ lib.concatMap (flatten (
                if prefix == "" then section.title else "${prefix} / ${section.title}"
              )) section.sections;
            unlabelled = lib.filter (entry: entry.section.usage != "" && entry.section.language == "") all;
            unsigned = lib.filter (entry: lib.hasSuffix " " entry.section.usage) all;
            untyped = lib.filter (entry: entry.section.usage != "" && entry.section.type == "") all;
            withoutUsage = lib.filter (
              entry:
              entry.section.sections == [ ]
              && entry.section.usage == ""
              && entry.section.body == null
              && entry.section.bodyFile == null
            ) all;
          in
          lib.optional (
            description == ""
          ) "the flake description is empty: it is the only statement of what this flake is for"
          ++
            lib.optional (builtins.stringLength description < 40)
              "the flake description is ${toString (builtins.stringLength description)} characters: too short to say what this flake is for"
          ++ map (
            entry: "${entry.path}: documents a thing without a usage line, so how to use it is not stated"
          ) withoutUsage
          ++ map (
            entry: "${entry.path}: usage line carries no argument shape, so the call cannot be inferred"
          ) unsigned
          ++ map (
            entry:
            "${entry.path}: usage line carries no language label, so the syntax of the snippet is ambiguous"
          ) unlabelled
          ++ map (entry: "${entry.path}: names no type, so what the thing is cannot be stated") untyped
          ++ lib.concatMap (
            entry:
            map (
              argument:
              "${entry.path}: argument '${argument.argument}' has no documented type, so the reader cannot tell what to pass"
            ) (lib.filter (argument: argument.argumentType == "") entry.section.arguments)
          ) all
          ++
            map
              (
                entry:
                if (entry.section.kind or null) == "value" then
                  "${entry.path}: is an exported value that declares no meta.description, so nothing states what it is"
                else
                  "${entry.path}: is a function that declares no meta.description, so nothing states what it is for or what it accepts"
              )
              (
                lib.filter (
                  entry:
                  (entry.section.kind or null) != null
                  && !entry.section.documented
                  && (requireInternalDocumentation || !(entry.section.internal or false))
                ) all
              )
          ++ lib.concatMap (
            entry: map (problem: "${entry.path}: ${problem}") (entry.section.problems or [ ])
          ) all;
      in
      {
        build = {
          __functor = _self: buildImpl;
          meta = {
            args = {
              apps = {
                description = "attrset of apps to document";
                type = lib.types.attrs;
              };
              checks = {
                description = "attrset of checks to document";
                type = lib.types.attrs;
              };
              configurations = {
                description = "attrset of NixOS configurations to document";
                type = lib.types.attrs;
              };
              description = {
                description = "statement of what the flake is for, shown at the top of every document";
                type = lib.types.str;
              };
              flake = {
                description = "the flake whose modules are documented, supplying the module arguments a blueprint system provides";
                type = lib.types.nullOr lib.types.attrs;
              };
              formatter = {
                description = "derivation exposed as the flake formatter, documented as `nix fmt`";
                type = lib.types.nullOr lib.types.package;
              };
              internalLibrary = {
                description = "attrset of functions documented as part of the internal surface";
                type = lib.types.attrs;
              };
              library = {
                description = "attrset of functions documented as part of the public surface";
                type = lib.types.attrs;
              };
              modules = {
                description = "attrset of NixOS modules to document";
                type = lib.types.attrs;
              };
              packages = {
                description = "attrset of packages to document";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set used to build the documents";
                type = lib.types.attrs;
              };
              requireInternalDocumentation = {
                description = "whether an internal export must state meta.description too, false when the internal surface may stay opaque";
                type = lib.types.bool;
              };
              root = {
                description = "source tree the documents describe, read for module options";
                type = lib.types.path;
              };
              system = {
                description = "system the documented outputs belong to";
                type = lib.types.str;
              };
              templates = {
                description = "attrset of templates to document";
                type = lib.types.attrs;
              };
              url = {
                description = "flake reference the templates are published under, empty when the flake states none";
                type = lib.types.str;
              };
            };
            description = "Builds the documentation of a flake: one document per group of outputs, the modules, and the root index that links them.";
          };
        };
        problems = {
          __functor = _self: problemsImpl;
          meta = {
            args = {
              description = {
                description = "sentence stating what the flake is for";
                type = lib.types.str;
              };
              requireInternalDocumentation = {
                description = "whether an internal export must state meta.description too, false when the internal surface may stay opaque";
                type = lib.types.bool;
              };
              sections = {
                description = "the rendered sections that are inspected";
                type = lib.types.listOf lib.types.attrs;
              };
            };
            description = "Reports every way a rendered document falls short of being usable: purpose unstated, usage missing, arguments untyped.";
          };
        };
      };
    flake =
      let
        argsImpl =
          {
            pkgs,
            flake,
            checks ? null,
            description ? descriptionImpl { inherit root; },
            root ? flake.outPath,
          }:
          let
            library' = flake.libDeclarations or (flake.lib or { });
            system = pkgs.stdenv.hostPlatform.system;
            title = description;
          in
          {
            inherit pkgs root system;
            inherit flake;
            apps = flake.apps.${system} or { };
            checks = if checks == null then flake.checks.${system} or { } else checks;
            configurations = flake.nixosConfigurations or { };
            description = title;
            formatter = flake.formatter.${system} or null;
            internalLibrary = library'.internal or { };
            library = builtins.removeAttrs library' [ "internal" ];
            modules = flake.nixosModules or { };
            packages = flake.packages.${system} or { };
            requireInternalDocumentation = (flake.docsSettings or { }).requireInternalDocumentation or false;
            templates = flake.templates or { };
            url = flake.url or "";
          };
        descriptionImpl =
          { root }:
          let
            indented =
              if opening == null then
                null
              else
                builtins.match "[[:space:]]*description[[:space:]]*=[[:space:]]*''(.*)" opening;
            inline =
              if opening == null then
                null
              else
                builtins.match "[[:space:]]*description[[:space:]]*=[[:space:]]*''(.*)''[[:space:]]*;?" opening;
            lines = lib.splitString "\n" (builtins.readFile (root + "/flake.nix"));
            multiline =
              if indented == null then
                null
              else
                let
                  after = lib.drop 1 (
                    dropWhile (line: builtins.match "[[:space:]]*description[[:space:]]*=.*" line == null) lines
                  );
                  body = takeWhile (line: builtins.match ".*''[[:space:]]*;?" line == null) after;
                  closing = if lib.length body == lib.length after then null else lib.elemAt after (lib.length body);
                  content =
                    lib.optional (builtins.head indented != "") (builtins.head indented)
                    ++ body
                    ++ lib.optional hasContent lastPiece;
                  finish = if closing == null then null else builtins.match "^(.*)''[[:space:]]*;?$" closing;
                  hasContent = lastPiece != "" && builtins.match "[[:space:]]*" lastPiece == null;
                  lastPiece = if finish == null then "" else builtins.head finish;
                  rendered = lib.concatStringsSep "\n" (stripIndent content);
                in
                if closing == null then "" else rendered + lib.optionalString (!hasContent) "\n";
            opening = lib.findFirst (
              line: builtins.match "[[:space:]]*description[[:space:]]*=.*" line != null
            ) null lines;
            quoted =
              if opening == null then
                null
              else
                builtins.match "[[:space:]]*description[[:space:]]*=[[:space:]]*\"(.*)\"[[:space:]]*;?" opening;
          in
          if quoted != null then
            builtins.head quoted
          else if inline != null then
            builtins.head inline
          else if multiline != null then
            multiline
          else
            "";
      in
      {
        args = {
          __functor = _self: argsImpl;
          meta = {
            args = {
              checks = {
                description = "checks to document, every check of the flake by default; pass an empty set from a check, which cannot enumerate the checks without forcing itself";
                type = lib.types.nullOr lib.types.attrs;
              };
              description = {
                description = "statement of what the flake is for, the multiline description in flake.nix by default";
                type = lib.types.str;
              };
              flake = {
                description = "the flake whose outputs are documented";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set for the system being documented";
                type = lib.types.attrs;
              };
              root = {
                description = "source tree the documentation describes, the store copy of the flake by default";
                type = lib.types.path;
              };
            };
            description = "Derives the arguments that document a flake, from the flake itself, so a repository states nothing about its own documentation.";
          };
        };
        description = {
          __functor = _self: descriptionImpl;
          meta = {
            args.root = {
              description = "source tree containing flake.nix";
              type = lib.types.path;
            };
            description = "Reads the description a flake states about itself, which is the only statement of what the flake is for.";
          };
        };
      };
    gate =
      let
        docsImpl =
          {
            pkgs,
            flake,
            checks ? { },
            root ? flake.outPath,
          }:
          let
            inherit
              (
                (documentation.build (
                  everything.flake.args {
                    inherit
                      checks
                      flake
                      pkgs
                      root
                      ;
                  }
                ))
              )
              problems
              ;
          in
          if problems != [ ] then
            throw "Failed documentation problems:\n${lib.concatMapStrings (problem: "- ${problem}\n") problems}"
          else
            pkgs.stdenv.mkDerivation {
              buildCommand = ''
                echo "documentation is complete: no problem reported"
                touch $out
              '';
              meta.description = "Checks that the documentation of the flake is complete: every output states what it is and how to use it, and every public library function is documented.";
              name = "docgate-documentation";
            };
        flakeInputsImpl =
          {
            pkgs,
            root,
            ignore ? [ ],
          }:
          let
            goPath =
              acc: segments:
              if segments == [ ] then
                acc
              else
                let
                  here = lib.head segments;
                  rest = lib.tail segments;
                in
                if here == "." || here == "" then
                  goPath acc rest
                else if here == ".." then
                  goPath (lib.drop 1 acc) rest
                else
                  goPath (acc ++ [ here ]) rest;
            insideRoot = targetSegments: lib.lists.take (lib.length rootParts) targetSegments == rootParts;
            listed = lib.concatMapStrings (input: "  - ${input.name}: path:${input.path}\n") outside;
            lockPath = "${toString root}/flake.lock";
            outside = lib.filter (
              { path, ... }:
              !(insideRoot (resolveToSegments path))
            ) pathInputs;
            pathInputs =
              let
                hasRoot = lock ? root && lock.nodes ? root;
                inputs = if hasRoot then (lock.nodes.${lock.root}.inputs or { }) else { };
                lock = if builtins.pathExists lockPath then builtins.fromJSON (builtins.readFile lockPath) else { };
              in
              lib.concatLists (
                lib.mapAttrsToList (
                  name: key:
                  let
                    isDirect = builtins.isString key && hasRoot;
                    locked = node.locked or { };
                    node = lock.nodes.${key} or { };
                  in
                  lib.optional (isDirect && (locked.type or "") == "path" && !(lib.elem name ignore)) {
                    inherit (locked) path;
                    inherit name;
                  }
                ) inputs
              );
            resolveToSegments =
              path:
              if builtins.match "^/.*" path != null then
                goPath [ ] (lib.splitString "/" path)
              else
                goPath rootParts (lib.splitString "/" path);
            rootParts =
              let
                segs = lib.splitString "/" (toString root);
              in
              lib.filter (segment: segment != "") segs;
          in
          if outside == [ ] then
            pkgs.stdenv.mkDerivation {
              buildCommand = ''
                echo "all locked inputs resolve inside ${toString root}"
                touch $out
              '';
              meta.description = "Fails a flake whose flake.lock pins a path input that resolves outside the repository.";
              name = "docgate-flake-inputs";
            }
          else
            throw "flake.lock pins path inputs that resolve outside the repository (they build only here):\n${listed}";
        readmeImpl =
          {
            pkgs,
            description,
            root,
            system,
            apps ? { },
            checks ? { },
            configurations ? { },
            flake ? null,
            formatter ? null,
            internalLibrary ? { },
            library ? { },
            modules ? { },
            packages ? { },
            requireInternalDocumentation ? false,
            templates ? { },
            url ? "",
          }:
          let
            documentation' = documentation.build {
              inherit
                pkgs
                root
                system
                description
                requireInternalDocumentation
                apps
                checks
                configurations
                flake
                internalLibrary
                formatter
                library
                modules
                packages
                templates
                url
                ;
            };
          in
          pkgs.stdenv.mkDerivation {
            buildCommand = ''
              result="$out"
              out="$TMPDIR/generated"
              mkdir -p "$out"
              install -m 644 ${documentation'.root}/README.md "$out/README.md"
              ${lib.concatMapStrings (
                entry: "install -D -m 644 ${entry.doc}/README.md \"$out/${entry.relative}\"\n"
              ) documentation'.files}
              status=0
              strip_checks() {
                awk 'BEGIN { skip = 0 } /^## Checks$/ { skip = 1; next } skip == 1 && /^## / { skip = 0 } skip == 0 { print }' "$1"
              }
              while IFS= read -r -d "" found; do
                file="''${found#./}"
                hint="nix run .#docs"
                committed="${root}/$file"
                if [ "$file" = "README.md" ] && [ -f "$committed" ]; then
                  strip_checks "$committed" > "$TMPDIR/committed.md"
                  committed="$TMPDIR/committed.md"
                fi
                if [ ! -f "${root}/$file" ]; then
                  echo "missing: $file (create it with: $hint)" >&2
                  status=1
                elif ! diff -q "$out/$file" "$committed" > /dev/null; then
                  echo "out of date: $file (regenerate it with: $hint)" >&2
                  status=1
                fi
              done < <(cd "$out" && find . -type f -print0)
              while IFS= read -r -d "" found; do
                committedFile="''${found#./}"
                if [ "$committedFile" = "checks/README.md" ]; then
                  continue
                fi
                if [ ! -f "$out/$committedFile" ]; then
                  echo "stale: $committedFile (this flake does not generate it; delete it with: rm $committedFile)" >&2
                  status=1
                fi
              done < <(cd "${root}" && find . -iname '*readme*.md' -not -path './.git/*' -print0)
              if [ -d "${root}/checks" ] && [ -f "${root}/checks/README.md" ]; then
                while IFS= read -r -d "" source; do
                  checkName=$(basename "$source" .nix)
                  if ! grep -qx "## $checkName" "${root}/checks/README.md"; then
                    echo "checks/README.md has no section for $checkName (regenerate it with: nix run .#docs)" >&2
                    status=1
                  fi
                done < <(find "${root}/checks" -maxdepth 1 -name '*.nix' -print0)
                awk '
                  /^## / { name = substr($0, 4); next }
                  /^\*Type:\*/ { afterType = 1; next }
                  afterType && NF { print name "\t" $0; afterType = 0 }
                ' "${root}/checks/README.md" > "$TMPDIR/check-descriptions"
                while IFS="$(printf '\t')" read -r checkName checkDescription; do
                  [ -n "$checkName" ] || continue
                  if ! grep -Fq -- "- [$checkName](checks/README.md#$checkName) — $checkDescription" "${root}/README.md"; then
                    echo "README.md does not state the description checks/README.md gives $checkName (regenerate it with: nix run .#docs)" >&2
                    status=1
                  fi
                done < "$TMPDIR/check-descriptions"
                for listed in $(grep -o -- '- \[[^]]*\](checks/README.md#[^)]*)' "${root}/README.md" | sed -e 's|^- \[||; s|\](checks/README.md#.*||'); do
                  if ! grep -qx "## $listed" "${root}/checks/README.md"; then
                    echo "README.md lists $listed under Checks, which checks/README.md does not document (regenerate it with: nix run .#docs)" >&2
                    status=1
                  fi
                done
              fi
              if [ "$status" -ne 0 ]; then
                exit 1
              fi
              touch "$result"
            '';
            meta.description = "Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.";
            name = "readme-gate";
          };
      in
      {
        docs = {
          __functor = _self: docsImpl;
          meta = {
            args = {
              checks = {
                description = "checks to document, none by default, because a check cannot enumerate the checks without forcing itself";
                type = lib.types.attrs;
              };
              flake = {
                description = "the flake whose documentation is inspected";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set for the system being documented";
                type = lib.types.attrs;
              };
              root = {
                description = "source tree the documentation describes, the store copy of the flake by default";
                type = lib.types.path;
              };
            };
            description = "Fails evaluation when the documentation of a flake is incomplete, so a repository can make its documentation a check instead of a convention.";
          };
        };
        flakeInputs = {
          __functor = _self: flakeInputsImpl;
          meta = {
            args = {
              ignore = {
                description = "input names exempted from the check, for inputs that are intentionally the local working copy of another repository";
                type = lib.types.listOf lib.types.str;
              };
              pkgs = {
                description = "nixpkgs package set for the system the check is built on";
                type = lib.types.attrs;
              };
              root = {
                description = "repository root whose flake.lock is inspected";
                type = lib.types.path;
              };
            };
            description = "Fails a flake whose flake.lock pins a path input that resolves outside the repository, because such a flake builds only where that path exists.";
          };
        };
        readme = {
          __functor = _self: readmeImpl;
          meta = {
            args = {
              apps = {
                description = "attrset of apps to document, empty when the flake exports none";
                type = lib.types.attrs;
              };
              checks = {
                description = "attrset of checks to document, empty when the flake exports none";
                type = lib.types.attrs;
              };
              configurations = {
                description = "attrset of NixOS configurations to document";
                type = lib.types.attrs;
              };
              description = {
                description = "sentence saying what this flake is for";
                type = lib.types.str;
              };
              flake = {
                description = "the flake whose modules are documented, supplying the module arguments a blueprint system provides";
                type = lib.types.nullOr lib.types.attrs;
              };
              formatter = {
                description = "the derivation exposed as the flake formatter for this system";
                type = lib.types.nullOr lib.types.package;
              };
              internalLibrary = {
                description = "attrset of functions documented only in lib/README.md";
                type = lib.types.attrs;
              };
              library = {
                description = "attrset of functions to document in the index";
                type = lib.types.attrs;
              };
              modules = {
                description = "attrset of NixOS modules to document";
                type = lib.types.attrs;
              };
              packages = {
                description = "attrset of packages to document";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set used to render and compare the documents";
                type = lib.types.attrs;
              };
              requireInternalDocumentation = {
                description = "whether an internal export must state meta.description too, false when the internal surface may stay opaque";
                type = lib.types.bool;
              };
              root = {
                description = "path to the repository root holding the committed READMEs";
                type = lib.types.path;
              };
              system = {
                description = "system string selecting the documented outputs";
                type = lib.types.str;
              };
              templates = {
                description = "attrset of templates to document";
                type = lib.types.attrs;
              };
              url = {
                description = "flake reference the templates are published under, empty when the flake states none";
                type = lib.types.str;
              };
            };
            description = "Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.";
          };
        };
      };
    message =
      let
        assertionImpl =
          {
            at,
            condition,
            expected,
            fix,
            violation,
          }:
          {
            assertion = condition;
            message = ''
              ${renderPath at}: ${violation}
                expected: ${expected}
                how to fix: ${fix}
            '';
          };
        problemsImpl =
          {
            assertions,
            options,
          }:
          let
            firstLine = message: lib.head (lib.splitString "\n" message);
          in
          lib.concatMap (
            assertion:
            let
              declared = prefixed && lib.hasAttrByPath (lib.splitString "." path) options;
              parts = lib.splitString ": " (firstLine assertion.message);
              path = lib.head parts;
              prefixed = lib.length parts > 1;
            in
            lib.optional (!prefixed) "message has no '<path>: ' prefix: ${assertion.message}"
            ++ lib.optional (prefixed && !declared) "message names '${path}', which is not a declared option"
            ++ lib.optional (
              !(lib.hasInfix "expected:" assertion.message)
            ) "message has no 'expected:' line: ${path}"
            ++ lib.optional (
              !(lib.hasInfix "how to fix:" assertion.message)
            ) "message has no 'how to fix:' line: ${path}"
          ) assertions;
      in
      {
        assertion = {
          __functor = _self: assertionImpl;
          meta = {
            args = {
              at = {
                description = "list of attribute names naming the option the assertion is about";
                type = lib.types.listOf lib.types.str;
              };
              condition = {
                description = "the property being asserted, true when it holds";
                type = lib.types.bool;
              };
              expected = {
                description = "sentence saying what the configuration should look like instead";
                type = lib.types.str;
              };
              fix = {
                description = "sentence saying how to make it look that way";
                type = lib.types.str;
              };
              violation = {
                description = "sentence saying what is wrong when the condition is false";
                type = lib.types.str;
              };
            };
            description = "Builds an assertion record whose message states the violation, what was expected and how to fix it.";
          };
        };
        problems = {
          __functor = _self: problemsImpl;
          meta = {
            args = {
              assertions = {
                description = "list of { assertion, message } records whose messages are inspected";
                type = lib.types.listOf lib.types.attrs;
              };
              options = {
                description = "evaluated option set the message paths are resolved against";
                type = lib.types.attrs;
              };
            };
            description = "Reports assertion messages that do not name a declared option, or that omit the expected value and the fix.";
          };
        };
      };
    section =
      let
        groupImpl =
          {
            title,
            body ? null,
            sections ? [ ],
          }:
          {
            inherit sections title;
            inherit body;
            arguments = [ ];
            bodyFile = null;
            description = "";
            documented = true;
            language = "";
            source = null;
            tests = [ ];
            type = "";
            usage = "";
          };
        makeImpl =
          {
            title,
            usage,
            arguments ? [ ],
            body ? null,
            bodyFile ? null,
            description ? "",
            documented ? true,
            internal ? false,
            kind ? null,
            language ? "",
            problems ? [ ],
            sections ? [ ],
            source ? null,
            tests ? [ ],
            type ? "",
          }:
          {
            inherit
              title
              usage
              description
              kind
              documented
              internal
              language
              arguments
              type
              body
              bodyFile
              problems
              sections
              source
              tests
              ;
          };
        renderImpl =
          {
            depth,
            s,
            fromDir ? "",
          }:
          let
            esc = lib.escapeShellArg;
            head = "${lib.concatStringsSep "" (lib.genList (_: "#") depth)} ${s.title}";
            sourceLink =
              if fromDir != "" && lib.hasPrefix "${fromDir}/" sourcePath then
                lib.removePrefix "${fromDir}/" sourcePath
              else
                sourcePath;
            sourcePath = s.source.path or s.source.file;
          in
          [ "printf '%s\n\n' ${esc head} >> $out/README.md" ]
          ++ lib.optionals (s.usage != "") [
            "printf '```%s\n%s\n```\n\n' ${esc s.language} ${esc s.usage} >> $out/README.md"
          ]
          ++ lib.optionals (s.type != "") [
            "printf '*Type:* %s\n\n' ${esc s.type} >> $out/README.md"
          ]
          ++ lib.optionals (s.tests != [ ]) [
            "printf '*Tests:* %s\n\n' ${
              esc (renderTestLinks {
                inherit (s) tests;
              })
            } >> $out/README.md"
          ]
          ++ lib.optionals (s.arguments != [ ]) [
            "printf '*Arguments:*\n\n' >> $out/README.md"
          ]
          ++ lib.concatMap (argument: [
            (
              if (argument.argumentDescription or "") != "" then
                "printf -- '- `%s` (`*%s*`): %s\n' ${esc argument.argument} ${
                  esc (if argument.argumentType != "" then argument.argumentType else "no type stated")
                } ${esc argument.argumentDescription} >> $out/README.md"
              else
                "printf -- '- `%s`: %s\n' ${esc argument.argument} ${
                  esc (if argument.argumentType != "" then argument.argumentType else "undocumented type")
                } >> $out/README.md"
            )
          ]) s.arguments
          ++ lib.optionals (s.arguments != [ ]) [ "printf '\n' >> $out/README.md" ]
          ++ lib.optionals (s.description != "") [
            "printf '%s\n\n' ${esc s.description} >> $out/README.md"
          ]
          ++ lib.optionals (s.source != null) [
            "printf '*Source:* [%s](%s)\n\n' ${
              esc (sourcePath + lib.optionalString (s.source.line != null) ":${toString s.source.line}")
            } ${esc sourceLink} >> $out/README.md"
          ]
          ++ lib.optionals (s.body != null) [
            "printf '%s\n\n' ${esc s.body} >> $out/README.md"
          ]
          ++ lib.optionals (s.bodyFile != null) [
            "cat ${s.bodyFile} >> $out/README.md"
            "printf '\n' >> $out/README.md"
          ]
          ++ lib.concatMap (
            s:
            renderImpl {
              inherit s fromDir;
              depth = depth + 1;
            }
          ) s.sections;
        testsImpl = renderTestLinks;
        writeImpl =
          {
            pkgs,
            description,
            sections,
            fromDir ? "",
            name ? "",
          }:
          let
            body = if name == "" then descriptionBody description else description;
            title = if name == "" then firstLine description else name;
          in
          pkgs.stdenv.mkDerivation {
            buildCommand = ''
              mkdir -p $out
              printf '# %s\n\n' ${lib.escapeShellArg title} > $out/README.md
              ${lib.optionalString (body != "") "printf '%s\\n\\n' ${lib.escapeShellArg body} >> $out/README.md"}
              ${lib.concatStringsSep "\n" (
                lib.concatMap (
                  s:
                  renderImpl {
                    inherit s fromDir;
                    depth = 2;
                  }
                ) sections
              )}
            '';
            meta.description = "Rendered documentation: the repository README plus one README per module.";
            name = "documentation-${name}";
          };
      in
      {
        group = {
          __functor = _self: groupImpl;
          meta = {
            args = {
              body = {
                description = "markdown emitted under the title instead of child headings, null when there is none";
                type = lib.types.nullOr lib.types.str;
              };
              sections = {
                description = "child sections, rendered one heading level deeper, empty when the group only holds prose";
                type = lib.types.listOf lib.types.attrs;
              };
              title = {
                description = "heading text of the group";
                type = lib.types.str;
              };
            };
            description = "Groups child sections under one title, for a part of the document that is itself not a usable thing.";
          };
        };
        make = {
          __functor = _self: makeImpl;
          meta = {
            args = {
              arguments = {
                description = "list of { argument, argumentType } describing the call shape";
                type = lib.types.listOf lib.types.attrs;
              };
              body = {
                description = "markdown emitted under the title, null when there is none";
                type = lib.types.nullOr lib.types.str;
              };
              bodyFile = {
                description = "path to a rendered markdown fragment appended after the description";
                type = lib.types.nullOr lib.types.path;
              };
              description = {
                description = "sentence saying what the thing is for, empty when the title says it";
                type = lib.types.str;
              };
              documented = {
                description = "whether authored prose exists for the thing, false when it is undocumented";
                type = lib.types.bool;
              };
              internal = {
                description = "whether the thing belongs to the internal surface, which is published but not part of the flake's contract";
                type = lib.types.bool;
              };
              kind = {
                description = "what sort of thing it is when the doc block describes it, function or value, null for sections that are not library exports";
                type = lib.types.nullOr lib.types.str;
              };
              language = {
                description = "code fence language of the usage snippet, for example nix or sh";
                type = lib.types.str;
              };
              problems = {
                description = "problems found while documenting this thing, each reported as a check failure";
                type = lib.types.listOf lib.types.str;
              };
              sections = {
                description = "child sections, rendered one heading level deeper";
                type = lib.types.listOf lib.types.attrs;
              };
              source = {
                description = "{ file, line } naming where the thing is defined in this repository, null when the location is unknown";
                type = lib.types.nullOr lib.types.attrs;
              };
              tests = {
                description = "list of { test, documented } naming the checks the thing is tested by";
                type = lib.types.listOf lib.types.attrs;
              };
              title = {
                description = "heading text naming the thing";
                type = lib.types.str;
              };
              type = {
                description = "what the thing is, for example derivation, app or NixOS module";
                type = lib.types.str;
              };
              usage = {
                description = "snippet that uses the thing, shown in a fenced block";
                type = lib.types.str;
              };
            };
            description = "One documented thing: what it is, how to call or import it, what its arguments are and any child sections.";
          };
        };
        render = {
          __functor = _self: renderImpl;
          meta = {
            args = {
              depth = {
                description = "heading level of the section, 2 for a top-level section of a document";
                type = lib.types.int;
              };
              fromDir = {
                description = "directory the rendered document lives in, so source links resolve relative to it";
                type = lib.types.str;
              };
              s = {
                description = "the section to render";
                type = lib.types.attrs;
              };
            };
            description = "Renders a list of sections into a README derivation.";
          };
        };
        tests = {
          __functor = _self: testsImpl;
          meta = {
            args.tests = {
              description = "list of { test, documented } records naming the checks a package is tested by";
              type = lib.types.listOf lib.types.attrs;
            };
            description = "Renders the test links of a section: a markdown link when the check is documented, plain text when it is not.";
          };
        };
        write = {
          __functor = _self: writeImpl;
          meta = {
            args = {
              description = {
                description = "statement of what the flake is for, printed under the title; when name is empty its first line titles the document and the rest of it is printed under that title";
                type = lib.types.str;
              };
              fromDir = {
                description = "directory the rendered document lives in, so source links resolve relative to it";
                type = lib.types.str;
              };
              name = {
                description = "title of the document, the first line of the description when it is empty";
                type = lib.types.str;
              };
              pkgs = {
                description = "nixpkgs package set the document derivation is built with";
                type = lib.types.attrs;
              };
              sections = {
                description = "sections to render, in order";
                type = lib.types.listOf lib.types.attrs;
              };
            };
            description = "Writes one document: a heading, the statement of purpose, and the sections rendered in order.";
          };
        };
      };
    shells =
      let
        devImpl =
          {
            pkgs,
            preCommit,
            devShellConfig ? { },
          }:
          let
            evaluated = lib.evalModules {
              modules = [
                {
                  config = {
                    inherit (preCommit) shellHook;
                    buildInputs = preCommit.enabledPackages;
                  };
                  options = {
                    buildInputs = lib.mkOption {
                      description = "Packages placed on the development shell's PATH.";
                      type = lib.types.listOf lib.types.package;
                    };
                    shellHook = lib.mkOption {
                      description = "Shell commands run when the development shell is entered.";
                      type = lib.types.lines;
                    };
                  };
                }
                devShellConfig
              ];
            };
          in
          pkgs.mkShell {
            inherit (evaluated.config) buildInputs shellHook;
          };
      in
      {
        dev = {
          __functor = _self: devImpl;
          meta = {
            args = {
              devShellConfig = {
                description = "evalModule-shaped configuration merged into the default development shell";
                type = lib.types.attrs;
              };
              pkgs = {
                description = "nixpkgs package set the shell is built with";
                type = lib.types.attrs;
              };
              preCommit = {
                description = "pre-commit check whose packages and hook the shell exposes";
                type = lib.types.attrs;
              };
            };
            description = "Shell environment carrying the formatter's packages and its shell hook.";
          };
        };
      };
  };
  firstFalse =
    predicate: list:
    lib.findFirst (index: !(predicate (lib.elemAt list index))) (lib.length list) (
      lib.genList (index: index) (lib.length list)
    );
  firstLine = description: builtins.head (lib.splitString "\n" description);
  flattenOptions =
    prefix: options:
    lib.concatLists (
      lib.mapAttrsToList (
        name: value:
        let
          path = prefix ++ [ name ];
        in
        if !(builtins.isAttrs value) then
          [ ]
        else if (value._type or null) == "option" then
          [
            {
              inherit path value;
            }
          ]
        else
          flattenOptions path value
      ) options
    );
  harness = {
    config.networking.domain = "test";
    imports = import (inputs.nixpkgs.outPath + "/nixos/modules/module-list.nix");
  };
  lib = inputs.nixpkgs.lib;
  metaOptions = ../lib/meta-options.nix;
  optionMarkdown =
    depth: options:
    let
      heading = lib.concatStringsSep "" (lib.genList (_: "#") depth);
      render =
        path: value:
        if value ? _type && value._type == "option" then
          renderOption path value
        else
          lib.concatStrings (lib.mapAttrsToList (name: child: render (path ++ [ name ]) child) value);
      renderOption =
        path: option:
        let
          default =
            if rendered.success && rendered.value != "null" then
              ''
                *Default:*

                ```nix
                ${rendered.value}
                ```
              ''
            else
              "";
          example =
            if renderedExample.success && renderedExample.value != null then
              ''
                *Example:*

                ```nix
                ${renderedExample.value}
                ```
              ''
            else
              "";
          rendered =
            if option ? defaultText then
              {
                success = true;
                value = if builtins.isAttrs option.defaultText then option.defaultText.text else option.defaultText;
              }
            else if option ? default then
              builtins.tryEval (lib.generators.toPretty { } option.default)
            else
              { success = false; };
          renderedExample = builtins.tryEval (
            if option ? example && option.example != null then
              lib.generators.toPretty { } option.example
            else
              null
          );
        in
        lib.concatStringsSep "\n\n" (
          lib.filter (part: part != "") [
            "${heading} ${lib.concatStringsSep "." path}"
            (option.description or "")
            "*Type:* ${option.type.description or "value"}"
            default
            example
            (lib.optionalString (option.internal or false) "**Internal.**")
          ]
        )
        + "\n\n";
    in
    render [ ] options;
  optionsDoc =
    pkgs: depth: options:
    pkgs.writeText "options.md" (optionMarkdown depth options);
  renderPath = path: lib.concatStringsSep "." path;
  renderTestLinks =
    { tests }:
    lib.concatStringsSep ", " (
      map (
        test:
        if test.documented then
          "[${test.test}](#${lib.replaceStrings [ " " ] [ "-" ] (lib.toLower test.test)})"
        else
          test.test
      ) tests
    );
  stripIndent =
    lines:
    let
      indentOf = line: builtins.stringLength (builtins.head (builtins.match "([[:space:]]*).*" line));
      meaningful = lib.filter (line: line != "") lines;
      stripped =
        line:
        let
          amount = lib.min width (indentOf line);
        in
        lib.substring amount (builtins.stringLength line - amount) line;
      width = if meaningful == [ ] then 0 else lib.foldl' lib.min 999999 (map indentOf meaningful);
    in
    map stripped lines;
  takeWhile = predicate: list: lib.take (firstFalse predicate list) list;
  words =
    text:
    let
      separators = [
        "`"
        "("
        ")"
        "["
        "]"
        ","
        "."
        ":"
        ";"
        "\n"
        "\t"
      ];
    in
    lib.filter (part: part != "") (
      lib.splitString " " (
        lib.replaceStrings separators (lib.genList (_: " ") (lib.length separators)) text
      )
    );
in
# The whole library is internal: consumers call the base flake directly, and the callable mixin supplies the
# documentation arguments, the gates, the pre-commit hook set and the development shell, so nothing needs to be
# public on the library itself.
{
  internal = everything;
}
