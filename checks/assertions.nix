{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  assertion = inputs.self.lib.internal.mkAssertion {
    at = [
      "toy"
      "good"
    ];
    condition = true;
    expected = "the expected shape";
    fix = "the remedy";
    violation = "violates the rule";
  };
  assertionList = [
    {
      inherit (assertion) assertion;
      message = "the condition round-trips into the assertion";
    }
    {
      assertion = lib.hasInfix "toy.good: violates the rule" assertion.message;
      message = "the message opens with the dotted option path and the violation";
    }
    {
      assertion = lib.hasInfix "expected: the expected shape" assertion.message;
      message = "the message states what is expected";
    }
    {
      assertion = lib.hasInfix "how to fix: the remedy" assertion.message;
      message = "the message states how to fix it";
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
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that an assertion keeps its condition and states the violation, the expectation and the fix.";
  name = "docgate-assertions";
}
