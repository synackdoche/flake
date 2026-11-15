{ lib, ... }:
{
  meta.description = "First module provides alpha.";
  options.first.enabled = lib.mkOption {
    default = false;
    description = "Whether first is enabled.";
    type = lib.types.bool;
  };
}
