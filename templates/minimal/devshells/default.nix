{ pkgs, inputs, ... }:
inputs.synackdoche-flake.lib.devShell {
  inherit pkgs;
  preCommit = inputs.self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit;
}
