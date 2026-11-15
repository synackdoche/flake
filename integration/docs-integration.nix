{
  pkgs,
  synackdoche-flake,
}:
let
  inherit (pkgs) lib;
  preamble = ''
    set -eu
    export PATH="${lib.makeBinPath runtimeInputs}"
    export NIX_CONFIG="''${NIX_CONFIG:-extra-experimental-features = nix-command flakes}"
    system=${system}

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

    source=''${DOCS_INTEGRATION_SOURCE:-${synackdoche-flake}}
    if touch "$source/.write-probe" 2> /dev/null; then
      rm -f "$source/.write-probe"
      fail "the repository the suite reads is writable, so a bug could mutate it"
    fi
    pass "the repository the suite reads is read-only"

    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    repo="$work/repo"
    cp -rL "$source" "$repo"
    chmod -R u+w "$repo"
    rm -rf "$repo/.git"

    commit() {
      git -c user.email=check@local -c user.name=check commit -qm "$1"
    }

    cd "$repo"
    git init -q
    git add -A
    commit initial
  '';
  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    findutils
    gnugrep
    gnused
    git
    nix
  ];
  suite = name: body: pkgs.writeShellScriptBin "docs-integration-${name}" (preamble + body);
  system = pkgs.stdenv.hostPlatform.system;
in
{
  all-types = suite "all-types" ''
    mkdir "$work/alltypes"
    cd "$work/alltypes"
    nix flake init -t "$repo#minimal" > /dev/null 2>&1 || fail "all-types: could not instantiate the minimal template"
    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix
    sed -i 's|description = "Minimal repository — the smallest flake that uses the SYNACKDOCHE base flake";|description = "All-types consumer exercising every documented output kind of the base flake";|' flake.nix

    mkdir -p modules/nixos packages lib hosts/example templates/demo
    echo '{ config, lib, ... }:' > modules/nixos/example.nix
    echo '{' >> modules/nixos/example.nix
    echo '  config = { };' >> modules/nixos/example.nix
    echo '  options = {' >> modules/nixos/example.nix
    echo '    example.enabled = lib.mkOption { description = "Whether the example subsystem is enabled."; default = false; type = lib.types.bool; };' >> modules/nixos/example.nix
    echo '  };' >> modules/nixos/example.nix
    echo '  meta = {' >> modules/nixos/example.nix
    echo '    description = "Enables the example subsystem.";' >> modules/nixos/example.nix
    echo '    example = { example.enabled = true; };' >> modules/nixos/example.nix
    echo '  };' >> modules/nixos/example.nix
    echo '}' >> modules/nixos/example.nix
    printf '%s\n' '{ lib, ... }:' '{' '  meta.description = "First module provides alpha.";' '  options.first.enabled = lib.mkOption { description = "Whether first is enabled."; default = false; type = lib.types.bool; };' '}' > modules/nixos/first.nix
    printf '%s\n' '{ lib, ... }:' '{' '  meta.description = "Second module provides beta.";' '  options.second.enabled = lib.mkOption { description = "Whether second is enabled."; default = false; type = lib.types.bool; };' '}' > modules/nixos/second.nix
    printf '%s\n' '{ lib, ... }:' '{' '  imports = [ ./first.nix ./second.nix ];' '  meta.description = "Composed module importing first and second.";' '  options.composed.enabled = lib.mkOption { description = "Whether composed is enabled."; default = false; type = lib.types.bool; };' '}' > modules/nixos/composed.nix
    printf '%s\n' '{ pkgs, ... }:' 'pkgs.hello' > packages/hello.nix
    echo '{ inputs, ... }:' > lib/default.nix
    echo '{' >> lib/default.nix
    echo '  /**' >> lib/default.nix
    echo '    Doubles its argument.' >> lib/default.nix
    echo >> lib/default.nix
    echo '    # Type' >> lib/default.nix
    echo >> lib/default.nix
    echo '    double :: Int -> Int' >> lib/default.nix
    echo >> lib/default.nix
    echo '    # Arguments' >> lib/default.nix
    echo >> lib/default.nix
    echo '    - `x`: the value to double' >> lib/default.nix
    echo '  */' >> lib/default.nix
    echo '  double = { x }: x * 2;' >> lib/default.nix
    echo '}' >> lib/default.nix
    echo '{ inputs, ... }:' > hosts/example/configuration.nix
    echo '{' >> hosts/example/configuration.nix
    echo '  imports = [ inputs.self.nixosModules.example ];' >> hosts/example/configuration.nix
    echo '  meta.description = "The example host runs the demo stack.";' >> hosts/example/configuration.nix
    echo '  networking.hostName = "example";' >> hosts/example/configuration.nix
    echo '  system.stateVersion = "24.05";' >> hosts/example/configuration.nix
    echo '  nixpkgs.hostPlatform = "x86_64-linux";' >> hosts/example/configuration.nix
    echo '  fileSystems."/" = { device = "none"; fsType = "tmpfs"; };' >> hosts/example/configuration.nix
    echo '  boot.loader.systemd-boot.enable = true;' >> hosts/example/configuration.nix
    echo '}' >> hosts/example/configuration.nix
    echo '{ description = "A demo template."; }' > templates/demo/flake.nix

    git init -q
    git add -A
    rm -f flake.lock
    nix flake lock > "$work/alltypes-lock.log" 2>&1 || fail "all-types: could not lock: $(tail -3 "$work/alltypes-lock.log")"

    hello=$(nix eval --raw ".#packages.$system.hello.name" 2>/dev/null) || fail "all-types: the callable flake dropped the client's package"
    echo "$hello" | grep -q hello || fail "all-types: the callable flake clobbered the client's package: $hello"
    pass "the callable flake keeps a client's packages alongside the mixed-in docs"

    nix run .#docs > "$work/alltypes-docs.log" 2>&1 || fail "all-types: the docs app failed: $(tail -3 "$work/alltypes-docs.log")"

    [ -f modules/README.md ] || fail "all-types: no modules/README.md"
    [ ! -f modules/nixos/example/README.md ] && [ ! -f modules/nixos/example.README.md ] || fail "all-types: a per-module README still exists"
    grep -q '^## example$' modules/README.md || fail "all-types: modules/README.md documents no example module"
    grep -q '\[modules/nixos/example.nix\](nixos/example.nix)' modules/README.md || fail "all-types: the module has no source link relative to modules/README.md"
    grep -q 'Declare values under the namespaces above' modules/README.md && fail "all-types: the hardcoded example stub is still rendered"
    grep -q '^### example$' modules/README.md || fail "all-types: the module's meta.example is not rendered"
    grep -q 'enabled = true' modules/README.md || fail "all-types: the rendered example does not show the configured option"
    grep -q 'options.meta' modules/nixos/example.nix && fail "all-types: the client module declares the meta options itself"
    grep -q 'meta\.description' modules/README.md && fail "all-types: a client module's Options list the meta namespace"

    grep -q '^## first$' modules/README.md || fail "all-types: modules/README.md documents no first module"
    grep -q '^## second$' modules/README.md || fail "all-types: modules/README.md documents no second module"
    grep -q '^## composed$' modules/README.md || fail "all-types: modules/README.md documents no composed module"
    grep -A10 '^## first$' modules/README.md | grep -q 'First module provides alpha\.' || fail "all-types: the first module is not documented with its own description"
    grep -A10 '^## second$' modules/README.md | grep -q 'Second module provides beta\.' || fail "all-types: the second module is not documented with its own description"
    grep -A10 '^## composed$' modules/README.md | grep -q 'Composed module importing first and second\.' || fail "all-types: the composed module is not documented with its own description"
    grep -A10 '^## composed$' modules/README.md | grep -q 'First module provides alpha\.' && fail "all-types: the composed module inherits an imported module's description"
    grep -q '#### first\.enabled' modules/README.md || fail "all-types: the composed module does not document the options it imports"
    grep -q '#### composed\.enabled' modules/README.md || fail "all-types: the composed module does not document its own options"

    grep -q '^## hello$' packages/README.md || fail "all-types: packages/README.md documents no hello package"
    grep -q '\[packages/hello.nix\](hello.nix)' packages/README.md || fail "all-types: the package has no source link relative to packages/README.md"

    grep -q '^## double$' lib/README.md || fail "all-types: lib/README.md documents no double function"
    grep -q '\[lib/default.nix:.*\](default.nix)' lib/README.md || fail "all-types: the function has no source link relative to lib/README.md"

    [ -f systems/README.md ] || fail "all-types: no systems/README.md"
    grep -q '^## example$' systems/README.md || fail "all-types: systems/README.md documents no example system"
    grep -A10 '^## example$' systems/README.md | grep -q 'The example host runs the demo stack\.' || fail "all-types: the system is not documented with the description the host states"
    grep -A10 '^## example$' systems/README.md | grep -q 'hostName example, system x86_64-linux' || fail "all-types: the system does not state its host name and system"
    grep -A10 '^## example$' systems/README.md | grep -q 'Enables the example subsystem\.' && fail "all-types: the system inherits an imported module's description"

    grep -q '^## demo$' templates/README.md || fail "all-types: templates/README.md documents no demo template"
    grep -q '\[templates/demo/flake.nix\](demo/flake.nix)' templates/README.md || fail "all-types: the template has no source link relative to templates/README.md"

    grep -q 'README.md#example' README.md || fail "all-types: the root index does not link to the module or system"
    grep -q 'packages/README.md#hello' README.md || fail "all-types: the root index does not link to the package"
    grep -q '\(lib\|modules\|systems\|templates\)/README.md#double' README.md || fail "all-types: the root index does not link to the function"
    pass "the docs cover a module, a system, a lib function, a package and a template, each in a single group file with a source link"
  '';
  check-mode = suite "check-mode" ''
    cd "$repo"
    rm -f README.md lib/README.md checks/README.md packages/README.md templates/README.md
    git add -A
    commit "drop the generated documentation"
    nix run .#docs > /dev/null 2>&1 || fail "the docs app failed to write the documentation"

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
  '';
  gate = suite "gate" ''
    cd "$repo"
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
  '';
  template = suite "template" ''
    mkdir "$work/client"
    cd "$work/client"
    nix flake init -t "$repo#minimal" > /dev/null 2>&1 || fail "nix flake init could not instantiate the minimal template"
    [ -f flake.nix ] || fail "the template wrote no flake.nix"
    [ ! -f formatter.nix ] || fail "the template still ships formatter.nix although the callable flake mixes in the default formatter"
    [ ! -d packages ] || fail "the template still ships packages/docs.nix although the callable flake mixes in the docs package"
    [ ! -d checks ] || fail "the template still ships checks/ although the callable flake mixes in the default checks"
    [ ! -d devshells ] || fail "the template still ships devshells/ although the callable flake mixes in the default devshell"
    grep -q 'synackdoche-flake' flake.nix || fail "the template does not depend on this flake"
    pass "nix flake init -t <flake>#minimal writes a minimal client repository"

    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix
    grep -q "url = \"path:$repo\";" flake.nix || fail "the template input could not be pointed at this flake"
    rm -f flake.lock
    git init -q
    git add -A
    nix flake lock > "$work/lock.log" 2>&1 || fail "the instantiated template could not resolve this flake as its base: $(tail -3 "$work/lock.log")"
    pass "the instantiated template locks against this flake"

    packages=$(nix eval --json ".#packages.$system" --apply 'builtins.attrNames') \
      || fail "the callable flake produces no packages output in the client"
    echo "$packages" | grep -q '"docs"' || fail "the callable flake does not mix in the docs package: $packages"
    nix eval ".#formatter.$system" --apply 'd: d ? outPath' 2>/dev/null \
      || fail "the callable flake does not mix in the default formatter"
    nix eval ".#devShells.$system.default" --apply 'd: d ? outPath' 2>/dev/null \
      || fail "the callable flake does not mix in the default devshell"
    checks=$(nix eval --json ".#checks.$system" --apply 'builtins.attrNames') \
      || fail "the callable flake produces no checks output in the client"
    for check in readme pre-commit documentation; do
      echo "$checks" | grep -q "\"$check\"" || fail "the callable flake does not mix in the $check check: $checks"
    done
    pass "the callable flake mixes in the default formatter, docs package, devshell and checks"

    nix run .#docs > /dev/null 2>&1 || fail "the docs app failed in the instantiated template"
    [ -f README.md ] || fail "the instantiated template produced no README"
    grep -q 'Minimal repository' README.md || fail "the instantiated template README does not carry its description"
    pass "nix run .#docs works in the instantiated template"

    git add -A
    commit "generated documentation"
    pass "the instantiated template commits its generated documentation"

    for check in documentation readme pre-commit; do
      nix build --no-link ".#checks.$system.$check" > "$work/$check.log" 2>&1 \
        || fail "the instantiated template fails its $check check: $(tail -3 "$work/$check.log")"
    done
    pass "the instantiated template passes its documentation, readme and pre-commit checks"

    mkdir "$work/override"
    cd "$work/override"
    nix flake init -t "$repo#minimal" > /dev/null 2>&1 || fail "override: could not instantiate the minimal template"
    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix
    mkdir -p packages checks devshells
    printf '{ pkgs, ... }:\npkgs.hello\n' > formatter.nix
    printf '{ pkgs, ... }:\npkgs.hello\n' > packages/docs.nix
    printf '{ pkgs, ... }:\npkgs.hello\n' > checks/readme.nix
    printf '{ pkgs, ... }:\npkgs.hello\n' > devshells/default.nix
    git init -q && git add -A && rm -f flake.lock
    nix flake lock > "$work/override-lock.log" 2>&1 || fail "override: could not lock: $(tail -3 "$work/override-lock.log")"
    for attr in formatter.$system packages.$system.docs checks.$system.readme devShells.$system.default; do
      name=$(nix eval --raw ".#$attr" --apply 'd: d.name' 2>/dev/null) || fail "override: $attr did not evaluate"
      echo "$name" | grep -q hello || fail "override: $attr kept the default instead of the client's value: $name"
    done
    pass "the client's own formatter, docs, readme check and devshell win over the defaults"
  '';
}
