{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  assertionList = [
    {
      assertion = lib.length problems == 5;
      message = "an option set with an undescribed, short, repeated and foreign description reports exactly five problems, got ${toString (lib.length problems)}";
    }
    {
      assertion = lib.any (lib.hasInfix "toy.undocumented: has no description") problems;
      message = "an option without a description is rejected";
    }
    {
      assertion = lib.any (lib.hasInfix "toy.short: description is 10 characters") problems;
      message = "a description too short to state a contract is rejected";
    }
    {
      assertion = lib.any (lib.hasInfix "toy.repeats: repeats the description") problems;
      message = "a description repeated from another option is rejected";
    }
    {
      assertion = lib.any (lib.hasInfix "toy.foreign: mentions pedantix") problems;
      message = "a description naming another component of this flake is rejected";
    }
    {
      assertion = problemsFor { module = clean; } == [ ];
      message = "a described option with no duplicated or foreign text violates nothing";
    }
    {
      assertion =
        lib.length (problemsFor {
          allowComponents = [ "pedantix" ];
          module = toy;
        }) == 4;
      message = "declaring a component as allowed stops it being reported as foreign";
    }

  ];
  clean = {
    options.toy.good = lib.mkOption {
      default = "";
      description = "A complete sentence describing this option's contract.";
      type = lib.types.str;
    };
  };
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
  problems = problemsFor { module = toy; };
  problemsFor =
    {
      module,
      allowComponents ? [ ],
    }:
    inputs.self.lib.internal.descriptions.problems {
      inherit allowComponents;
      inherit ((lib.evalModules { modules = [ module ]; })) options;
      components = builtins.attrNames inputs;
    };
  toy = {
    options.toy = {
      foreign = lib.mkOption {
        default = "";
        description = "Delegates rendering to the pedantix formatter, which this option does not use.";
        type = lib.types.str;
      };
      good = lib.mkOption {
        default = "";
        description = "A complete sentence describing this option's contract.";
        type = lib.types.str;
      };
      repeats = lib.mkOption {
        default = "";
        description = "A complete sentence describing this option's contract.";
        type = lib.types.str;
      };
      short = lib.mkOption {
        default = "";
        description = "Too short.";
        type = lib.types.str;
      };
      undocumented = lib.mkOption {
        default = "";
        type = lib.types.str;
      };
    };
  };
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that option descriptions are present, long enough to state a contract, unique, and free of other components of this flake.";
  name = "docgate-descriptions";
}
