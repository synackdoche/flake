{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.devShell {
  inherit pkgs;
  preCommit = inputs.self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit;
}
