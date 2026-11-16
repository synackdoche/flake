{ lib }:
{
  probeBare = 0;
  probeUntyped.meta.description = "A value whose documentation states no type.";
  probeValue.meta = {
    description = "The answer to everything.";
    type = "Int";
  };
  shape = {
    meta = {
      description = "Option type whose shape the documentation renders.";
      type = "OptionType";
    };
    value = lib.types.submodule {
      options.probe.enabled = lib.mkOption {
        default = false;
        description = "Whether the probed option is enabled.";
        type = lib.types.bool;
      };
    };
  };
  types.nested = {
    __functor = _self: { value }: value;
    meta = {
      args.value = {
        description = "the value to return";
        type = lib.types.anything;
      };
      description = "Returns the nested value unchanged.";
    };
  };
}
