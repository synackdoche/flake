# Checks

SYNACKDOCHE GAMES - Base Flake — checks

## assertions

```sh
nix build .#checks.x86_64-linux.assertions
```

*Type:* derivation

Checks that an assertion keeps its condition and states the violation, the expectation and the fix.

*Source:* [checks/assertions.nix](assertions.nix)

## descriptions

```sh
nix build .#checks.x86_64-linux.descriptions
```

*Type:* derivation

Checks that option descriptions are present, long enough to state a contract, unique, and free of other components of this flake.

*Source:* [checks/descriptions.nix](descriptions.nix)

## docs-introspection

```sh
nix build .#checks.x86_64-linux.docs-introspection
```

*Type:* derivation

Checks that the generated documentation is complete and usable, and that incomplete documentation is reported.

*Source:* [checks/docs-introspection.nix](docs-introspection.nix)

## formatter-config

```sh
nix build .#checks.x86_64-linux.formatter-config
```

*Type:* derivation

Checks that an evalModule-shaped formatterConfig is merged into the canonical formatter and that the pre-commit hook runs the resulting formatter.

*Source:* [checks/formatter-config.nix](formatter-config.nix)

## messages

```sh
nix build .#checks.x86_64-linux.messages
```

*Type:* derivation

Checks that an assertion message names a declared option and states both the expectation and the fix.

*Source:* [checks/messages.nix](messages.nix)

## pre-commit

```sh
nix build .#checks.x86_64-linux.pre-commit
```

*Type:* derivation

Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.

*Source:* [checks/pre-commit.nix](pre-commit.nix)

## readme

```sh
nix build .#checks.x86_64-linux.readme
```

*Type:* derivation

Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

*Source:* [checks/readme.nix](readme.nix)

