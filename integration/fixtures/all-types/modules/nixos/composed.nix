{ lib, ... }:
{
  imports = [
    ./first.nix
    ./second.nix
  ];
  meta.description = "Composed module importing first and second.";
  options.composed.enabled = lib.mkOption {
    default = false;
    description = "Whether composed is enabled.";
    type = lib.types.bool;
  };
}
