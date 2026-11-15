{ lib, ... }:
{
  meta.description = "Module A states its own description.";
  options.a.enabled = lib.mkOption {
    default = false;
    description = "Whether a is enabled.";
    type = lib.types.bool;
  };
}
