{ lib, ... }:
lib.removeAttrs ((import ../modules/nixos/meta-options.nix) { inherit lib; }) [ "meta" ]
