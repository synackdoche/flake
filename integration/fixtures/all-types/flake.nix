{
  description = "All-types consumer exercising every documented output kind of the base flake";
  inputs = {
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    synackdoche-flake = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:synackdoche/flake";
    };
  };
  outputs =
    inputs:
    let
      base = inputs.synackdoche-flake {
        inherit inputs;
        flakeInputs.ignore = [ "synackdoche-flake" ];
        systems = [ "x86_64-linux" ];
      };
    in
    base
    // {
      __functor = _: args: {
        inherit (args) probe;
      };
      meta = {
        args.probe = {
          description = "value the client's own functor returns unchanged, so its call shape states what it adds";
          type = inputs.nixpkgs.lib.types.str;
        };
        description = "Adds a functor of its own on top of the base flake's outputs, so the client's call shape is documented next to them.";
      };
    };
}
