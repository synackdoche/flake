{
  pkgs,
  flake,
}:
let
  formatter = pkgs.writeShellScriptBin "treefmt" ''
    exec ${treefmtEval.config.build.wrapper}/bin/treefmt --no-cache "$@"
  '';
  treefmtEval = flake.inputs.treefmt-nix.lib.evalModule pkgs {
    imports = [
      flake.inputs.pedantix.treefmtModules.default
      {
        options.programs.flake-edit.settings.follow.transitive_min = pkgs.lib.mkOption {
          default = 2;
          description = "The minimum number of transitive dependencies to follow when editing a flake.";
          type = pkgs.lib.types.int;
        };
      }
    ];
    programs = {
      deadnix.enable = true;
      flake-edit.enable = true;
      pedantix = {
        enable = true;
        settings = {
          args = {
            first = [
              "self"
              "lib"
              "config"
              "pkgs"
            ];
            last = [
              "<defaulted>"
              "..."
            ];
          };
          attrs = {
            blank-lines = 0;
            flatten = true;
            merge = true;
            name-style = "identifier";
            sort = true;
          };
          lets.sort = true;
        };
      };
      statix.enable = true;
    };
    projectRootFile = "flake.nix";
  };
in
formatter
// {
  meta.description = "treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.";
}
