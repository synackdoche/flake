{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
in
{
  answer = {
    meta = {
      description = "The answer every consumer wants to read from the flake's library.";
      type = "Int";
    };
    value = 42;
  };
  double = {
    __functor = _self: { x }: x * 2;
    meta = {
      args.x = {
        description = "the value to double";
        type = lib.types.int;
      };
      description = "Doubles its argument.";
    };
  };
  types = {
    strings.bla = {
      __functor = _self: { x }: toString x;
      meta = {
        args.x = {
          description = "the value to render";
          type = lib.types.anything;
        };
        description = "Renders its argument as a string.";
      };
    };
    wrap = {
      __functor = _self: { value }: [ value ];
      meta = {
        args.value = {
          description = "the value to wrap";
          type = lib.types.anything;
        };
        description = "Wraps a value in a list.";
      };
    };
  };
}
