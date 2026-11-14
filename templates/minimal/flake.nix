{
  description = "Minimal repository — the smallest flake that uses the SYNACKDOCHE base flake";
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
      systems = [ "x86_64-linux" ];
    };
}
