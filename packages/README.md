# Packages

SYNACKDOCHE GAMES - Base Flake — packages

## docs

```sh
nix run .#docs
```

*Type:* derivation

Writes the generated documentation into the working tree, or checks that it is current and staged.

*Source:* [packages/docs.nix](docs.nix)

## formatter

```sh
nix fmt
```

*Type:* derivation

treefmt wrapper running deadnix, flake-edit, pedantix and statix with the canonical configuration.

