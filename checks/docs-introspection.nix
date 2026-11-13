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
  args = import ../docs-args.nix { inherit pkgs inputs; };
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
          name = "fixture";
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
          name = "fixture";
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
      message = "every library function is grouped under lib.internal, so the README has no library section at all";
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
      checks = {
        probe = pkgs.hello;
      };
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
  runnablePackage = inputs.self.lib.internal.documentPackage {
    name = "runnable";
    package = pkgs.writeShellScriptBin "runnable" "true" // {
      meta = {
        mainProgram = "runnable";
      };
    };

  };
  splitDocumentation = inputs.self.lib.internal.documentation (
    args
    // {
      library = {
        probe =
          {
            value,
          }:
          value;
      };
    }
  );
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
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that the generated documentation is complete and usable, and that incomplete documentation is reported.";
  name = "docgate-introspection";
}
