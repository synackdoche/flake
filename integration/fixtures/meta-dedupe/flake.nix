{
  description = "Two-module consumer that demonstrates how the injected meta options dedupe";
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
