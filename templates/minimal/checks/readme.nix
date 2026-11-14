{
  pkgs,
  inputs,
  ...
}:
inputs.synackdoche-flake.lib.readmeGate (
  inputs.synackdoche-flake.lib.flakeArgs {
    inherit pkgs;
    checks = { };
    flake = inputs.self;
    root = ../.;
  }
)
