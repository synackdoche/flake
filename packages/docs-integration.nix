{
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs) git;
  jail = inputs.jail-nix.lib.init pkgs;
  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    findutils
    gnugrep
    gnused
    git
    nix
  ];
  script = pkgs.writeShellScriptBin "docs-integration" ''
    set -eu
    export PATH="${pkgs.lib.makeBinPath runtimeInputs}"
    export NIX_CONFIG="''${NIX_CONFIG:-extra-experimental-features = nix-command flakes}"

    pass() { printf 'ok: %s\n' "$*"; }
    fail() {
      printf 'FAIL: %s\n' "$*" >&2
      exit 1
    }

    savedIFS=$IFS
    IFS=:
    for entry in $PATH; do
      case "$entry" in
        /nix/store/*) ;;
        *) fail "the check runs with a PATH entry outside the store: $entry" ;;
      esac
    done
    IFS=$savedIFS
    case "$(command -v nix)" in
      /nix/store/*) ;;
      *) fail "nix does not resolve to a store path: $(command -v nix)" ;;
    esac
    pass "the check runs with the tool set declared by its package, not the user's PATH"

    work=$(mktemp -d)
    system=${pkgs.stdenv.hostPlatform.system}
    trap 'rm -rf "$work"' EXIT
    repo="$work/repo"
    cp -r "''${DOCS_INTEGRATION_SOURCE:-${src}}" "$repo"
    chmod -R u+w "$repo"
    rm -rf "$repo/.git"

    commit() {
      git -c user.email=check@local -c user.name=check commit -qm "$1"
    }

    if [ -d /repo ]; then
      if touch /repo/.write-probe 2> /dev/null; then
        fail "the repository is writable inside the jail"
      fi
      pass "the repository is mounted read-only"
    fi

    cd "$repo"
    git init -q
    git add -A
    commit initial

    rm -f README.md lib/README.md checks/README.md packages/README.md templates/README.md
    git add -A
    commit "drop the generated documentation"

    if out=$(nix build --no-link .#checks.x86_64-linux.readme 2>&1); then
      fail "the readme gate passed although no README exists at all"
    fi
    case "$out" in
      *"missing: README.md"*) pass "the readme gate fails when the READMEs do not exist at all" ;;
      *) fail "the readme gate did not report a missing README: $out" ;;
    esac

    nix run .#docs > /dev/null 2>&1 || fail "the docs app failed to write the documentation"
    if out=$(nix build --no-link .#checks.x86_64-linux.readme 2>&1); then
      fail "the readme gate passed with an untracked README, which a flake build does not see"
    fi
    case "$out" in
      *"missing: README.md"*) pass "an untracked README is invisible to a flake build, so the gate still reports it missing" ;;
      *) fail "the readme gate reported something other than a missing README for an untracked file: $out" ;;
    esac

    git add -N README.md lib/README.md checks/README.md packages/README.md templates/README.md
    nix build --no-link .#checks.x86_64-linux.readme || fail "the readme gate failed although the READMEs exist and are only intent-to-add"
    pass "the readme gate passes when the READMEs exist and are not in the index"

    git reset -q
    if out=$(nix run .#docs -- --check 2>&1); then
      fail "check mode passed although the documentation is not staged"
    fi
    case "$out" in
      *"not staged: README.md"*) pass "check mode reports documentation that is not staged" ;;
      *) fail "check mode did not report unstaged documentation: $out" ;;
    esac

    git add -A
    out=$(nix run .#docs -- --check 2>&1) || fail "check mode failed although the documentation is up to date and staged: $out"
    case "$out" in
      *"documentation is up to date and staged"*) pass "check mode passes when the documentation is up to date and staged" ;;
      *) fail "check mode did not confirm staged documentation: $out" ;;
    esac

    printf '\nchanged\n' >> README.md
    if out=$(nix run .#docs -- --check 2>&1); then
      fail "check mode passed although a document is out of date"
    fi
    case "$out" in
      *"out of date: README.md"*) pass "check mode reports a document that is out of date" ;;
      *) fail "check mode did not report an out-of-date document: $out" ;;
    esac
    git checkout -q -- README.md

    printf '# not generated\n' > STRAY.README.md
    git add STRAY.README.md
    commit "add a stray README"
    if out=$(nix build --no-link .#checks.x86_64-linux.readme 2>&1); then
      fail "the readme gate passed with a README the generator does not produce"
    fi
    case "$out" in
      *"stale: STRAY.README.md"*) pass "the readme gate fails on a README the generator does not produce" ;;
      *) fail "the readme gate did not report a stale README: $out" ;;
    esac
    rm -f STRAY.README.md
    git add -A
    commit "drop the stray README"

    mkdir "$work/client"
    cd "$work/client"
    nix flake init -t "$repo#minimal" > /dev/null 2>&1 || fail "nix flake init could not instantiate the minimal template"
    [ -f flake.nix ] || fail "the template wrote no flake.nix"
    [ -f checks/readme.nix ] || fail "the template wrote no readme check"
    [ -f checks/documentation.nix ] || fail "the template wrote no documentation check"
    grep -q 'synackdoche-flake' flake.nix || fail "the template does not depend on this flake"
    pass "nix flake init -t <flake>#minimal writes a client repository"

    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix
    grep -q "url = \"path:$repo\";" flake.nix || fail "the template input could not be pointed at this flake"
    rm -f flake.lock
    git init -q
    git add -A
    nix flake lock > "$work/lock.log" 2>&1 || fail "the instantiated template could not resolve this flake as its base: $(tail -3 "$work/lock.log")"
    pass "the instantiated template locks against this flake"

    nix run .#docs > /dev/null 2>&1 || fail "the docs app failed in the instantiated template"
    [ -f README.md ] || fail "the instantiated template produced no README"
    grep -q 'Minimal repository' README.md || fail "the instantiated template README does not carry its description"
    pass "nix run .#docs works in the instantiated template"

    git add -A
    git -c user.email=check@local -c user.name=check commit -qm "generated documentation"
    pass "the instantiated template commits its generated documentation"

    for check in documentation readme pre-commit; do
      nix build --no-link ".#checks.$system.$check" > "$work/$check.log" 2>&1 \
        || fail "the instantiated template fails its $check check: $(tail -3 "$work/$check.log")"
    done
    pass "the instantiated template passes its documentation, readme and pre-commit checks"

    printf '%s\n' "all documentation behaviour checks passed"
  '';
  src = ../.;
in
jail "docs-integration" (pkgs.lib.getExe script) (
  with jail.combinators;
  [
    network
    (ro-bind "${src}" "/repo")
    (readonly "/nix/store")
    (try-readonly "/nix/var/nix/daemon-socket")
    (set-env "DOCS_INTEGRATION_SOURCE" "/repo")
    (set-env "NIX_REMOTE" "daemon")
  ]
)
// {
  meta = {
    description = "Checks the documentation behaviour that only a real nix and git can show: the readme gate on absent, untracked and stale files, the docs app's check mode, and template instantiation. Runs in a bubblewrap jail with the repository and the store mounted read-only, the nix daemon socket reachable, and no access to the user's nix cache.";
    internal = true;
    mainProgram = "docs-integration";
  };
}
