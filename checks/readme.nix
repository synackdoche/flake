{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.gate.readme (
  inputs.self.lib.internal.flake.args {
    inherit pkgs;
    checks = { };
    flake = inputs.self;
    root = inputs.self.outPath;
  }
)
