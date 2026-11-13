{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  inherit
    (
      (lib.evalModules {
        modules = [
          {
            options.toy.good = lib.mkOption {
              default = "";
              description = "A complete sentence describing this option's contract.";
              type = lib.types.str;
            };
          }
        ];
      })
    )
    options
    ;
  assertionList = [
    {
      assertion =
        problems {
          inherit options;
          assertions = [ good ];
        } == [ ];
      message = "a well-formed assertion message violates nothing";
    }
    {
      assertion =
        lib.any (lib.hasInfix "message names 'toy.absent', which is not a declared option")
          (problems {
            inherit options;
            assertions = [ wrongPath ];
          });
      message = "a message naming a path that is not a declared option is reported";
    }
    {
      assertion = lib.any (lib.hasInfix "message has no '<path>: ' prefix") (problems {
        inherit options;
        assertions = [ malformed ];
      });
      message = "a message without the option path prefix is reported";
    }
    {
      assertion = lib.any (lib.hasInfix "message has no 'how to fix:' line") (problems {
        inherit options;
        assertions = [ noFix ];
      });
      message = "a message without the how-to-fix line is reported";
    }
  ];
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
  good = inputs.self.lib.internal.mkAssertion {
    at = [
      "toy"
      "good"
    ];
    condition = false;
    expected = "the expected shape";
    fix = "the remedy";
    violation = "violates the rule";
  };
  malformed = {
    assertion = false;
    message = "boom";
  };
  noFix = {
    assertion = false;
    message = "toy.good: boom\n  expected: something";
  };
  problems = inputs.self.lib.internal.messageProblems;
  wrongPath = inputs.self.lib.internal.mkAssertion {
    at = [
      "toy"
      "absent"
    ];
    condition = false;
    expected = "the expected shape";
    fix = "the remedy";
    violation = "violates the rule";
  };
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that an assertion message names a declared option and states both the expectation and the fix.";
  name = "docgate-messages";
}
