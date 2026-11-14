{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.readmeGate (
  inputs.self.lib.flakeArgs {
    inherit pkgs;
    checks = { };
    flake = inputs.self;
    root = ../.;
  }
)
