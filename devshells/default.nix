{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.shells.dev {
  inherit pkgs;
  preCommit = inputs.self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit;
}
