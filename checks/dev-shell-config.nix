{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  assertionList = [
    {
      assertion = lib.all (name: lib.elem name (names merged.buildInputs)) (
        names preCommit.enabledPackages
      );
      message = "the default development shell keeps the packages the pre-commit check enables";
    }
    {
      assertion =
        lib.elem pkgs.jq.name (names merged.buildInputs)
        && !(lib.elem pkgs.jq.name (names plain.buildInputs));
      message = "a devShellConfig package is merged into the default development shell, not into a shell built without it";
    }
    {
      assertion = lib.hasInfix hook mergedHook;
      message = "the default development shell keeps the shell hook the pre-commit check states";
    }
    {
      assertion = lib.hasInfix "export PROBE=1" mergedHook && !(lib.hasInfix "export PROBE=1" plainHook);
      message = "a devShellConfig shellHook is merged into the default development shell, not into a shell built without it";
    }
    {
      assertion = plainHook == hook && names plain.buildInputs == names preCommit.enabledPackages;
      message = "a client that states no devShellConfig gets the base shell unchanged";
    }
  ];
  dev = inputs.self.lib.internal.shells.dev;
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
  hook = builtins.unsafeDiscardStringContext preCommit.shellHook;
  merged = dev {
    inherit pkgs preCommit;
    devShellConfig = {
      buildInputs = [ pkgs.jq ];
      shellHook = "export PROBE=1";
    };
  };
  mergedHook = builtins.unsafeDiscardStringContext merged.shellHook;
  names = packages: map (package: package.name) packages;
  plain = dev { inherit pkgs preCommit; };
  plainHook = builtins.unsafeDiscardStringContext plain.shellHook;
  preCommit = inputs.self.lib.internal.dev.preCommit {
    inherit pkgs;
    src = ../.;
  };
in
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    echo "${toString (lib.length evaluated.config.assertions)} assertions held"
    touch $out
  '';
  meta.description = "Checks that an evalModule-shaped devShellConfig is merged into the default development shell and that its packages and shell hook survive.";
  name = "docgate-devshell-config";
}
