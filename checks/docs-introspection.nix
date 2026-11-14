{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  appPackage = inputs.self.lib.internal.documentApp {
    app = {
      meta.description = "probe";
      program = "/nix/store/x/bin/probe";
      type = "app";
    };
    name = "probe";
  };
  args = inputs.self.lib.internal.flakeArgs {
    inherit pkgs;
    checks = { };
    flake = inputs.self;
    root = inputs.self.outPath;
  };
  argsWithPublicLibrary = args // {
    library.probeFn = { value }: value;
  };
  assertionList = [
    {
      assertion = documentation.problems == [ ];
      message = "every documented thing states how to use it and the flake description states what the flake is for (problems: ${lib.concatStringsSep " | " documentation.problems})";
    }
    {
      assertion = !failingAssertion.success;
      message = "an assertion that does not hold fails evaluation instead of reporting problems";
    }
    {
      assertion =
        lib.any (lib.hasInfix "too short to say what this flake is for")
          (inputs.self.lib.internal.documentation (args // { description = "too short"; })).problems;
      message = "a flake description too short to state what the flake is for is reported";
    }
    {
      assertion = lib.any (lib.hasInfix "the flake description is empty") broken.problems;
      message = "a flake whose description is empty is reported, because the description is the only statement of purpose";
    }
    {
      assertion = lib.any (lib.hasInfix "usage line carries no argument shape") broken.problems;
      message = "a function whose arguments cannot be inferred is reported instead of being documented as uncallable";
    }
    {
      assertion = lib.any (lib.hasInfix "usage line carries no language label") (
        inputs.self.lib.internal.documentationProblems {
          description = "A fixture description long enough to satisfy the purpose rule.";
          sections = [
            (inputs.self.lib.internal.section {
              title = "unlabelled";
              type = "derivation";
              usage = "nix build .#thing";
            })
          ];
        }
      );
      message = "a snippet whose language is not stated is reported, because a fenced block without a language renders without highlighting";
    }
    {
      assertion = lib.any (lib.hasInfix "names no type, so what the thing is cannot be stated") (
        inputs.self.lib.internal.documentationProblems {
          description = "A fixture description long enough to satisfy the purpose rule.";
          sections = [
            (inputs.self.lib.internal.section {
              language = "sh";
              title = "untyped";
              usage = "nix build .#thing";
            })
          ];
        }
      );
      message = "a thing documented without a type is reported, because the reader cannot tell what it is";
    }
    {
      assertion =
        inputs.self.lib.internal.testsLine { inherit (testedPackage) tests; }
        == "[assertions](#assertions), undocumented";
      message = "a passthru.tests entry naming a documented check becomes a link to that check, and one naming nothing documented stays plain text";
    }
    {
      assertion =
        map (test: test.documented) testedPackage.tests == [
          true
          false
        ];
      message = "each passthru.tests entry records whether the check it names is documented";
    }
    {
      assertion = lib.any (file: file.relative == "lib/README.md") documentation.files;
      message = "the library is documented in lib/README.md, next to the code it describes";
    }
    {
      assertion =
        map (section: section.title)
          (lib.findFirst (file: file.relative == "lib/README.md") null splitDocumentation.files).sections == [
          "Public"
          "Internal"
        ];
      message = "a library with public and internal functions states which is which, in one document, under Public and Internal headings";
    }
    {
      assertion = builtins.attrNames inputs.self.lib == [ "internal" ];
      message = "the whole library is internal, because a consuming repository calls the base flake directly and the callable mixin supplies the documentation arguments, the gates, the pre-commit hook set and the development shell";
    }
    {
      assertion = builtins.attrNames inputs.self.lib.internal != [ ];
      message = "the functions that are not part of the consuming surface are grouped under lib.internal";
    }
    {
      assertion =
        bulletLines documentation "Packages" != [ ]
        && lib.all (line: lib.hasInfix ") — " line) (bulletLines documentation "Packages");
      message = "each package in the index states its description after the link";
    }
    {
      assertion =
        bulletLines documentedChecks "Checks"
        == [ "- [probe](checks/README.md#probe) — Program that produces a familiar, friendly greeting" ];
      message = "checks are listed in the index with the description they state, like every other documented thing";
    }
    {
      assertion =
        let
          lines = bulletLines documentation "Packages";
        in
        lines == lib.sort (a: b: a < b) lines;
      message = "the entries of a section are listed in alphabetical order";
    }
    {
      assertion = runnablePackage.usage == "nix run .#runnable";
      message = "a package with a mainProgram is documented as runnable, not as something to build";
    }
    {
      assertion = buildOnlyPackage.usage == "nix build .#buildable";
      message = "a package without a mainProgram is documented as something to build";
    }
    {
      assertion = formatterPackage.usage == "nix fmt";
      message = "the derivation the flake exposes as its formatter is documented as nix fmt";
    }
    {
      assertion = appPackage.usage == "nix run .#probe";
      message = "an app is documented as something to run, without the system in the example";
    }
    {
      assertion =
        configurationPackage.usage == "nix build .#nixosConfigurations.host.config.system.build.toplevel";
      message = "a NixOS configuration is documented with the attribute path that builds it";
    }
    {
      assertion = functionPackage.usage == "lib.internal.mkSection { body ? …, sections ? …, title }";
      message = "a function is documented under the namespace it is actually reachable from, with its argument shape";
    }
    {
      assertion =
        indexOf "Library" (inputs.self.lib.internal.documentation (args // { library = { }; })).sections
        == null;
      message = "a library that is entirely internal is documented in lib/README.md and adds no Library section to the index";
    }
    {
      assertion =
        let
          section = indexOf "Library" (inputs.self.lib.internal.documentation argsWithPublicLibrary).sections;
        in
        section != null
        && lib.hasInfix "probeFn" section.body
        && !(lib.hasInfix "descriptionsProblems" section.body);
      message = "a library with public and internal functions lists the public ones in the index and none of the internal ones";
    }
    {
      assertion = args.checks == { } && args.internalLibrary == inputs.self.lib.internal;
      message = "the documentation arguments are derived from the flake: its internal library, and the checks the caller chose to document";
    }
    {
      assertion =
        args.modules == inputs.self.nixosModules
        && args.packages == inputs.self.packages.${pkgs.stdenv.hostPlatform.system}
        && args.formatter == inputs.self.formatter.${pkgs.stdenv.hostPlatform.system}
        && builtins.attrNames args.library == [ ];
      message = "the documentation arguments are derived from the flake: its modules, packages, formatter and an internal-only library";
    }
    {
      assertion =
        let
          expected = map (name: "nix flake init -t ${inputs.self.url}#${name}") (
            builtins.attrNames inputs.self.templates
          );
          file = lib.findFirst (each: each.relative == "templates/README.md") null documentation.files;
          usages = map (section: section.usage) (if file == null then [ ] else file.sections);
        in
        usages == expected && expected != [ ];
      message = "each template is documented with the public command that instantiates it, nix flake init -t <flake url>#<name>";
    }
    {
      assertion =
        let
          body = if section == null then "" else section.body;
          section = indexOf "Packages" documentation.sections;
        in
        !(lib.hasInfix "docs-integration" body);
      message = "a package marked meta.internal is not documented, so a check that only runs outside the sandbox stays out of the README";
    }
    {
      assertion =
        let
          probe = inputs.self.lib.internal.documentation (
            args
            // {
              packages = args.packages // {
                hidden = pkgs.hello.overrideAttrs (_: {
                  meta.internal = true;
                });
              };
            }
          );
          section = indexOf "Packages" probe.sections;
        in
        !(lib.hasInfix "hidden" (if section == null then "" else section.body));
      message = "the internal marking is what hides a package, not its name";
    }
    {
      assertion =
        let
          present = map (section: section.title) documentation.sections;
        in
        present == lib.filter (title: lib.elem title present) canonicalOrder;
      message = "the index lists its sections in the canonical order, whatever subset of them the flake has: ${
        lib.concatStringsSep ", " (map (section: section.title) documentation.sections)
      }";
    }
    {
      assertion =
        renderedNested == [
          "printf '%s\n\n' '### probe' >> $out/README.md"
          "printf '```%s\n%s\n```\n\n' sh 'nix run .#probe' >> $out/README.md"
          "printf '*Type:* %s\n\n' template >> $out/README.md"
        ];
      message = "a section nested in another renders one heading level deeper, with the language on the fence and its type stated";
    }
    {
      assertion =
        let
          body = if section == null then "" else section.body;
          section = indexOf "Checks" withReexports.sections;
        in
        lib.hasInfix "genuine" body
        && !(lib.hasInfix "devshell-probe" body)
        && !(lib.hasInfix "pkgs-probe" body)
        && !(lib.hasInfix "shared" body);
      message = "checks that merely re-export a devshell or a package, or that share a name with a package, are not documented a second time";
    }
    {
      assertion =
        (inputs.self.lib.internal.documentTemplate {
          name = "probe";
          template.description = "probe template";
        }).usage == "nix flake init -t .#probe";
      message = "a flake that states no url documents its templates with the relative reference, nix flake init -t .#<name>";
    }
    {
      assertion = internalCalls == [ ];
      message = "the template only calls the public library, so a function it needs cannot stay internal: ${lib.concatStringsSep ", " (map toString internalCalls)}";
    }
    {
      assertion =
        importedFunction.documented
        && importedFunction.description == "Summarises the second function, defined in another file."
        &&
          (lib.head importedFunction.arguments).argumentType
          == "the value the function returns, and the doc block bullet wraps onto a second line that the parser joins";
      message = "a function documented in a file other than the library entry point is found, with its summary and argument types";
    }
    {
      assertion =
        rfc145Function.documented
        && rfc145Function.description == "Adds two numbers together."
        &&
          (lib.map (arg: arg.argumentType) rfc145Function.arguments) == [
            "Number"
            "Number"
          ];
      message = "an RFC-145 /** doc comment with a definition-list and a # Type signature is read, its argument types filled positionally from the signature";
    }
    {
      assertion = internalFunction.documented && internalProblems == [ ];
      message = "an internal function may leave its arguments undocumented without being reported, while its doc block is still used";
    }
    {
      assertion =
        !legacyFunction.documented
        && lib.elem "legacy: is documented with a `#` line-comment block directly above it, which is not read; the only doc-comment format is the RFC-145 `/** */` block" legacyProblems
        && lib.elem "legacy: is a function with no documentation block above it, so nothing states what it is for or what it accepts" legacyProblems;
      message = "a function documented with the former `#` line-comment format is no longer documented, and the documentation check reports it: the parser reads only RFC-145 `/** */` blocks";
    }
    {
      assertion =
        inputs.self.lib.internal.flakeDescription { root = ../.; } == ''
          SYNACKDOCHE GAMES - Base Flake

          shared formatter, pre-commit, docgate checks and flake scaffolding
        '';
      message = "the purpose shown in every document is read from the description the flake states about itself";
    }
  ];
  broken = inputs.self.lib.internal.documentation (
    args
    // {
      description = "";
      library = args.library // {
        positional = value: value;
      };
    }
  );
  buildOnlyPackage = inputs.self.lib.internal.documentPackage {
    name = "buildable";
    package = pkgs.hello.overrideAttrs (old: {
      meta = builtins.removeAttrs (old.meta or { }) [ "mainProgram" ];
    });

  };
  bulletLines =
    document: groupTitle:
    let
      group = lib.findFirst (each: each.title == groupTitle) null document.sections;
    in
    if group == null || group.body == null then
      [ ]
    else
      lib.filter (line: lib.hasPrefix "- [" line) (lib.splitString "\n" group.body);
  canonicalOrder = [
    "Apps"
    "Systems"
    "Modules"
    "Templates"
    "Packages"
    "Library"
    "Checks"
  ];
  configurationPackage = inputs.self.lib.internal.documentConfiguration {
    configuration = {
      config.networking.hostName = "host";
      pkgs.stdenv.hostPlatform.system = "x86_64-linux";
    };
    name = "host";
  };
  documentation = inputs.self.lib.internal.documentation args;
  documentedChecks = inputs.self.lib.internal.documentation (
    args
    // {
      checks.probe = pkgs.hello;
    }
  );
  evaluated = lib.evalModules {
    modules = [
      {
        options.assertions = lib.mkOption {
          apply =
            assertions:
            let
              failed = lib.filter (each: !each.assertion) assertions;
            in
            if failed == [ ] then
              assertions
            else
              throw "Failed assertions:\n${lib.concatMapStrings (each: "- ${each.message}\n") failed}";
          default = [ ];
          description = "Assertions this check makes; evaluation fails when one does not hold.";
          type = lib.types.listOf lib.types.unspecified;
        };
      }
      { assertions = assertionList; }
    ];
  };
  failingAssertion =
    builtins.tryEval
      (lib.evalModules {
        modules = [
          {
            options.assertions = lib.mkOption {
              apply =
                assertions:
                let
                  failed = lib.filter (each: !each.assertion) assertions;
                in
                if failed == [ ] then
                  assertions
                else
                  throw "Failed assertions:\n${lib.concatMapStrings (each: "- ${each.message}\n") failed}";
              default = [ ];
              type = lib.types.listOf lib.types.unspecified;
            };
          }
          {
            assertions = [
              {
                assertion = false;
                message = "toy.good: violates the rule";
              }
            ];
          }
        ];
      }).config.assertions;
  formatterPackage = inputs.self.lib.internal.documentPackage {
    formatter = pkgs.hello;
    name = "formatter";
    package = pkgs.hello;
  };
  functionPackage = inputs.self.lib.internal.documentFunction {
    fn = inputs.self.lib.internal.mkSection;
    name = "mkSection";
    namespace = "lib.internal";
  };
  importedFunction = inputs.self.lib.internal.documentFunction {
    fn = { value }: value;
    name = "second";
    source = libraryFixture + "/lib";
  };
  indexOf = title: lib.findFirst (section: section.title == title) null;
  internalCalls = lib.filter (
    file: lib.hasInfix "lib.internal" (builtins.readFile file)
  ) templateSources;
  internalFunction = inputs.self.lib.internal.documentFunction {
    fn = { value }: value;
    internal = true;
    name = "third";
    source = libraryFixture + "/lib";
  };
  internalProblems = inputs.self.lib.internal.documentationProblems {
    description = "A flake that exists to check the documentation rules themselves.";
    sections = [ internalFunction ];
  };
  legacyFunction = inputs.self.lib.internal.documentFunction {
    fn = { value }: value;
    name = "legacy";
    source = libraryFixture + "/lib";
  };
  legacyProblems = inputs.self.lib.internal.documentationProblems {
    description = "A flake that exists to check the documentation rules themselves.";
    sections = [ legacyFunction ];
  };
  libraryFixture = pkgs.runCommand "library-fixture" { } ''
    mkdir -p $out/lib
    printf '%s\n' '{ }' > $out/lib/first.nix
    cat > $out/lib/second.nix <<'EOF'
    {
      /**
        Summarises the second function, defined in another file.

        # Arguments

        - `value`: the value the function returns, and the doc block bullet
          wraps onto a second line that the parser joins
      */
      second = { value }: value;

      /**
        Summarises the internal function, whose arguments are not documented.
      */
      third = { value }: value;

      # Summarises the legacy function, using the former line-comment format.
      # The parser reads only RFC-145 block comments, so this block is a comment.
      legacy = { value }: value;

      /**
        Adds two numbers together.

        # Type

        add :: Number -> Number -> Number

        # Arguments

        a
        : The first number

        b
        : The second number
      */
      add = a: b: a + b;
    }
    EOF
  '';
  renderedNested = inputs.self.lib.internal.renderSection {
    depth = 3;
    s = inputs.self.lib.internal.section {
      language = "sh";
      title = "probe";
      type = "template";
      usage = "nix run .#probe";
    };
  };
  rfc145Function = inputs.self.lib.internal.documentFunction {
    fn = { a, b }: a + b;
    name = "add";
    source = libraryFixture + "/lib";
  };
  runnablePackage = inputs.self.lib.internal.documentPackage {
    name = "runnable";
    package = pkgs.writeShellScriptBin "runnable" "true" // {
      meta.mainProgram = "runnable";
    };

  };
  splitDocumentation = inputs.self.lib.internal.documentation (
    args
    // {
      library.probe =
        {
          value,
        }:
        value;
    }
  );
  templateSources = lib.filesystem.listFilesRecursive ../templates;
  testedPackage = inputs.self.lib.internal.documentPackage {
    checks = [ "assertions" ];
    name = "probe";
    package = pkgs.hello.overrideAttrs (old: {
      passthru = (old.passthru or { }) // {
        tests = {
          assertions = pkgs.hello;
          undocumented = pkgs.hello;
        };
      };
    });

  };
  withReexports = inputs.self.lib.internal.documentation (
    args
    // {
      checks = args.checks // {
        devshell-probe = pkgs.hello;
        genuine = pkgs.emptyFile;
        pkgs-probe = pkgs.hello;
        shared = pkgs.emptyFile;
      };
      packages = args.packages // {
        shared = pkgs.emptyFile;
      };
    }
  );
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that the generated documentation is complete and usable, and that incomplete documentation is reported.";
  name = "docgate-introspection";
}
