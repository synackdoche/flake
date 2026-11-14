{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs.nixpkgs) lib;
  enabled = lib.attrNames (lib.filterAttrs (_name: hook: hook.enable or false) hookSet.config.hooks);
  hookSet = inputs.self.lib.preCommit {
    inherit pkgs;
    extraHooks.integration = {
      enable = true;
      entry = "${integrationHook}";
      language = "system";
      name = "docs-integration";
      pass_filenames = false;
    };
    src = ../.;
  };
  integrationHook = pkgs.writeShellScript "docs-integration-hook" ''
    export LANG=''${LANG:-C.UTF-8}
    set -o pipefail
    if [ ! -S /nix/var/nix/daemon-socket/socket ] || ! ${lib.getExe' pkgs.util-linux "unshare"} --user --map-root-user true 2> /dev/null; then
      echo "docs-integration: no nix daemon socket or no user namespaces here, skipping the jail suites"
      exit 0
    fi
    nix=${lib.getExe pkgs.nix}
    suites=( ${lib.concatStringsSep " " suiteNames} )
    installables=()
    for suite in ''${suites[*]}; do
      installables+=("path:$PWD/integration#$suite")
    done
    readarray -t bins < <($nix build --no-link --print-out-paths --override-input synackdoche-flake "path:$PWD" "''${installables[@]}")
    [ "''${#bins[@]}" -eq "''${#suites[@]}" ] || {
      echo "docs-integration: could not build all of the jail suites" >&2
      exit 1
    }
    pids=()
    for i in "''${!suites[@]}"; do
      name="''${suites[$i]}"
      "''${bins[$i]}/bin/docs-integration-$name" 2>&1 | sed "s|^|[''${name}] |" &
      pids+=($!)
    done
    status=0
    for pid in "''${pids[@]}"; do
      wait "$pid" || status=1
    done
    exit "$status"
  '';
  suiteNames = [
    "check-mode"
    "gate"
    "template"
  ];
in
assert lib.assertMsg
  (
    enabled == [
      "docs"
      "integration"
      "treefmt"
    ]
  )
  "the hook set is the formatter, the documentation check and the jailed integration suites, got: ${lib.concatStringsSep ", " enabled}";
assert lib.assertMsg (
  hookSet.config.hooks.treefmt.enable && hookSet.config.hooks.docs.enable
) "the formatter and the documentation check run on every commit";
assert lib.assertMsg hookSet.config.hooks.integration.enable
  "the jailed integration suites run on every commit, and report when they cannot run";
hookSet
