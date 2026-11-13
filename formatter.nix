{
  pkgs,
  flake,
}:
let
  formatter = pkgs.writeShellScriptBin "treefmt" ''
    exec ${treefmtEval.config.build.wrapper}/bin/treefmt --no-cache "$@"
  '';
  treefmtEval = flake.inputs.treefmt-nix.lib.evalModule pkgs {
    imports = [ flake.inputs.pedantix.treefmtModules.default ];
    programs = {
      deadnix.enable = true;
      flake-edit.enable = true;
      pedantix.enable = true;
      statix.enable = true;
    };
    projectRootFile = "flake.nix";
  };
in
formatter
// {
  meta.description = "treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.";
}
