{ lib, ... }:
{
  config = { };
  meta = {
    description = "Enables the example subsystem.";
    example.example.enabled = true;
  };
  options.example.enabled = lib.mkOption {
    default = false;
    description = "Whether the example subsystem is enabled.";
    type = lib.types.bool;
  };
}
