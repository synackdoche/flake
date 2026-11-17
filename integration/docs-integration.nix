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
    cp -r "$repo/integration/fixtures/all-types/." .
    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix

    git init -q
    git add -A
    rm -f flake.lock
    nix flake lock > "$work/alltypes-lock.log" 2>&1 || fail "all-types: could not lock: $(tail -3 "$work/alltypes-lock.log")"

    hello=$(nix eval --raw ".#packages.$system.hello.name" 2>/dev/null) || fail "all-types: the callable flake dropped the client's package"
    echo "$hello" | grep -q hello || fail "all-types: the callable flake clobbered the client's package: $hello"
    pass "the callable flake keeps a client's packages alongside the mixed-in docs"

    grep -q 'meta-options' modules/nixos/*.nix && fail "all-types: a client module imports the meta options itself"
    metaStates=$(nix eval --impure --json --expr "
      let
        flake = builtins.getFlake \"path:$PWD\";
        lib = flake.inputs.nixpkgs.lib;
        evaluated = lib.evalModules {
          modules = [ flake.nixosModules.example flake.nixosModules.composed ];
        };
      in
      map (definition: definition.value) evaluated.config.meta.description
    " 2> "$work/alltypes-meta.log") || fail "all-types: a published module does not declare the meta options: $(tail -3 "$work/alltypes-meta.log")"
    echo "$metaStates" | grep -q 'Enables the example subsystem' || fail "all-types: the example module's own description is missing from a bare evaluation: $metaStates"
    echo "$metaStates" | grep -q 'Composed module importing' || fail "all-types: the composed module's own description is missing from a bare evaluation: $metaStates"
    echo "$metaStates" | grep -q 'Declares the module metadata options' && fail "all-types: the meta options module leaks its own description into a bare evaluation"
    pass "published modules carry the meta options into a bare evaluation of several modules"

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

    grep -q '^## wired$' modules/README.md || fail "all-types: modules/README.md does not document a module that defines a systemd unit"
    grep -A10 '^## wired$' modules/README.md | grep -q 'Runs a unit from the certificate list the NixOS module system provides\.' || fail "all-types: a module that defines a systemd unit is not documented with its own description"
    grep -q '#### wired\.certificates$' modules/README.md || fail "all-types: the option a module defaults from a NixOS option is not documented"
    grep -q 'security\.pki\.certificateFiles' modules/README.md || fail "all-types: the defaultText a module states for that option is not rendered"
    grep -q '#### systemd\.' modules/README.md && fail "all-types: the documentation lists NixOS options a module merely defines"
    grep -q '#### security\.' modules/README.md && fail "all-types: the documentation lists NixOS options a module merely reads"
    pass "a module that defines a systemd unit from a NixOS option is documented with its own options only"

    grep -q '^## hello$' packages/README.md || fail "all-types: packages/README.md documents no hello package"
    grep -q '\[packages/hello.nix\](hello.nix)' packages/README.md || fail "all-types: the package has no source link relative to packages/README.md"

    grep -q '^## double$' lib/README.md || fail "all-types: lib/README.md documents no double function"
    grep -q '^## answer$' lib/README.md || fail "all-types: lib/README.md documents no exported value"
    grep -A8 '^## answer$' lib/README.md | grep -q 'Int' || fail "all-types: the exported value is documented without the type its doc block states"
    grep -q '\[lib/default.nix:.*\](default.nix)' lib/README.md || fail "all-types: the exported value has no source link relative to lib/README.md"
    grep -q '^## types$' lib/README.md || fail "all-types: lib/README.md documents no exported namespace"
    grep -q '^### wrap$' lib/README.md || fail "all-types: the exported namespace documents none of its members"
    grep -q 'lib.types.wrap' lib/README.md || fail "all-types: the namespace member has no qualified usage line"
    grep -q '#### bla$' lib/README.md || fail "all-types: a declaration two namespaces deep is not documented"
    grep -q 'lib.types.strings.bla' lib/README.md || fail "all-types: a declaration two namespaces deep has no qualified usage line"
    grep -q '\[lib/default.nix:.*\](default.nix)' lib/README.md || fail "all-types: the function has no source link relative to lib/README.md"

    nix eval --json "path:$PWD#lib.double" --apply 'f: builtins.isFunction f' 2>/dev/null | grep -q true || fail "all-types: a documented function is published as a plain lambda, so builtins.isFunction holds"
    nix eval --json "path:$PWD#lib.double" --apply 'f: f { x = 3; }' 2>/dev/null | grep -q 6 || fail "all-types: the published function returns what the declaration it documents returns"
    nix eval --json "path:$PWD#lib.answer" 2>/dev/null | grep -q 42 || fail "all-types: a documented value is published as the value it declares, not as the declaration that documents it"
    nix eval --json "path:$PWD#lib" --apply 'l: l ? internal' 2>/dev/null | grep -q false || fail "all-types: the published library still exports the internal surface"
    nix eval --json "path:$PWD#lib.types.wrap" --apply 'f: builtins.isFunction f' 2>/dev/null | grep -q true || fail "all-types: a documented function nested in a published namespace is not built"
    nix eval --json "path:$PWD#lib.types.strings.bla" --apply 'f: builtins.isFunction f' 2>/dev/null | grep -q true || fail "all-types: a documented function two namespaces deep is not built"
    nix eval --json "path:$PWD#lib.types.strings.bla" --apply 'f: f { x = 7; }' 2>/dev/null | grep -q '"7"' || fail "all-types: the function two namespaces deep does not return what its declaration returns"
    if nix eval --json "path:$PWD#lib.double" --apply 'f: f { x = "no"; }' > /dev/null 2>&1; then fail "all-types: the published function accepts an argument its meta.args type rejects"; fi
    pass "a documented export is published as a checked function and a documented value as the value itself"

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
  meta-dedupe = suite "meta-dedupe" ''
    mkdir "$work/meta"
    cp -r "$repo/integration/fixtures/meta-dedupe/." "$work/meta/"
    cd "$work/meta"
    sed -i "s|url = \"github:synackdoche/flake\";|url = \"path:$repo\";|" flake.nix
    git init -q
    git add -A
    rm -f flake.lock
    nix flake lock > "$work/meta-lock.log" 2>&1 || fail "meta-dedupe: could not lock: $(tail -3 "$work/meta-lock.log")"

    states=$(nix eval --impure --json --expr "
      let
        flake = builtins.getFlake \"path:$PWD\";
        lib = flake.inputs.nixpkgs.lib;
        evaluated = lib.evalModules {
          modules = [ flake.nixosModules.a flake.nixosModules.b ];
        };
      in
      {
        declarations = builtins.length evaluated.options.meta.description.declarations;
        states = map (definition: definition.value) evaluated.config.meta.description;
      }
    " 2> "$work/meta-shared.log") || fail "meta-dedupe: two published modules did not share one declaration: $(tail -3 "$work/meta-shared.log")"
    echo "$states" | grep -q '"declarations":1' || fail "meta-dedupe: the meta options were declared more than once: $states"
    echo "$states" | grep -q 'Module A states its own description' || fail "meta-dedupe: module a's description is missing from the shared evaluation: $states"
    echo "$states" | grep -q 'Module B states its own description' || fail "meta-dedupe: module b's description is missing from the shared evaluation: $states"
    echo "$states" | grep -q 'Declares the module metadata options' && fail "meta-dedupe: the injected module leaked its own description into the shared evaluation: $states"
    pass "the injected module dedupes by file identity: two wrapped modules in one evaluation declare the meta options once"

    if nix eval --impure --expr "
      let
        flake = builtins.getFlake \"path:$PWD\";
        lib = flake.inputs.nixpkgs.lib;
        meta = { lib, ... }: lib.removeAttrs ((import (flake.inputs.synackdoche-flake.outPath + \"/modules/nixos/meta-options.nix\")) { inherit lib; }) [ \"meta\" ];
      in
      builtins.length
        (lib.evalModules {
          modules = [
            { imports = [ meta ./modules/nixos/a.nix ]; }
            { imports = [ meta ./modules/nixos/b.nix ]; }
          ];
        }).options.meta.description.declarations
    " > "$work/meta-inline.log" 2>&1; then
      fail "meta-dedupe: an inline function module injected twice did not collide"
    fi
    grep -q 'already declared' "$work/meta-inline.log" || fail "meta-dedupe: the inline collision did not report a duplicate declaration: $(tail -3 "$work/meta-inline.log")"
    pass "an inline function module injected twice collides, which is why the stripped copy is a file"
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
    sed -i "s|inherit inputs;|inherit inputs;\n      flakeInputs.ignore = [ \"synackdoche-flake\" ];|" flake.nix
    grep -q 'flakeInputs.ignore = \[ "synackdoche-flake" \]' flake.nix || fail "the pointed-at-this-flake client does not exempt its base input"
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
    clientFormatterDescription=$(nix eval --raw ".#formatter.$system.meta.description" 2>/dev/null) \
      || fail "the client flake's formatter states no description"
    echo "$clientFormatterDescription" | grep -q 'canonical configuration' \
      || fail "a client without formatter.nix does not format with this flake's canonical configuration: $clientFormatterDescription"
    pass "a client that states no formatter.nix formats with this flake's canonical configuration, not a second one"

    sed -i "s|      flakeInputs.ignore = \[ \"synackdoche-flake\" \];|      devShellConfig.shellHook = \"export DEVSHELL_PROBE=1\";\n      flakeInputs.ignore = [ \"synackdoche-flake\" ];|" flake.nix
    shellHook=$(nix eval --raw ".#devShells.$system.default.shellHook" 2>/dev/null) \
      || fail "the client's default devShell does not evaluate"
    echo "$shellHook" | grep -q 'DEVSHELL_PROBE=1' \
      || fail "a client's devShellConfig shellHook is not merged into its default devShell: $shellHook"
    echo "$shellHook" | grep -q 'git-hooks' \
      || fail "a client's devShellConfig replaced the pre-commit shell hook instead of merging with it: $shellHook"
    shellInputs=$(nix eval --json ".#devShells.$system.default.buildInputs" --apply 'ps: map (p: p.name) ps' 2>/dev/null) \
      || fail "the client's default devShell states no buildInputs"
    echo "$shellInputs" | grep -q 'treefmt' \
      || fail "a client's devShellConfig dropped the formatter's packages from the default devShell: $shellInputs"
    pass "a client's devShellConfig merges into the default devShell, keeping the pre-commit packages and hook"
    nix eval ".#devShells.$system.default" --apply 'd: d ? outPath' 2>/dev/null \
      || fail "the callable flake does not mix in the default devshell"
    checks=$(nix eval --json ".#checks.$system" --apply 'builtins.attrNames') \
      || fail "the callable flake produces no checks output in the client"
    for check in readme pre-commit documentation flake-inputs; do
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

    for check in documentation readme pre-commit flake-inputs; do
      nix build --no-link ".#checks.$system.$check" > "$work/$check.log" 2>&1 \
        || fail "the instantiated template fails its $check check: $(tail -3 "$work/$check.log")"
    done
    pass "the instantiated template passes its documentation, readme, pre-commit and flake-inputs checks"

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
