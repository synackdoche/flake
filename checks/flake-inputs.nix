{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  accepts =
    root:
    builtins.tryEval (gate {
      inherit pkgs root;
    });
  acceptsWithIgnore =
    root: ignored:
    builtins.tryEval (gate {
      inherit pkgs root;
      ignore = ignored;
    });
  checks = [
    {
      assertion = passing ../fixtures/flake-inputs/remote;
      message = "a lock that pins only remote inputs is accepted";
    }
    {
      assertion = passing ../fixtures/flake-inputs/in-repo;
      message = "a path input that resolves inside the repository is accepted";
    }
    {
      assertion =
        let
          result = accepts ../fixtures/flake-inputs/external;
        in
        !result.success;
      message = "a path input that resolves outside the repository is rejected";
    }
    {
      assertion =
        let
          result = acceptsWithIgnore ../fixtures/flake-inputs/external [ "outside" ];
        in
        result.success;
      message = "a path input that resolves outside the repository is accepted when its name is ignored";
    }
    {
      assertion =
        let
          result = acceptsWithIgnore ../fixtures/flake-inputs/external [ "other" ];
        in
        !result.success;
      message = "ignoring a name the lock does not use does not exempt a path input";
    }
  ];
  failed = lib.filter (each: !each.assertion) checks;
  gate = inputs.self.lib.internal.gate.flakeInputs;
  passing = root: (accepts root).success;
in
assert lib.assertMsg (failed == [ ])
  "failed flake-inputs assertions:\n${
    lib.concatMapStringsSep "\n" (each: "- ${each.message}") failed
  }";
inputs.self.lib.internal.gate.flakeInputs {
  inherit pkgs;
  root = inputs.self.outPath;
}
