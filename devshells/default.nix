{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.devShell {
  inherit pkgs;
  preCommit = inputs.self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit;
}
