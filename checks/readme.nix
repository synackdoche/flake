{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.readmeGate (
  inputs.self.lib.internal.flakeArgs {
    inherit pkgs;
    checks = { };
    flake = inputs.self;
    root = inputs.self.outPath;
  }
)
