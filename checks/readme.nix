{
  pkgs,
  inputs,
  ...
}:
inputs.self.lib.internal.readmeGate (import ../docs-args.nix { inherit pkgs inputs; })
