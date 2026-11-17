{
  pkgs,
  inputs,
  ...
}:
let
  formatter = import ../formatter.nix {
    inherit pkgs;
    flake.inputs = { inherit (inputs) pedantix treefmt-nix; };
    formatterConfig.imports = [
      (
        { pkgs, ... }:
        let
          probe = pkgs.writeShellScriptBin "probe" ''
            for f in "$@"; do
              if [ "$(cat "$f")" = probe ]; then
                printf 'PROBE\n' > "$f"
              fi
            done
          '';
        in
        {
          config = {
            programs.probe = {
              enable = true;
              package = probe;
            };
            settings.formatter.probe = {
              command = "${probe}/bin/probe";
              includes = [ "*.probe" ];
            };
          };
          options.programs.probe = {
            enable = pkgs.lib.mkEnableOption "probe";
            package = pkgs.lib.mkOption { type = pkgs.lib.types.package; };
          };
        }
      )
    ];
  };
  hookSet = inputs.self.lib.internal.dev.preCommit {
    inherit pkgs formatter;
    src = ../.;
  };
in
assert pkgs.lib.assertMsg (
  hookSet.config.hooks.treefmt.packageOverrides.treefmt.outPath == formatter.outPath
) "the treefmt hook does not run the formatter it was given";
pkgs.stdenv.mkDerivation {
  buildCommand = ''
    work=$(mktemp -d)
    cp ${../fixtures/formatter/probe.probe} "$work/page.probe"
    chmod u+w "$work/page.probe"
    cd "$work"
    touch flake.nix

    if ${formatter}/bin/treefmt --ci page.probe; then
      echo "the formatter ignored formatterConfig: an unformatted file passed --ci" >&2
      exit 1
    fi
    grep -qx 'PROBE' page.probe || {
      echo "formatterConfig's formatter did not run: page.probe was left unchanged" >&2
      exit 1
    }
    ${formatter}/bin/treefmt --ci page.probe || exit 1

    touch $out
  '';
  meta.description = "Checks that an evalModule-shaped formatterConfig is merged into the canonical formatter and that the pre-commit hook runs the resulting formatter.";
  name = "docgate-formatter";
}
