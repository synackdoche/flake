{
  description = "Consumer that includes its own hook in the base flake's pre-commit set";
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
      preCommitHooks = pkgs: {
        probe = {
          always_run = true;
          enable = true;
          entry = "${pkgs.writeShellScript "probe-hook" "printf probe >> .probe-ran"}";
          name = "probe";
          pass_filenames = false;
        };
      };
      systems = [ "x86_64-linux" ];
    };
}
