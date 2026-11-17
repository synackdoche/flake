# SYNACKDOCHE GAMES - Base Flake

shared formatter, pre-commit, docgate checks and flake scaffolding

## Templates

- [minimal](templates/README.md#minimal) — Minimal repository — the smallest flake that uses the SYNACKDOCHE base flake

## Modules

- [meta-options](modules/README.md#meta-options) — Declares the module metadata options the documentation pipeline reads, so a module states its summary and its worked example without declaring options itself.

## Packages

- [docs](packages/README.md#docs) — Writes the generated documentation into the working tree, or checks that it is current and staged.
- [formatter](packages/README.md#formatter) — treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.

## Checks

- [assertions](checks/README.md#assertions) — Checks that an assertion keeps its condition and states the violation, the expectation and the fix.
- [descriptions](checks/README.md#descriptions) — Checks that option descriptions are present, long enough to state a contract, unique, and free of other components of this flake.
- [dev-shell-config](checks/README.md#dev-shell-config) — Checks that an evalModule-shaped devShellConfig is merged into the default development shell and that its packages and shell hook survive.
- [docs-introspection](checks/README.md#docs-introspection) — Checks that the generated documentation is complete and usable, and that incomplete documentation is reported.
- [flake-inputs](checks/README.md#flake-inputs) — Fails a flake whose flake.lock pins a path input that resolves outside the repository.
- [formatter-config](checks/README.md#formatter-config) — Checks that an evalModule-shaped formatterConfig is merged into the canonical formatter and that the pre-commit hook runs the resulting formatter.
- [messages](checks/README.md#messages) — Checks that an assertion message names a declared option and states both the expectation and the fix.
- [pre-commit](checks/README.md#pre-commit) — Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.
- [readme](checks/README.md#readme) — Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

