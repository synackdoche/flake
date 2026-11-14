{
  pkgs,
  inputs,
  ...
}:
inputs.synackdoche-flake.lib.docsGate {
  inherit pkgs;
  flake = inputs.self;
  root = ../.;
}
