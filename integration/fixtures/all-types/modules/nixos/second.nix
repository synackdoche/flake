{ lib, ... }:
{
  meta.description = "Second module provides beta.";
  options.second.enabled = lib.mkOption {
    default = false;
    description = "Whether second is enabled.";
    type = lib.types.bool;
  };
}
