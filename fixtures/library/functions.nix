{ lib }:
{
  add = {
    __functor = _self: { a, b }: a + b;
    meta = {
      args = {
        a = {
          description = "left addend";
          type = lib.types.int;
        };
        b = {
          description = "right addend";
          type = lib.types.int;
        };
      };
      description = "Adds two numbers together.";
    };
  };
  nested.shadowed = 1;
  readOptions = {
    __functor = _self: { opts }: opts.enabled;
    meta = {
      args.opts = {
        description = "option set whose enabled flag the function reports";
        type = lib.types.submodule {
          options.enabled = lib.mkOption {
            default = true;
            type = lib.types.bool;
          };
        };
      };
      description = "Reports the enabled flag of the option set it is handed.";
    };
  };
  second = {
    __functor = _self: { value }: value;
    meta = {
      args.value = {
        description = "the value the function returns";
        type = lib.types.anything;
      };
      description = "Summarises the second function, defined in another file.";
    };
  };
  shadowed = {
    __functor = _self: { value }: value;
    meta = {
      args.value.type = lib.types.anything;
      description = "Summarises the shadowed function, whose name also appears as a nested binding above it.";
    };
  };
  third = {
    __functor = _self: { value }: value;
    meta = {
      args.value = { };
      description = "Summarises the internal function, whose arguments are not documented.";
    };
  };
  undocumented.__functor = _self: { value }: value;
}
