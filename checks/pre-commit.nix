{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.preCommit {
  inherit pkgs;
  src = ../.;
}
