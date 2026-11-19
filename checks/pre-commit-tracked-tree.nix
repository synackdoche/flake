{ pkgs, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  script = pkgs.writeShellScript "check-tracked-tree" ''
    set -eu
    export PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          git
        ]
      )
    }"
    work=$(mktemp -d)
    repo="$work/repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q
    printf '{ }\n' > flake.nix
    printf 'tracked\n' > tracked.txt
    git add flake.nix tracked.txt
    git -c user.email=check@local -c user.name=check commit -qm initial
    printf 'super-secret-CANARY\n' > untracked-secret
    ${trackedTree}
    [ -f "$tracked_tree/flake.nix" ] || { echo "no tracked flake.nix copied" >&2; exit 1; }
    [ -f "$tracked_tree/tracked.txt" ] || { echo "tracked file missing from copy" >&2; exit 1; }
    if [ -f "$tracked_tree/untracked-secret" ]; then
      echo "untracked secret leaked into the tracked tree" >&2
      exit 1
    fi
    echo "the tracked tree carries only tracked files"
  '';
  trackedTree = builtins.readFile ../fixtures/pre-commit/tracked-tree.sh;
in
pkgs.runCommand "pre-commit-tracked-tree"
  {
    meta.description = "Checks that the jail hook copies only tracked files, so untracked secrets never reach the Nix store.";
  }
  ''
    ${script}
    touch $out
  ''
