{
  lib,
  flake,
  inputs,
  ...
}:
{
  imports = lib.optional (flake ? outPath) {
    options.inputs-aware.flakePath = inputs.nixpkgs.lib.mkOption {
      default = flake.outPath;
      description = "Store path of the flake that documents this module.";
      type = inputs.nixpkgs.lib.types.str;
    };
  };
  meta.description = "Builds an import from the flake and its inputs.";
  options.inputs-aware = {
    enable = lib.mkEnableOption "the inputs-aware probe";
    inputCount = lib.mkOption {
      default = builtins.length (builtins.attrNames inputs);
      description = "Number of inputs the module received from the flake.";
      type = lib.types.int;
    };
  };
}
