# Packages

SYNACKDOCHE base flake — shared formatter, pre-commit, docgate checks and flake scaffolding — packages

## docs

```sh
nix run .#docs
```

*Type:* derivation

Writes the generated documentation into the working tree, or checks that it is current and staged.

## formatter

```sh
nix fmt
```

*Type:* derivation

treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.

