# SYNACKDOCHE base flake — shared formatter, pre-commit, docgate checks and flake scaffolding

## Templates

- [minimal](templates/README.md#minimal) — Minimal repository — the smallest flake that uses the SYNACKDOCHE base flake

## Packages

- [docs](packages/README.md#docs) — Writes the generated documentation into the working tree, or checks that it is current and staged.
- [formatter](packages/README.md#formatter) — treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.

## Library

- [devShell](lib/README.md#devshell) — Shell environment carrying the formatter's packages and its shell hook.
- [docsGate](lib/README.md#docsgate) — Fails evaluation when the documentation of a flake is incomplete, so a repository can make its documentation a check instead of a convention.
- [flakeArgs](lib/README.md#flakeargs) — Derives the arguments that document a flake, from the flake itself, so a repository states nothing about its own documentation.
- [preCommit](lib/README.md#precommit) — Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.
- [readmeGate](lib/README.md#readmegate) — Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

## Checks

- [assertions](checks/README.md#assertions) — Checks that an assertion keeps its condition and states the violation, the expectation and the fix.
- [descriptions](checks/README.md#descriptions) — Checks that option descriptions are present, long enough to state a contract, unique, and free of other components of this flake.
- [docs-introspection](checks/README.md#docs-introspection) — Checks that the generated documentation is complete and usable, and that incomplete documentation is reported.
- [messages](checks/README.md#messages) — Checks that an assertion message names a declared option and states both the expectation and the fix.
- [pre-commit](checks/README.md#pre-commit) — Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.
- [readme](checks/README.md#readme) — Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

