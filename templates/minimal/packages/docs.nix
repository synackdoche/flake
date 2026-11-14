{ pkgs, inputs, ... }:
inputs.synackdoche-flake.packages.${pkgs.stdenv.hostPlatform.system}.docs
