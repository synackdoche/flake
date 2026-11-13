{
  description = "SYNACKDOCHE base flake";
  inputs = {
    blueprint = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/blueprint";
    };
    git-hooks = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:cachix/git-hooks.nix";
    };
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    pedantix = {
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
      url = "github:swarsel/pedantix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
  outputs =
    inputs:
    inputs.blueprint {
      inherit inputs;
      systems = [ "x86_64-linux" ];
    }
    // {
      title = "SYNACKDOCHE base flake — shared formatter, pre-commit, docgate checks and flake scaffolding";
    };
}
