{ inputs, ... }:
let
  contributed =
    modules: moduleName:
    let
      added = lib.subtractLists (builtins.attrNames baseline) (builtins.attrNames evaluated.options);
      baseline = (lib.evalModules { modules = [ harness ]; }).options;
      described = builtins.tryEval evaluated.config.meta.description;
      evaluated = lib.evalModules {
        modules = [
          harness
          modules.${moduleName}
        ];
      };
    in
    {
      description = if described.success then described.value else "";
      names = added;
      options = lib.genAttrs added (optionName: evaluated.options.${optionName});
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
  docBlocksFor =
    source:
    let
      argumentTypeOf =
        name: argument:
        let
          found = lib.findFirst (entry: entry.argument == argument) null (docArguments name);
        in
        if found == null then "" else found.argumentType;
      commentBefore =
        name:
        let
          index = declaredAt name;
          preceding = lib.reverseList (lib.take (if index == null then 0 else index) sourceLines);
        in
        lib.reverseList (takeWhile (line: lib.hasPrefix "#" (trimLeft line)) preceding);
      declaredAt =
        name:
        let
          found = lib.findFirst (
            entry: builtins.match "[[:space:]]+${name} =.*" entry.line != null
          ) null indexedLines;
        in
        if found == null then null else found.i;
      docArguments =
        name:
        let
          argumentOf =
            entry:
            let
              parsed = builtins.match "- `([^\`]+)`: (.+)" entry.bullet;
            in
            if parsed == null then
              [ ]
            else
              [
                {
                  argument = builtins.elemAt parsed 0;
                  argumentType = lib.concatStringsSep " " ([ (builtins.elemAt parsed 1) ] ++ entry.continuation);
                }
              ];
          fromArguments = dropWhile (line: line != "# Arguments") (docLines name);
          grouped = lib.foldl' (
            acc: line:
            if isBullet line then
              acc
              ++ [
                {
                  bullet = line;
                  continuation = [ ];
                }
              ]
            else if acc == [ ] then
              acc
            else
              let
                previous = lib.last acc;
              in
              lib.init acc
              ++ [
                {
                  inherit (previous) bullet;
                  continuation = previous.continuation ++ [ (trimLeft line) ];
                }
              ]
          ) [ ] fromArguments;
          isBullet = line: lib.hasPrefix "- `" line;
        in
        lib.concatMap argumentOf grouped;
      docLines =
        name:
        map (
          line:
          let
            trimmed = trimLeft line;
          in
          if trimmed == "#" then
            ""
          else if lib.hasPrefix "# " trimmed then
            lib.removePrefix "# " trimmed
          else
            ""
        ) (commentBefore name);
      docSummary =
        name:
        lib.concatStringsSep " " (
          takeWhile (line: line != "" && line != "# Arguments") (
            lib.filter (line: line != "") (takeWhile (line: line != "# Arguments") (docLines name))
          )
        );
      hasDocBlock = name: commentBefore name != [ ];
      indexedLines = lib.imap0 (i: line: { inherit i line; }) sourceLines;
      sourceFiles =
        if builtins.pathExists source then
          lib.filter (file: lib.hasSuffix ".nix" (toString file)) (lib.filesystem.listFilesRecursive source)
        else
          [ ];
      sourceLines = lib.splitString "\n" (
        lib.concatMapStrings (file: builtins.readFile file + "\n") sourceFiles
      );
    in
    {
      inherit
        argumentTypeOf
        docArguments
        docLines
        docSummary
        hasDocBlock
        ;
    };
  dropWhile = predicate: list: lib.drop (firstFalse predicate list) list;
  everything = rec {
    # Reports descriptions that are missing, too short to state a contract, repeated, or that name another component of the flake.
    #
    # # Arguments
    # - `options`: evaluated option set whose descriptions are inspected
    # - `components`: names of the components this flake is built from, whose mention is reported
    # - `allowComponents`: component names that may be mentioned without being reported
    descriptionsProblems =
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
    # Shell environment carrying the formatter's packages and its shell hook.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set the shell is built with
    # - `preCommit`: pre-commit check whose packages and hook the shell exposes
    devShell =
      { pkgs, preCommit }:
      pkgs.mkShell {
        inherit (preCommit) shellHook;
        buildInputs = preCommit.enabledPackages;
      };
    # Writes one generated README into the working tree, for the repository or for one named module.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set the wrapper script runs with; the flake it documents is read from the working directory
    docsApp =
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
          args = base.lib.flakeArgs { inherit description flake pkgs; };
        in
        base.lib.internal.docsTree args
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
          --module)
            shift
            module="$1"
            ;;
          *)
            echo "usage: docs [--check | --module NAME]" >&2
            exit 2
            ;;
        esac
        if [ -f "$tree/modules/nixos/$module/README.md" ]; then
          target="modules/nixos/$module/README.md"
        elif [ -f "$tree/modules/nixos/$module.README.md" ]; then
          target="modules/nixos/$module.README.md"
        else
          echo "no module '$module' is documented by this flake" >&2
          exit 1
        fi
        install -D -m 644 "$tree/$target" "$PWD/$target"
        echo "wrote $target"
      '')
      // {
        meta.description = "Writes the generated documentation into the working tree, or checks that it is current and staged.";
      };
    # Fails evaluation when the documentation of a flake is incomplete, so a repository can make its documentation a
    # check instead of a convention.
    #
    # # Arguments
    # - `flake`: the flake whose documentation is inspected
    # - `pkgs`: nixpkgs package set for the system being documented
    # - `root`: source tree the documentation describes, the store copy of the flake by default
    # - `librarySource`: directory holding the library sources whose doc blocks are read, `<root>/lib` by default
    # - `checks`: checks to document, none by default, because a check cannot enumerate the checks without forcing itself
    docsGate =
      {
        pkgs,
        flake,
        checks ? { },
        librarySource ? root + "/lib",
        root ? flake.outPath,
      }:
      let
        inherit
          (
            (documentation (flakeArgs {
              inherit
                checks
                flake
                librarySource
                pkgs
                root
                ;
            }))
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
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set used to render option documentation
    # - `root`: path to the repository root, used to locate module files
    # - `system`: system string selecting the packages, apps and checks to document
    # - `description`: sentence saying what this flake is for
    # - `apps`: attrset of apps to document, empty when the flake exports none
    # - `formatter`: the derivation exposed as the flake formatter for this system
    # - `checks`: attrset of checks to document, empty when the flake exports none
    # - `configurations`: attrset of NixOS configurations to document
    # - `library`: attrset of functions to document in the index
    # - `internalLibrary`: attrset of functions documented only in lib/README.md
    # - `modules`: attrset of NixOS modules to document
    # - `packages`: attrset of packages to document
    # - `templates`: attrset of templates to document
    # - `url`: flake reference the templates are published under, empty when the flake states none
    # - `librarySource`: directory holding the library sources whose doc blocks are read
    docsTree =
      {
        pkgs,
        description,
        root,
        system,
        apps ? { },
        checks ? { },
        configurations ? { },
        formatter ? null,
        internalLibrary ? { },
        library ? { },
        librarySource ? root + "/lib",
        modules ? { },
        packages ? { },
        templates ? { },
        url ? "",
      }:
      let
        documentation' = documentation {
          inherit
            pkgs
            root
            system
            description
            apps
            checks
            configurations
            formatter
            internalLibrary
            library
            modules
            packages
            templates
            url
            librarySource
            ;
        };
      in
      pkgs.stdenv.mkDerivation {
        buildCommand = ''
          mkdir -p $out
          install -m 644 ${documentation'.root}/README.md $out/README.md
          ${lib.concatMapStrings (
            entry: "install -D -m 644 ${entry.doc}/README.md $out/${entry.relative}\n"
          ) (documentation'.modules ++ documentation'.files)}
        '';
        meta.description = "Documentation tree: the repository README plus one README per module.";
        name = "docs-tree";
      };
    # Documents one app: how to run it and what its meta.description says.
    #
    # # Arguments
    # - `name`: attribute name of the app
    # - `app`: the app record being documented
    documentApp =
      { app, name }:
      section {
        description = app.meta.description or "";
        language = "sh";
        title = name;
        type = "app";
        usage = "nix run .#${name}";
      };
    # Documents one check: how to build it and the assertions it makes.
    #
    # # Arguments
    # - `system`: system string selecting the check set
    # - `name`: attribute name of the check
    # - `check`: the check derivation being documented
    documentCheck =
      {
        check,
        name,
        system,
      }:
      section {
        description = check.meta.description or "";
        language = "sh";
        title = name;
        type = "derivation";
        usage = "nix build .#checks.${system}.${name}";
      };
    # Documents one NixOS configuration: how to build it, its host name and its system.
    #
    # # Arguments
    # - `name`: attribute name of the configuration
    # - `configuration`: the evaluated configuration being documented
    documentConfiguration =
      { configuration, name }:
      section {
        description = "hostName ${
          toString (configuration.config.networking.hostName or "nixos")
        }, system ${configuration.pkgs.stdenv.hostPlatform.system}";
        language = "sh";
        title = name;
        type = "NixOS configuration";
        usage = "nix build .#nixosConfigurations.${name}.config.system.build.toplevel";
      };
    # Documents one function: how to call it, what it is for, and what each argument is.
    #
    # # Arguments
    # - `fn`: the function being documented
    # - `name`: attribute name of the function, used to find its doc block
    # - `namespace`: attribute path the function is reachable from, `lib` by default
    # - `source`: directory holding the library sources whose doc blocks are read, the flake library by default
    # - `internal`: whether the function is outside the public surface, whose documentation may be omitted
    documentFunction =
      {
        fn,
        name,
        internal ? false,
        namespace ? "lib",
        source ? ./.,
      }:
      let
        argumentNames = if probed.success then builtins.attrNames probed.value else [ ];
        blocks = docBlocksFor source;
        probed = builtins.tryEval (builtins.functionArgs fn);
      in
      section {
        inherit internal;
        arguments = map (argument: {
          inherit argument;
          argumentType = blocks.argumentTypeOf name argument;
        }) argumentNames;
        description = blocks.docSummary name;
        documented = blocks.hasDocBlock name;
        language = "nix";
        title = name;
        type = "function";
        usage = "${namespace}.${name} ${functionSignature fn}";
      };
    # Documents one package: how to run it when it has a mainProgram, how to build it otherwise, what its
    # meta.description says, and which checks it is tested by.
    #
    # # Arguments
    # - `name`: attribute name of the package
    # - `package`: the derivation being documented
    # - `checks`: names of the checks this document links to, so passthru.tests entries become links
    # - `formatter`: the flake's formatter for this system, so it is documented as `nix fmt` instead of a build
    documentPackage =
      {
        name,
        package,
        checks ? [ ],
        formatter ? null,
      }:
      section {
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
    # Documents one library function: its call shape, the types from the doc block above it, and the doc block's summary.
    #
    # # Arguments
    # - `name`: attribute name of the function, used to find its doc block
    # - `fn`: the function being documented
    # - `namespace`: attribute path the function is reachable from, so the usage snippet can be called as written
    # Documents one flake template: how to instantiate it and what it says it is for.
    #
    # # Arguments
    # - `name`: attribute name of the template
    # - `template`: the template record, carrying the description its flake states
    # - `url`: flake reference the templates are published under, `.` when the flake states none
    documentTemplate =
      {
        name,
        template,
        url ? "",
      }:
      section {
        description = template.description or "";
        language = "sh";
        title = name;
        type = "template";
        usage = "nix flake init -t ${if url == "" then "." else url}#${name}";
      };
    # Builds the documentation of a flake: one document per group of outputs, the modules, and the root index that
    # links them.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set used to build the documents
    # - `description`: statement of what the flake is for, shown at the top of every document
    # - `name`: name of the flake, used in the document headings
    # - `root`: source tree the documents describe, read for module options
    # - `system`: system the documented outputs belong to
    # - `apps`: attrset of apps to document
    # - `checks`: attrset of checks to document
    # - `configurations`: attrset of NixOS configurations to document
    # - `formatter`: derivation exposed as the flake formatter, documented as `nix fmt`
    # - `internalLibrary`: attrset of functions documented as part of the internal surface
    # - `library`: attrset of functions documented as part of the public surface
    # - `modules`: attrset of NixOS modules to document
    # - `packages`: attrset of packages to document
    # - `templates`: attrset of templates to document
    # - `url`: flake reference the templates are published under, empty when the flake states none
    # - `librarySource`: directory holding the library sources whose doc blocks are read
    documentation =
      {
        pkgs,
        description,
        root,
        system,
        apps ? { },
        checks ? { },
        configurations ? { },
        formatter ? null,
        internalLibrary ? { },
        library ? { },
        librarySource ? root + "/lib",
        modules ? { },
        packages ? { },
        templates ? { },
        url ? "",
      }:
      let
        documentedChecks = lib.filterAttrs (
          checkName: _:
          !(documentedPackages ? ${checkName})
          && !(lib.hasPrefix "devshell-" checkName)
          && !(lib.hasPrefix "pkgs-" checkName)
        ) checks;
        documentedPackages = lib.filterAttrs (_name: package: !(package.meta.internal or false)) packages;
        files = map (group: {
          inherit (group) relative;
          doc = writeDocumentation {
            inherit pkgs;
            description = "${firstLine description} — ${lib.toLower group.title}";
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
                  documentConfiguration {
                    configuration = c;
                    name = n;
                  }
                ) configurations;
                relative = "systems/README.md";
                title = "Systems";
              }
              {
                entries = lib.mapAttrsToList (
                  n: template:
                  documentTemplate {
                    inherit template url;
                    name = n;
                  }
                ) templates;
                relative = "templates/README.md";
                title = "Templates";
              }
              {
                entries = lib.mapAttrsToList (
                  n: p:
                  documentPackage {
                    inherit formatter;
                    checks = builtins.attrNames documentedChecks;
                    name = n;
                    package = p;
                  }
                ) documentedPackages;
                relative = "packages/README.md";
                title = "Packages";
              }
              {
                entries = lib.mapAttrsToList (
                  n: a:
                  documentApp {
                    app = a;
                    name = n;
                  }
                ) apps;
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
                  documentCheck {
                    inherit system;
                    check = c;
                    name = n;
                  }
                ) documentedChecks;
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
                  if group.unsorted or false then group.entries else lib.sort (a: b: a.title < b.title) group.entries;
              }
            ) declared
          );
        groupEntries = group: group.summary or group.entries;
        groupSummary =
          group:
          mkSection {
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
        libraryInternalSections =
          map
            (
              n:
              documentFunction {
                fn = internalLibrary.${n};
                internal = true;
                name = n;
                namespace = "lib.internal";
                source = librarySource;
              }
            )
            (
              lib.sort (a: b: a < b) (
                builtins.attrNames (lib.filterAttrs (_name: builtins.isFunction) internalLibrary)
              )
            );
        libraryPublicSections =
          map
            (
              n:
              documentFunction {
                fn = library.${n};
                name = n;
                source = librarySource;
              }
            )
            (
              lib.sort (a: b: a < b) (builtins.attrNames (lib.filterAttrs (_name: builtins.isFunction) library))
            );
        librarySections =
          if libraryPublicSections != [ ] && libraryInternalSections != [ ] then
            [
              (mkSection {
                sections = libraryPublicSections;
                title = "Public";
              })
              (mkSection {
                sections = libraryInternalSections;
                title = "Internal";
              })
            ]
          else
            libraryPublicSections ++ libraryInternalSections;
        moduleDoc =
          moduleName:
          let
            info = contributed modules moduleName;
          in
          {
            doc = writeDocumentation {
              inherit pkgs;
              description = if info.description != "" then info.description else summary info;
              name = moduleName;
              sections = [
                (section {
                  language = "nix";
                  title = "Usage";
                  type = "NixOS module";
                  usage = "imports = [ inputs.<flake>.nixosModules.${moduleName} ];";
                })
                (section {
                  bodyFile = optionsDoc pkgs info.options;
                  sections = [
                    (section {
                      description = "Declare values under the namespaces above; the interface asserts their referential integrity.";
                      language = "nix";
                      title = "example";
                      usage = "{ }";
                    })
                  ];
                  title = "Options";
                  usage = "";
                })
              ];
            };
            relative = moduleReadmePath root moduleName;
          };
        moduleIndex =
          moduleName:
          let
            info = contributed modules moduleName;
          in
          section {
            description = if info.description != "" then info.description else summary info;
            language = "nix";
            title = "[${moduleName}](${moduleReadmePath root moduleName})";
            type = "NixOS module";
            usage = "imports = [ inputs.<flake>.nixosModules.${moduleName} ];";
          };
        moduleNames = lib.sort (a: b: a < b) (builtins.attrNames modules);
        sections =
          groupSummaryOf "Apps"
          ++ groupSummaryOf "Systems"
          ++ lib.optional (moduleNames != [ ]) (mkSection {
            sections = map moduleIndex moduleNames;
            title = "Modules";
          })
          ++ groupSummaryOf "Templates"
          ++ groupSummaryOf "Packages"
          ++ groupSummaryOf "Library"
          ++ groupSummaryOf "Checks";
        slug = text: lib.replaceStrings [ " " ] [ "-" ] (lib.toLower text);
        summary = info: lib.concatStringsSep ", " (map (group: "${group}.*") info.names);
      in
      {
        inherit sections;
        inherit files;
        modules = map moduleDoc moduleNames;
        problems = documentationProblems {
          inherit description;
          sections = sections ++ lib.concatMap (group: group.entries) groupDocuments;
        };
        root = writeDocumentation {
          inherit description pkgs;
          inherit sections;
        };
      };
    # Reports every way a rendered document falls short of being usable: purpose unstated, usage missing, arguments untyped.
    #
    # # Arguments
    # - `description`: sentence stating what the flake is for
    # - `sections`: the rendered sections that are inspected
    documentationProblems =
      {
        description,
        sections,
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
          entry: entry.section.sections == [ ] && entry.section.usage == "" && entry.section.body == null
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
        map
          (
            argument:
            "${entry.path}: argument '${argument.argument}' has no documented type, so the reader cannot tell what to pass"
          )
          (
            lib.filter (
              argument: argument.argumentType == "" && !(entry.section.internal or false)
            ) entry.section.arguments
          )
      ) all
      ++
        map
          (
            entry:
            "${entry.path}: is a function with no documentation block above it, so nothing states what it is for or what it accepts"
          )
          (
            lib.filter (
              entry:
              entry.section.type == "function" && !entry.section.documented && !(entry.section.internal or false)
            ) all
          );
    # Derives the arguments that document a flake, from the flake itself, so a repository states nothing about its own
    # documentation.
    #
    # # Arguments
    # - `flake`: the flake whose outputs are documented
    # - `pkgs`: nixpkgs package set for the system being documented
    # - `root`: source tree the documentation describes, the store copy of the flake by default
    # - `checks`: checks to document, every check of the flake by default; pass an empty set from a check, which
    #   cannot enumerate the checks without forcing itself
    # - `description`: statement of what the flake is for, the multiline description in flake.nix by default
    # - `librarySource`: directory holding the library sources whose doc blocks are read, `<flake>/lib` by default
    flakeArgs =
      {
        pkgs,
        flake,
        checks ? null,
        description ? flakeDescription { inherit root; },
        librarySource ? flake.outPath + "/lib",
        root ? flake.outPath,
      }:
      let
        library' = flake.lib or { };
        system = pkgs.stdenv.hostPlatform.system;
        title = description;
      in
      {
        inherit pkgs root system;
        inherit librarySource;
        apps = flake.apps.${system} or { };
        checks = if checks == null then flake.checks.${system} or { } else checks;
        configurations = flake.nixosConfigurations or { };
        description = title;
        formatter = flake.formatter.${system} or null;
        internalLibrary = library'.internal or { };
        library = builtins.removeAttrs library' [ "internal" ];
        modules = flake.nixosModules or { };
        packages = flake.packages.${system} or { };
        templates = flake.templates or { };
        url = flake.url or "";
      };
    # Reads the description a flake states about itself, which is the only statement of what the flake is for.
    #
    # # Arguments
    # - `root`: source tree containing flake.nix
    flakeDescription =
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
    # Reports assertion messages that do not name a declared option, or that omit the expected value and the fix.
    #
    # # Arguments
    # - `assertions`: list of { assertion, message } records whose messages are inspected
    # - `options`: evaluated option set the message paths are resolved against
    messageProblems =
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
    # Builds an assertion record whose message states the violation, what was expected and how to fix it.
    #
    # # Arguments
    # - `at`: list of attribute names naming the option the assertion is about
    # - `condition`: the property being asserted, true when it holds
    # - `violation`: sentence saying what is wrong when the condition is false
    # - `expected`: sentence saying what the configuration should look like instead
    # - `fix`: sentence saying how to make it look that way
    mkAssertion =
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
    # Groups child sections under one title, for a part of the document that is itself not a usable thing.
    #
    # # Arguments
    # - `title`: heading text of the group
    # - `sections`: child sections, rendered one heading level deeper, empty when the group only holds prose
    # - `body`: markdown emitted under the title instead of child headings, null when there is none
    mkSection =
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
        tests = [ ];
        type = "";
        usage = "";
      };
    # Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set the hooks are taken from
    # - `src`: the tree the hooks are run against
    # - `extraHooks`: additional git-hooks definitions merged into the hook set
    preCommit =
      {
        pkgs,
        src,
        extraHooks ? { },
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
          exec ${lib.getExe inputs.self.packages.${system}.docs} --check
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
              packageOverrides.treefmt = inputs.self.formatter.${system};
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
    # Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md
    # disagree about a check.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set used to render and compare the documents
    # - `root`: path to the repository root holding the committed READMEs
    # - `system`: system string selecting the documented outputs
    # - `description`: sentence saying what this flake is for
    # - `apps`: attrset of apps to document, empty when the flake exports none
    # - `formatter`: the derivation exposed as the flake formatter for this system
    # - `checks`: attrset of checks to document, empty when the flake exports none
    # - `configurations`: attrset of NixOS configurations to document
    # - `library`: attrset of functions to document in the index
    # - `internalLibrary`: attrset of functions documented only in lib/README.md
    # - `modules`: attrset of NixOS modules to document
    # - `packages`: attrset of packages to document
    # - `templates`: attrset of templates to document
    # - `url`: flake reference the templates are published under, empty when the flake states none
    # - `librarySource`: directory holding the library sources whose doc blocks are read
    readmeGate =
      {
        pkgs,
        description,
        root,
        system,
        apps ? { },
        checks ? { },
        configurations ? { },
        formatter ? null,
        internalLibrary ? { },
        library ? { },
        librarySource ? root + "/lib",
        modules ? { },
        packages ? { },
        templates ? { },
        url ? "",
      }:
      let
        documentation' = documentation {
          inherit
            pkgs
            root
            system
            description
            apps
            checks
            configurations
            internalLibrary
            formatter
            library
            modules
            packages
            templates
            url
            librarySource
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
          ) (documentation'.modules ++ documentation'.files)}
          status=0
          strip_checks() {
            awk 'BEGIN { skip = 0 } /^## Checks$/ { skip = 1; next } skip == 1 && /^## / { skip = 0 } skip == 0 { print }' "$1"
          }
          while IFS= read -r -d "" found; do
            file="''${found#./}"
            case "$file" in
              modules/nixos/*/README.md)
                hint="nix run .#docs -- --module $(echo "$file" | sed -e 's|modules/nixos/||; s|/README.md$||')"
                ;;
              modules/nixos/*.README.md)
                hint="nix run .#docs -- --module $(echo "$file" | sed -e 's|modules/nixos/||; s|\.README\.md$||')"
                ;;
              *)
                hint="nix run .#docs"
                ;;
            esac
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
    # Renders a list of sections into a README derivation.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set the derivation is built with
    # - `name`: document title
    # - `description`: sentence under the title saying what the documented thing is for
    # - `sections`: sections to render, each with its own heading
    # Renders one section of a document as the shell commands that append its markdown, one heading level per depth.
    #
    # # Arguments
    # - `depth`: heading level of the section, 2 for a top-level section of a document
    # - `s`: the section to render
    renderSection =
      { depth, s }:
      let
        esc = lib.escapeShellArg;
        head = "${lib.concatStringsSep "" (lib.genList (_: "#") depth)} ${s.title}";
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
        "printf -- '- `%s`: %s\n' ${esc argument.argument} ${
          esc (if argument.argumentType != "" then argument.argumentType else "undocumented type")
        } >> $out/README.md"
      ]) s.arguments
      ++ lib.optionals (s.arguments != [ ]) [ "printf '\n' >> $out/README.md" ]
      ++ lib.optionals (s.description != "") [
        "printf '%s\n\n' ${esc s.description} >> $out/README.md"
      ]
      ++ lib.optionals (s.body != null) [
        "printf '%s\n\n' ${esc s.body} >> $out/README.md"
      ]
      ++ lib.optionals (s.bodyFile != null) [
        "sed -e 's/^## /### /' ${s.bodyFile} >> $out/README.md"
        "printf '\n' >> $out/README.md"
      ]
      ++ lib.concatMap (
        s:
        renderSection {
          inherit s;
          depth = depth + 1;
        }
      ) s.sections;
    # One documented thing: what it is, how to call or import it, what its arguments are and any child sections.
    #
    # # Arguments
    # - `title`: heading text naming the thing
    # - `usage`: snippet that uses the thing, shown in a fenced block
    # - `description`: sentence saying what the thing is for, empty when the title says it
    # - `language`: code fence language of the usage snippet, for example nix or sh
    # - `type`: what the thing is, for example derivation, app or NixOS module
    # - `arguments`: list of { argument, argumentType } describing the call shape
    # - `documented`: whether authored prose exists for the thing, false when it is undocumented
    # - `body`: markdown emitted under the title, null when there is none
    # - `bodyFile`: path to a rendered markdown fragment appended after the description
    # - `sections`: child sections, rendered one heading level deeper
    # - `tests`: list of { test, documented } naming the checks the thing is tested by
    section =
      {
        title,
        usage,
        arguments ? [ ],
        body ? null,
        bodyFile ? null,
        description ? "",
        documented ? true,
        internal ? false,
        language ? "",
        sections ? [ ],
        tests ? [ ],
        type ? "",
      }:
      {
        inherit
          title
          usage
          description
          documented
          internal
          language
          arguments
          type
          body
          bodyFile
          sections
          tests
          ;
      };
    # Renders the test links of a section: a markdown link when the check is documented, plain text when it is not.
    #
    # # Arguments
    # - `tests`: list of { test, documented } records naming the checks a package is tested by
    testsLine = renderTestLinks;
    # Writes one document: a heading, the statement of purpose, and the sections rendered in order.
    #
    # # Arguments
    # - `pkgs`: nixpkgs package set the document derivation is built with
    # - `name`: title of the document, the first line of the description when it is empty
    # - `description`: statement of what the flake is for, printed under the title; when name is empty its first
    #   line titles the document and the rest of it is printed under that title
    # - `sections`: sections to render, in order
    writeDocumentation =
      {
        pkgs,
        description,
        sections,
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
              renderSection {
                inherit s;
                depth = 2;
              }
            ) sections
          )}
        '';
        meta.description = "Rendered documentation: the repository README plus one README per module.";
        name = "documentation-${name}";
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
  functionSignature =
    fn:
    let
      probed = builtins.tryEval (builtins.functionArgs fn);
    in
    if !probed.success || probed.value == { } then
      ""
    else
      "{ "
      + lib.concatStringsSep ", " (
        lib.mapAttrsToList (
          argument: defaulted: if defaulted then "${argument} ? …" else argument
        ) probed.value
      )
      + " }";
  harness = {
    config.networking.domain = "test";
    options = {
      assertions = lib.mkOption {
        default = [ ];
        internal = true;
        type = lib.types.listOf lib.types.unspecified;
      };
      networking.domain = lib.mkOption {
        description = "Domain the documentation harness uses to derive host names.";
        type = lib.types.str;
      };
      warnings = lib.mkOption {
        default = [ ];
        internal = true;
        type = lib.types.listOf lib.types.unspecified;
      };
    };
  };
  lib = inputs.nixpkgs.lib;
  moduleReadmePath =
    root: moduleName:
    if builtins.pathExists (root + "/modules/nixos/${moduleName}") then
      "modules/nixos/${moduleName}/README.md"
    else
      "modules/nixos/${moduleName}.README.md";
  optionsDoc =
    pkgs: options:
    (pkgs.nixosOptionsDoc {
      inherit options;
      transformOptions = option: option // { declarations = [ ]; };
    }).optionsCommonMark;
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
  trimLeft = line: if lib.hasPrefix " " line then trimLeft (lib.removePrefix " " line) else line;
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
# The surface a consuming repository calls: the documentation arguments, the readme gate, the pre-commit hook set and
# the development shell. Everything else is internal.
(lib.getAttrs [
  "devShell"
  "docsGate"
  "flakeArgs"
  "preCommit"
  "readmeGate"
] everything)
// {
  internal = builtins.removeAttrs everything [
    "devShell"
    "docsGate"
    "flakeArgs"
    "preCommit"
    "readmeGate"
  ];
}
