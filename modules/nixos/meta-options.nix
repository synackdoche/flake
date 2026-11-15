{ lib, ... }:
let
  perDefiningModule =
    type:
    type
    // {
      merge = _loc: defs: defs;
    };
in
{
  meta = {
    description = "Declares the module metadata options the documentation pipeline reads, so a module states its summary and its worked example without declaring options itself.";
    example.meta = {
      description = "An example";
      example = {
        optionA = "example";
        optionB = 42;
      };
    };
  };
  options.meta = {
    description = lib.mkOption {
      default = null;
      description = "Summary the documentation pipeline shows as the module's heading description.";
      internal = true;
      type = perDefiningModule (lib.types.nullOr lib.types.str);
    };
    example = lib.mkOption {
      default = null;
      description = "Worked configuration the documentation pipeline renders under the module and checks against the module's declared options.";
      internal = true;
      type = perDefiningModule (lib.types.nullOr lib.types.anything);
    };
  };
}
