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
    inputs.synackdoche-flake {
      inherit inputs;
      flakeInputs.ignore = [ "synackdoche-flake" ];
      systems = [ "x86_64-linux" ];
    };
}
