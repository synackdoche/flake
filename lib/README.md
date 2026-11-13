# flake (library)

Library functions of flake, separated into those that are part of the public surface and those that are not.

## descriptionsProblems

```nix
lib.internal.descriptionsProblems { allowComponents ? …, components, options }
```

*Type:* function

*Arguments:*

- `allowComponents`: component names that may be mentioned without being reported
- `components`: names of the components this flake is built from, whose mention is reported
- `options`: evaluated option set whose descriptions are inspected

Reports descriptions that are missing, too short to state a contract, repeated, or that name another component of the flake.

## devShell

```nix
lib.internal.devShell { pkgs, preCommit }
```

*Type:* function

*Arguments:*

- `pkgs`: nixpkgs package set the shell is built with
- `preCommit`: pre-commit check whose packages and hook the shell exposes

Shell environment carrying the formatter's packages and its shell hook.

## docsApp

```nix
lib.internal.docsApp { pkgs }
```

*Type:* function

*Arguments:*

- `pkgs`: nixpkgs package set the wrapper script runs with; the flake it documents is read from the working directory

Writes one generated README into the working tree, for the repository or for one named module.

## docsTree

```nix
lib.internal.docsTree { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, modules ? …, name, packages ? …, pkgs, root, system }
```

*Type:* function

*Arguments:*

- `apps`: attrset of apps to document, empty when the flake exports none
- `checks`: attrset of checks to document, empty when the flake exports none
- `configurations`: attrset of NixOS configurations to document
- `description`: sentence saying what this flake is for
- `formatter`: the derivation exposed as the flake formatter for this system
- `internalLibrary`: attrset of functions documented only in lib/README.md
- `library`: attrset of functions to document in the index
- `modules`: attrset of NixOS modules to document
- `name`: repository name, used as the document title
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to render option documentation
- `root`: path to the repository root, used to locate module files
- `system`: system string selecting the packages, apps and checks to document

## documentApp

```nix
lib.internal.documentApp { app, name }
```

*Type:* function

*Arguments:*

- `app`: the app record being documented
- `name`: attribute name of the app

Documents one app: how to run it and what its meta.description says.

## documentCheck

```nix
lib.internal.documentCheck { check, name, system }
```

*Type:* function

*Arguments:*

- `check`: the check derivation being documented
- `name`: attribute name of the check
- `system`: system string selecting the check set

Documents one check: how to build it and the assertions it makes.

## documentConfiguration

```nix
lib.internal.documentConfiguration { configuration, name }
```

*Type:* function

*Arguments:*

- `configuration`: the evaluated configuration being documented
- `name`: attribute name of the configuration

Documents one NixOS configuration: how to build it, its host name and its system.

## documentFunction

```nix
lib.internal.documentFunction { fn, name, namespace ? … }
```

*Type:* function

*Arguments:*

- `fn`: the function being documented
- `name`: attribute name of the function, used to find its doc block
- `namespace`: attribute path the function is reachable from, so the usage snippet can be called as written

Documents one library function: its call shape, the types from the doc block above it, and the doc block's summary.

## documentPackage

```nix
lib.internal.documentPackage { checks ? …, formatter ? …, name, package }
```

*Type:* function

*Arguments:*

- `checks`: names of the checks this document links to, so passthru.tests entries become links
- `formatter`: the flake's formatter for this system, so it is documented as `nix fmt` instead of a build
- `name`: attribute name of the package
- `package`: the derivation being documented

Documents one package: how to run it when it has a mainProgram, how to build it otherwise, what its meta.description says, and which checks it is tested by.

## documentation

```nix
lib.internal.documentation { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, modules ? …, name, packages ? …, pkgs, root, system }
```

*Type:* function

*Arguments:*

- `apps`: attrset of apps to document, empty when the flake exports none
- `checks`: attrset of checks to document, empty when the flake exports none
- `configurations`: attrset of NixOS configurations to document
- `description`: sentence saying what this flake is for
- `formatter`: the derivation exposed as the flake formatter for this system
- `internalLibrary`: attrset of functions documented only in lib/README.md
- `library`: attrset of functions to document in the index
- `modules`: attrset of NixOS modules to document
- `name`: repository name, used as the document title
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to render option documentation
- `root`: path to the repository root, used to locate module files
- `system`: system string selecting the packages, apps and checks to document

Renders the section list and the per-module documents that the documentation tree is built from.

## documentationProblems

```nix
lib.internal.documentationProblems { description, name, sections }
```

*Type:* function

*Arguments:*

- `description`: sentence stating what the flake is for
- `name`: repository name, which the description must not merely repeat
- `sections`: the rendered sections that are inspected

Reports every way a rendered document falls short of being usable: purpose unstated, usage missing, arguments untyped.

## messageProblems

```nix
lib.internal.messageProblems { assertions, options }
```

*Type:* function

*Arguments:*

- `assertions`: list of { assertion, message } records whose messages are inspected
- `options`: evaluated option set the message paths are resolved against

Reports assertion messages that do not name a declared option, or that omit the expected value and the fix.

## mkAssertion

```nix
lib.internal.mkAssertion { at, condition, expected, fix, violation }
```

*Type:* function

*Arguments:*

- `at`: list of attribute names naming the option the assertion is about
- `condition`: the property being asserted, true when it holds
- `expected`: sentence saying what the configuration should look like instead
- `fix`: sentence saying how to make it look that way
- `violation`: sentence saying what is wrong when the condition is false

Builds an assertion record whose message states the violation, what was expected and how to fix it.

## mkSection

```nix
lib.internal.mkSection { body ? …, sections ? …, title }
```

*Type:* function

*Arguments:*

- `body`: markdown emitted under the title instead of child headings, null when there is none
- `sections`: child sections, rendered one heading level deeper, empty when the group only holds prose
- `title`: heading text of the group

Groups child sections under one title, for a part of the document that is itself not a usable thing.

## preCommit

```nix
lib.internal.preCommit { pkgs, src }
```

*Type:* function

*Arguments:*

- `pkgs`: nixpkgs package set the hooks are taken from
- `src`: the tree the hooks are run against

Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.

## readmeGate

```nix
lib.internal.readmeGate { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, modules ? …, name, packages ? …, pkgs, root, system }
```

*Type:* function

*Arguments:*

- `apps`: attrset of apps to document, empty when the flake exports none
- `checks`: attrset of checks to document, empty when the flake exports none
- `configurations`: attrset of NixOS configurations to document
- `description`: sentence saying what this flake is for
- `formatter`: the derivation exposed as the flake formatter for this system
- `internalLibrary`: attrset of functions documented only in lib/README.md
- `library`: attrset of functions to document in the index
- `modules`: attrset of NixOS modules to document
- `name`: repository name, used as the document title
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to render and compare the documents
- `root`: path to the repository root holding the committed READMEs
- `system`: system string selecting the documented outputs

Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

## section

```nix
lib.internal.section { arguments ? …, body ? …, bodyFile ? …, description ? …, documented ? …, language ? …, sections ? …, tests ? …, title, type ? …, usage }
```

*Type:* function

*Arguments:*

- `arguments`: list of { argument, argumentType } describing the call shape
- `body`: markdown emitted under the title, null when there is none
- `bodyFile`: path to a rendered markdown fragment appended after the description
- `description`: sentence saying what the thing is for, empty when the title says it
- `documented`: whether authored prose exists for the thing, false when it is undocumented
- `language`: code fence language of the usage snippet, for example nix or sh
- `sections`: child sections, rendered one heading level deeper
- `tests`: list of { test, documented } naming the checks the thing is tested by
- `title`: heading text naming the thing
- `type`: what the thing is, for example derivation, app or NixOS module
- `usage`: snippet that uses the thing, shown in a fenced block

One documented thing: what it is, how to call or import it, what its arguments are and any child sections.

## testsLine

```nix
lib.internal.testsLine { tests }
```

*Type:* function

*Arguments:*

- `tests`: list of { test, documented } records naming the checks a package is tested by

Renders the test links of a section: a markdown link when the check is documented, plain text when it is not.

## writeDocumentation

```nix
lib.internal.writeDocumentation { description, name, pkgs, sections }
```

*Type:* function

*Arguments:*

- `description`: sentence under the title saying what the documented thing is for
- `name`: document title
- `pkgs`: nixpkgs package set the derivation is built with
- `sections`: sections to render, each with its own heading

Renders a list of sections into a README derivation.

