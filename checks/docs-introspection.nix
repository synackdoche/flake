{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  appPackage = inputs.self.lib.internal.document.app {
    app = {
      meta.description = "probe";
      program = "/nix/store/x/bin/probe";
      type = "app";
    };
    name = "probe";
  };
  args = inputs.self.lib.internal.flake.args {
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
      assertion =
        let
          section = exampleSection "withExample";
        in
        section != null
        && lib.hasInfix "enabled = true" section.usage
        && section.description == "A configuration that satisfies the interface above.";
      message = "a module that sets meta.example renders it under its Options section";
    }
    {
      assertion = exampleSection "withoutExample" == null;
      message = "a module that sets no meta.example renders no example section";
    }
    {
      assertion = map (section: section.title) (moduleEntry "systemdUnit").sections == [ "Options" ];
      message = "a module that defines a systemd unit from a NixOS option is documented with its own options instead of failing to evaluate";
    }
    {
      assertion =
        let
          entry = moduleEntry "withModuleArgs";
        in
        entry != null && lib.hasInfix "Builds an import from the flake and its inputs" entry.description;
      message = "a module that takes the flake and its inputs is documented instead of failing to evaluate";
    }
    {
      assertion = indexOf "Options" (moduleEntry "wiringOnly").sections == null;
      message = "a module that declares no options of its own documents no options, rather than the NixOS options it defines";
    }
    {
      assertion =
        valueSection.type == "Int"
        && valueSection.kind == "value"
        && lib.hasSuffix "values.nix" valueSection.source.path
        && valueSection.description == "The answer to everything.";
      message = "an exported value is documented with the type its doc block states and a link to the file it is defined in";
    }
    {
      assertion = lib.any (
        problem: lib.hasInfix "probeUntyped: names no type" problem
      ) libraryValues.problems;
      message = "a documented value that states no type is reported as naming no type";
    }
    {
      assertion = lib.any (
        problem: lib.hasInfix "probeBare: is an exported value that declares no meta.description" problem
      ) libraryValues.problems;
      message = "an exported value with no doc block is reported as undocumented";
    }
    {
      assertion =
        let
          file = lib.findFirst (
            candidate: indexOf "Public" (candidate.sections or [ ]) != null
          ) null libraryValues.files;
          namespace = indexOf "types" public.sections;
          nested = indexOf "nested" namespace.sections;
          public = indexOf "Public" file.sections;
        in
        nested.kind == "function" && lib.hasInfix "lib.types.nested" nested.usage;
      message = "an exported namespace is documented with its members nested under it, each under its qualified name";
    }
    {
      assertion =
        let
          file = lib.findFirst (
            candidate: indexOf "Public" (candidate.sections or [ ]) != null
          ) null libraryValues.files;
          public = indexOf "Public" file.sections;
          shape = indexOf "shape" public.sections;
        in
        shape != null && map (child: child.title) shape.sections == [ "Options" ];
      message = "an exported option type is documented with the shape of the options it defines";
    }
    {
      assertion =
        let
          file = lib.findFirst (
            candidate: indexOf "Public" (candidate.sections or [ ]) != null
          ) null libraryValues.files;
          options = indexOf "Options" shape.sections;
          public = indexOf "Public" file.sections;
          shape = indexOf "shape" public.sections;
        in
        options != null && options.bodyFile != null && options.usage == "";
      message = "the option type's shape is rendered from the base's own options renderer";
    }
    {
      assertion =
        let
          entry = indexOf "probe" file.sections;
          file = lib.findFirst (
            candidate: indexOf "probe" (candidate.sections or [ ]) != null
          ) null (exampleDocs "withExample").files;
        in
        entry.description == "Enables the example subsystem.";
      message = "a module that sets meta.description is documented with that description";
    }
    {
      assertion =
        let
          mentions = needle: lib.any (lib.hasInfix needle) problems.problems;
          problems = exampleDocs "badExample";
        in
        mentions "bogus.deep" && mentions "example.enabled";
      message = "an example that sets an undeclared option or a mistyped value is reported as a documentation problem (problems: ${lib.concatStringsSep " | " (exampleDocs "badExample").problems})";
    }
    {
      assertion = (exampleDocs "packageExample").problems == [ ];
      message = "a module whose example sets a package option is documented without recursing into the derivation";
    }
    {
      assertion =
        let
          built = inputs.self.lib.internal.buildDocumented.function {
            name = "probePositional";
            value = decl;
          };
          decl = {
            __functor = _self: args: args;
            meta = {
              args = [
                {
                  description = "an integer";
                  type = lib.types.int;
                }
              ];
              description = "Probe positional function.";
            };
          };
          errorText = builtins.tryEval (built "wrong");
        in
        !errorText.success;
      message = "a positional argument rejected by its declared type fails with a type error, not a missing attribute name";
    }
    {
      assertion =
        let
          built = inputs.self.lib.internal.buildDocumented.function {
            name = "probeDefault";
            value = decl;
          };
          decl = {
            __functor = _self: args: args;
            meta = {
              args = {
                optional = {
                  default = 7;
                  description = "an integer with a default";
                  type = lib.types.int;
                };
                required = {
                  description = "a string";
                  type = lib.types.str;
                };
              };
              description = "Probe named function.";
            };
          };
        in
        (built { required = "x"; }).optional == 7
        &&
          (built {
            optional = 3;
            required = "x";
          }).optional == 3;
      message = "a named argument that declares a default uses it when omitted and accepts an explicit value";
    }
    {
      assertion =
        let
          built = inputs.self.lib.internal.documentation.build (
            args
            // {
              modules = {
                configuration = { lib, ... }: {
                  options.shared = lib.mkOption {
                    default = "from-configuration";
                    description = "Shared value declared in configuration.";
                    type = lib.types.str;
                  };
                };
                impl =
                  { lib, config, ... }:
                  {
                    config = lib.mkIf config.impl.enable {
                      environment.variables.FROM_SHARED = config.shared;
                    };
                    meta.description = "The implementation module.";
                    options.impl = lib.mkOption {
                      default = false;
                      description = "Implementation option declared outside configuration.";
                      type = lib.types.bool;
                    };
                  };
              };
            }
          );
        in
        built.problems == [ ];
      message = "a module whose option reads a sibling module's value is documented at a scope that includes that sibling";
    }
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
          (inputs.self.lib.internal.documentation.build (args // { description = "too short"; })).problems;
      message = "a flake description too short to state what the flake is for is reported";
    }
    {
      assertion = lib.any (lib.hasInfix "the flake description is empty") broken.problems;
      message = "a flake whose description is empty is reported, because the description is the only statement of purpose";
    }
    {
      assertion = lib.any (lib.hasInfix "positional: is a function that declares no meta.description") broken.problems;
      message = "a function whose arguments and purpose cannot be read is reported instead of being documented as uncallable";
    }
    {
      assertion = lib.any (lib.hasInfix "usage line carries no language label") (
        inputs.self.lib.internal.documentation.problems {
          description = "A fixture description long enough to satisfy the purpose rule.";
          sections = [
            (inputs.self.lib.internal.section.make {
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
        inputs.self.lib.internal.documentation.problems {
          description = "A fixture description long enough to satisfy the purpose rule.";
          sections = [
            (inputs.self.lib.internal.section.make {
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
        inputs.self.lib.internal.section.tests { inherit (testedPackage) tests; }
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
      assertion = functionPackage.usage == "lib.internal.section.group { body, sections, title }";
      message = "a function is documented under the namespace it is actually reachable from, with its argument shape";
    }
    {
      assertion =
        indexOf "Library"
          (inputs.self.lib.internal.documentation.build (args // { library = { }; })).sections == null;
      message = "a library that is entirely internal is documented in lib/README.md and adds no Library section to the index";
    }
    {
      assertion =
        let
          section = indexOf "Library" (inputs.self.lib.internal.documentation.build argsWithPublicLibrary)
          .sections;
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
          probe = inputs.self.lib.internal.documentation.build (
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
        let
          section = indexOf "Usage" documentation.sections;
        in
        section != null
        && section.type == "function"
        && section.language == "nix"
        && lib.hasPrefix "inputs.<flake> {" section.usage
        && lib.all (argument: lib.hasInfix argument.argument section.usage) section.arguments
        && map (argument: argument.argument) section.arguments == builtins.attrNames inputs.self.meta.args
        && lib.all (
          argument: argument.argumentType != "" && argument.argumentDescription != ""
        ) section.arguments;
      message = "the flake's own call shape is documented as a Usage section, with every argument its functor declares, each stating a type and what it means";
    }
    {
      assertion =
        let
          section =
            indexOf "Usage"
              (inputs.self.lib.internal.documentation.build (args // { flake = null; })).sections;
        in
        section == null;
      message = "a flake whose functor declares no meta.args gets no Usage section, so stray metadata cannot invent a call shape";
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
        (inputs.self.lib.internal.document.template {
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
        && (lib.head importedFunction.arguments).argumentType == "anything"
        && (lib.head importedFunction.arguments).argumentDescription == "the value the function returns";
      message = "a documented declaration is read from the meta it carries: its description, and each argument's type and description";
    }
    {
      assertion =
        rfc145Function.documented
        && rfc145Function.description == "Adds two numbers together."
        &&
          (lib.map (arg: arg.argumentType) rfc145Function.arguments) == [
            "signed integer"
            "signed integer"
          ]
        &&
          (lib.map (arg: arg.argumentDescription) rfc145Function.arguments) == [
            "left addend"
            "right addend"
          ];
      message = "each argument states the option type it accepts and what it means, so the reader is told how to check a call and what to pass";
    }
    {
      assertion =
        shadowedFunction.documented
        &&
          shadowedFunction.description
          == "Summarises the shadowed function, whose name also appears as a nested binding above it.";
      message = "an export whose name also appears as a nested binding elsewhere in the file is documented from its own meta, with no lookup to confuse the two";
    }
    {
      assertion =
        internalFunction.documented
        && lib.any (
          problem: lib.hasInfix "argument 'value' has no documented type" problem
        ) internalProblems;
      message = "an internal function's undocumented argument is reported too, because the internal surface is published and read like any other";
    }
    {
      assertion =
        !legacyFunction.documented
        && lib.elem "undocumented: is a function that declares no meta.description, so nothing states what it is for or what it accepts" legacyProblems;
      message = "a callable export that declares no meta.description is reported, so prose in a comment cannot stand in for documentation";
    }
    {
      assertion =
        let
          entry =
            let
              public =
                indexOf "Public"
                  (lib.findFirst (
                    candidate: indexOf "Public" (candidate.sections or [ ]) != null
                  ) null libraryFunctions.files).sections;
            in
            indexOf "readOptions" public.sections;
          options = indexOf "Options" (indexOf "opts" entry.sections).sections;
        in
        entry != null
        && lib.any (
          argument: argument.argument == "opts" && argument.argumentType == "submodule"
        ) entry.arguments
        && options != null
        && options.bodyFile != null;
      message = "an argument whose type is a submodule is documented with the shape of the options it accepts";
    }
    {
      assertion =
        (inputs.self.lib.internal.buildDocumented.function {
          name = "readOptions";
          value = functionFixture.readOptions;
        })
          {
            opts.enabled = false;
          } == false;
      message = "a documented declaration whose argument is a submodule accepts an option set that satisfies it";
    }
    {
      assertion =
        !(builtins.tryEval (
          (inputs.self.lib.internal.buildDocumented.function {
            name = "readOptions";
            value = functionFixture.readOptions;
          })
            {
              opts.enabled = "yes";
            }
        )).success;
      message = "a documented declaration whose argument is a submodule rejects a mistyped option, so the argument is validated as an option set and not only as an attribute set";
    }
    {
      assertion =
        let
          inherit
            (
              (inputs.self.lib.internal.documentation.build (
                args
                // {
                  internalLibrary.plain = x: x;
                  requireInternalDocumentation = false;
                }
              ))
            )
            problems
            ;
        in
        !(lib.any (lib.hasInfix "plain") problems);
      message = "an internal export that declares no meta.description is not reported, because the internal surface may stay opaque";
    }
    {
      assertion =
        let
          inherit
            (
              (inputs.self.lib.internal.documentation.build (
                args
                // {
                  internalLibrary.plain = x: x;
                  requireInternalDocumentation = true;
                }
              ))
            )
            problems
            ;
        in
        lib.any (lib.hasInfix "plain: is a function that declares no meta.description") problems;
      message = "a flake that requires internal documentation has an undocumented internal export reported, so the exemption is configurable";
    }
    {
      assertion =
        let
          built = inputs.self.lib.internal.buildDocumented.functions {
            data = {
              a = 1;
              b.c = 2;
            };
          };
        in
        built.data == {
          a = 1;
          b.c = 2;
        };
      message = "an export that holds no declaration is published untouched, so a table of plain data keeps its shape";
    }
    {
      assertion =
        let
          built = inputs.self.lib.internal.buildDocumented.functions cyclic;
          cyclic = rec {
            aSelf = cyclic;
            zFn = {
              __functor = _self: _: 9;
              meta.description = "Returns nine.";
            };
          };
        in
        builtins.isFunction built.zFn && builtins.isAttrs built.aSelf;
      message = "a self-referential export does not overflow the walk: the depth bound stops it and the cycle is left as it was";
    }
    {
      assertion =
        inputs.self.lib.internal.flake.description { root = ../.; } == ''
          SYNACKDOCHE GAMES - Base Flake

          shared formatter, pre-commit, docgate checks and flake scaffolding
        '';
      message = "the purpose shown in every document is read from the description the flake states about itself";
    }
  ];
  broken = inputs.self.lib.internal.documentation.build (
    args
    // {
      description = "";
      library = args.library // {
        positional = value: value;
      };
    }
  );
  buildOnlyPackage = inputs.self.lib.internal.document.package {
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
    "Usage"
    "Templates"
    "Apps"
    "Systems"
    "Modules"
    "Packages"
    "Library"
    "Checks"
  ];
  configurationPackage = inputs.self.lib.internal.document.configuration {
    configuration = {
      config.networking.hostName = "host";
      pkgs.stdenv.hostPlatform.system = "x86_64-linux";
    };
    name = "host";
  };
  documentation = inputs.self.lib.internal.documentation.build args;
  documentedChecks = inputs.self.lib.internal.documentation.build (
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
  exampleDocs =
    name:
    inputs.self.lib.internal.documentation.build (
      args
      // {
        modules.probe = exampleModules.${name};
      }
    );
  exampleModules = {
    badExample =
      { lib, ... }:
      {
        meta = {
          description = "Enables the example subsystem.";
          example = {
            bogus.deep = true;
            example.enabled = "yes";
          };
        };
        options.example.enabled = lib.mkOption {
          default = false;
          type = lib.types.bool;
        };
      };
    packageExample =
      { lib, ... }:
      {
        meta = {
          description = "Sets a package-valued option in its worked example.";
          example.probe.pkg = pkgs.hello;
        };
        options.probe.pkg = lib.mkOption {
          default = null;
          description = "The package the example sets.";
          type = lib.types.nullOr lib.types.package;
        };
      };
    systemdUnit =
      { lib, config, ... }:
      {
        config = lib.mkIf config.probeUnit.enable {
          systemd.services.probe-unit = {
            serviceConfig.ExecStart = lib.escapeShellArgs (
              [ "probe" ] ++ map toString config.probeUnit.certificates
            );
            wantedBy = [ "multi-user.target" ];
          };
        };
        meta.description = "Runs a unit from the certificate list the NixOS module system provides.";
        options.probeUnit = {
          certificates = lib.mkOption {
            default = config.security.pki.certificateFiles;
            defaultText = lib.literalExpression "config.security.pki.certificateFiles";
            description = "Certificates the unit starts with, defaulted from the NixOS option that owns them.";
            type = lib.types.listOf lib.types.path;
          };
          enable = lib.mkEnableOption "the probe unit";
        };
      };
    wiringOnly = _: {
      config.systemd.services.probe-wiring.serviceConfig.ExecStart = "probe";
      meta.description = "Defines a NixOS unit without declaring an option of its own.";
    };
    withExample =
      { lib, ... }:
      {
        meta = {
          description = "Enables the example subsystem.";
          example.example.enabled = true;
        };
        options.example.enabled = lib.mkOption {
          default = false;
          type = lib.types.bool;
        };
      };
    withModuleArgs =
      {
        lib,
        flake,
        inputs,
        ...
      }:
      {
        imports = lib.optional (flake ? outPath) {
          options.probe-flake.inputCount = inputs.nixpkgs.lib.mkOption {
            default = builtins.length (builtins.attrNames inputs);
            description = "Number of inputs the module received from the flake.";
            type = inputs.nixpkgs.lib.types.int;
          };
        };
        meta.description = "Builds an import from the flake and its inputs, which a blueprint system provides to every module.";
      };
    withoutExample =
      { lib, ... }:
      {
        meta.description = "Enables the example subsystem.";
        options.example.enabled = lib.mkOption {
          default = false;
          type = lib.types.bool;
        };
      };
  };
  exampleSection = name: indexOf "example" (moduleEntry name).sections;
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
  formatterPackage = inputs.self.lib.internal.document.package {
    formatter = pkgs.hello;
    name = "formatter";
    package = pkgs.hello;
  };
  functionFixture = import ../fixtures/library/functions.nix { inherit lib; };
  functionPackage = inputs.self.lib.internal.document.function {
    fn = inputs.self.lib.internal.section.group;
    name = "group";
    namespace = "lib.internal.section";
  };
  importedFunction = inputs.self.lib.internal.document.function {
    fn = functionFixture.second;
    name = "second";
    position = builtins.unsafeGetAttrPos "second" functionFixture;
  };
  indexOf = title: lib.findFirst (section: section.title == title) null;
  internalCalls = lib.filter (
    file: lib.hasInfix "lib.internal" (builtins.readFile file)
  ) templateSources;
  internalFunction = inputs.self.lib.internal.document.function {
    fn = functionFixture.third;
    internal = true;
    name = "third";
    position = builtins.unsafeGetAttrPos "third" functionFixture;
  };
  internalProblems = inputs.self.lib.internal.documentation.problems {
    description = "A flake that exists to check the documentation rules themselves.";
    sections = [ internalFunction ];
  };
  legacyFunction = inputs.self.lib.internal.document.function {
    fn = functionFixture.undocumented;
    name = "undocumented";
    position = builtins.unsafeGetAttrPos "undocumented" functionFixture;
  };
  legacyProblems = inputs.self.lib.internal.documentation.problems {
    description = "A flake that exists to check the documentation rules themselves.";
    sections = [ legacyFunction ];
  };
  libraryFunctions = inputs.self.lib.internal.documentation.build (
    args
    // {
      library = functionFixture;
    }
  );
  libraryValues = inputs.self.lib.internal.documentation.build (
    args
    // {
      library = valueFixture;
    }
  );
  moduleEntry =
    name:
    let
      file = lib.findFirst (
        candidate: indexOf "probe" (candidate.sections or [ ]) != null
      ) null (exampleDocs name).files;
    in
    indexOf "probe" file.sections;
  renderedNested = inputs.self.lib.internal.section.render {
    depth = 3;
    s = inputs.self.lib.internal.section.make {
      language = "sh";
      title = "probe";
      type = "template";
      usage = "nix run .#probe";
    };
  };
  rfc145Function = inputs.self.lib.internal.document.function {
    fn = functionFixture.add;
    name = "add";
    position = builtins.unsafeGetAttrPos "add" functionFixture;
  };
  runnablePackage = inputs.self.lib.internal.document.package {
    name = "runnable";
    package = pkgs.writeShellScriptBin "runnable" "true" // {
      meta.mainProgram = "runnable";
    };

  };
  shadowedFunction = inputs.self.lib.internal.document.function {
    fn = functionFixture.shadowed;
    name = "shadowed";
    position = builtins.unsafeGetAttrPos "shadowed" functionFixture;
  };
  splitDocumentation = inputs.self.lib.internal.documentation.build (
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
  testedPackage = inputs.self.lib.internal.document.package {
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
  valueFixture = import ../fixtures/library/values.nix { inherit lib; };
  valueSection =
    let
      file = lib.findFirst (
        candidate: indexOf "Public" (candidate.sections or [ ]) != null
      ) null libraryValues.files;
      public = indexOf "Public" file.sections;
    in
    indexOf "probeValue" public.sections;
  withReexports = inputs.self.lib.internal.documentation.build (
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
