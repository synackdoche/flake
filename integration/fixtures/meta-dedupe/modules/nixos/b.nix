{ lib, ... }:
{
  meta.description = "Module B states its own description.";
  options.b.enabled = lib.mkOption {
    default = false;
    description = "Whether b is enabled.";
    type = lib.types.bool;
  };
}
