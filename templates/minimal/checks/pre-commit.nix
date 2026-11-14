{ pkgs, inputs, ... }:
inputs.synackdoche-flake.lib.preCommit {
  inherit pkgs;
  src = ../.;
}
