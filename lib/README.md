# Library

SYNACKDOCHE GAMES - Base Flake — library

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

*Source:* [lib/default.nix:230](lib/default.nix)

## devShell

```nix
lib.internal.devShell { pkgs, preCommit }
```

*Type:* function

*Arguments:*

- `pkgs`: nixpkgs package set the shell is built with
- `preCommit`: pre-commit check whose packages and hook the shell exposes

Shell environment carrying the formatter's packages and its shell hook.

*Source:* [lib/default.nix:287](lib/default.nix)

## docsApp

```nix
lib.internal.docsApp { pkgs }
```

*Type:* function

*Arguments:*

- `pkgs`: nixpkgs package set the wrapper script runs with; the flake it documents is read from the working directory

Writes one generated README into the working tree, for the repository or for one named module.

*Source:* [lib/default.nix:299](lib/default.nix)

## docsGate

```nix
lib.internal.docsGate { checks ? …, flake, librarySource ? …, pkgs, root ? … }
```

*Type:* function

*Arguments:*

- `checks`: checks to document, none by default, because a check cannot enumerate the checks without forcing itself
- `flake`: the flake whose documentation is inspected
- `librarySource`: directory holding the library sources whose doc blocks are read, `<root>/lib` by default
- `pkgs`: nixpkgs package set for the system being documented
- `root`: source tree the documentation describes, the store copy of the flake by default

Fails evaluation when the documentation of a flake is incomplete, so a repository can make its documentation a check instead of a convention.

*Source:* [lib/default.nix:385](lib/default.nix)

## docsTree

```nix
lib.internal.docsTree { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, librarySource ? …, modules ? …, packages ? …, pkgs, root, system, templates ? …, url ? … }
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
- `librarySource`: directory holding the library sources whose doc blocks are read
- `modules`: attrset of NixOS modules to document
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to render option documentation
- `root`: path to the repository root, used to locate module files
- `system`: system string selecting the packages, apps and checks to document
- `templates`: attrset of templates to document
- `url`: flake reference the templates are published under, empty when the flake states none

*Source:* [lib/default.nix:438](lib/default.nix)

## documentApp

```nix
lib.internal.documentApp { app, name }
```

*Type:* function

*Arguments:*

- `app`: the app record being documented
- `name`: attribute name of the app

Documents one app: how to run it and what its meta.description says.

*Source:* [lib/default.nix:495](lib/default.nix)

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

*Source:* [lib/default.nix:512](lib/default.nix)

## documentConfiguration

```nix
lib.internal.documentConfiguration { configuration, name }
```

*Type:* function

*Arguments:*

- `configuration`: the evaluated configuration being documented
- `name`: attribute name of the configuration

Documents one NixOS configuration: how to build it, its host name and its system.

*Source:* [lib/default.nix:532](lib/default.nix)

## documentFunction

```nix
lib.internal.documentFunction { fn, internal ? …, name, namespace ? …, source ? … }
```

*Type:* function

*Arguments:*

- `fn`: the function being documented
- `internal`: whether the function is outside the public surface, whose documentation may be omitted
- `name`: attribute name of the function, used to find its doc block
- `namespace`: attribute path the function is reachable from, `lib` by default
- `source`: directory holding the library sources whose doc blocks are read, the flake library by default

Documents one function: how to call it, what it is for, and what each argument is.

*Source:* [lib/default.nix:553](lib/default.nix)

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

*Source:* [lib/default.nix:599](lib/default.nix)

## documentTemplate

```nix
lib.internal.documentTemplate { name, template, url ? … }
```

*Type:* function

*Arguments:*

- `name`: attribute name of the function, used to find its doc block
- `template`: the template record, carrying the description its flake states
- `url`: flake reference the templates are published under, `.` when the flake states none

Documents one library function: its call shape, the types from the doc block above it, and the doc block's summary.

*Source:* [lib/default.nix:637](lib/default.nix)

## documentation

```nix
lib.internal.documentation { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, librarySource ? …, modules ? …, packages ? …, pkgs, root, system, templates ? …, url ? … }
```

*Type:* function

*Arguments:*

- `apps`: attrset of apps to document
- `checks`: attrset of checks to document
- `configurations`: attrset of NixOS configurations to document
- `description`: statement of what the flake is for, shown at the top of every document
- `formatter`: derivation exposed as the flake formatter, documented as `nix fmt`
- `internalLibrary`: attrset of functions documented as part of the internal surface
- `library`: attrset of functions documented as part of the public surface
- `librarySource`: directory holding the library sources whose doc blocks are read
- `modules`: attrset of NixOS modules to document
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to build the documents
- `root`: source tree the documents describe, read for module options
- `system`: system the documented outputs belong to
- `templates`: attrset of templates to document
- `url`: flake reference the templates are published under, empty when the flake states none

Builds the documentation of a flake: one document per group of outputs, the modules, and the root index that links them.

*Source:* [lib/default.nix:672](lib/default.nix)

## documentationProblems

```nix
lib.internal.documentationProblems { description, sections }
```

*Type:* function

*Arguments:*

- `description`: sentence stating what the flake is for
- `sections`: the rendered sections that are inspected

Reports every way a rendered document falls short of being usable: purpose unstated, usage missing, arguments untyped.

*Source:* [lib/default.nix:947](lib/default.nix)

## flakeArgs

```nix
lib.internal.flakeArgs { checks ? …, description ? …, flake, librarySource ? …, pkgs, root ? … }
```

*Type:* function

*Arguments:*

- `checks`: checks to document, every check of the flake by default; pass an empty set from a check, which cannot enumerate the checks without forcing itself
- `description`: statement of what the flake is for, the multiline description in flake.nix by default
- `flake`: the flake whose outputs are documented
- `librarySource`: directory holding the library sources whose doc blocks are read, `<flake>/lib` by default
- `pkgs`: nixpkgs package set for the system being documented
- `root`: source tree the documentation describes, the store copy of the flake by default

Derives the arguments that document a flake, from the flake itself, so a repository states nothing about its own documentation.

*Source:* [lib/default.nix:1035](lib/default.nix)

## flakeDescription

```nix
lib.internal.flakeDescription { root }
```

*Type:* function

*Arguments:*

- `root`: source tree containing flake.nix

Reads the description a flake states about itself, which is the only statement of what the flake is for.

*Source:* [lib/default.nix:1070](lib/default.nix)

## messageProblems

```nix
lib.internal.messageProblems { assertions, options }
```

*Type:* function

*Arguments:*

- `assertions`: list of { assertion, message } records whose messages are inspected
- `options`: evaluated option set the message paths are resolved against

Reports assertion messages that do not name a declared option, or that omit the expected value and the fix.

*Source:* [lib/default.nix:1128](lib/default.nix)

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

*Source:* [lib/default.nix:1163](lib/default.nix)

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

*Source:* [lib/default.nix:1187](lib/default.nix)

## preCommit

```nix
lib.internal.preCommit { extraHooks ? …, pkgs, src }
```

*Type:* function

*Arguments:*

- `extraHooks`: additional git-hooks definitions merged into the hook set
- `pkgs`: nixpkgs package set the hooks are taken from
- `src`: the tree the hooks are run against

Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.

*Source:* [lib/default.nix:1214](lib/default.nix)

## readmeGate

```nix
lib.internal.readmeGate { apps ? …, checks ? …, configurations ? …, description, formatter ? …, internalLibrary ? …, library ? …, librarySource ? …, modules ? …, packages ? …, pkgs, root, system, templates ? …, url ? … }
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
- `librarySource`: directory holding the library sources whose doc blocks are read
- `modules`: attrset of NixOS modules to document
- `packages`: attrset of packages to document
- `pkgs`: nixpkgs package set used to render and compare the documents
- `root`: path to the repository root holding the committed READMEs
- `system`: system string selecting the documented outputs
- `templates`: attrset of templates to document
- `url`: flake reference the templates are published under, empty when the flake states none

Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

*Source:* [lib/default.nix:1277](lib/default.nix)

## renderSection

```nix
lib.internal.renderSection { depth, s }
```

*Type:* function

*Arguments:*

- `depth`: heading level of the section, 2 for a top-level section of a document
- `s`: the section to render

Renders a list of sections into a README derivation.

*Source:* [lib/default.nix:1404](lib/default.nix)

## section

```nix
lib.internal.section { arguments ? …, body ? …, bodyFile ? …, description ? …, documented ? …, hashCommented ? …, internal ? …, language ? …, sections ? …, source ? …, tests ? …, title, type ? …, usage }
```

*Type:* function

*Arguments:*

- `arguments`: list of { argument, argumentType } describing the call shape
- `body`: markdown emitted under the title, null when there is none
- `bodyFile`: path to a rendered markdown fragment appended after the description
- `description`: sentence saying what the thing is for, empty when the title says it
- `documented`: whether authored prose exists for the thing, false when it is undocumented
- `hashCommented`: undocumented type
- `internal`: undocumented type
- `language`: code fence language of the usage snippet, for example nix or sh
- `sections`: child sections, rendered one heading level deeper
- `source`: { file, line } naming where the thing is defined in this repository, null when the location is unknown
- `tests`: list of { test, documented } naming the checks the thing is tested by
- `title`: heading text naming the thing
- `type`: what the thing is, for example derivation, app or NixOS module
- `usage`: snippet that uses the thing, shown in a fenced block

One documented thing: what it is, how to call or import it, what its arguments are and any child sections.

*Source:* [lib/default.nix:1472](lib/default.nix)

## testsLine

```nix
lib.internal.testsLine { tests }
```

*Type:* function

*Arguments:*

- `tests`: list of { test, documented } records naming the checks a package is tested by

Renders the test links of a section: a markdown link when the check is documented, plain text when it is not.

*Source:* [lib/default.nix:1513](lib/default.nix)

## writeDocumentation

```nix
lib.internal.writeDocumentation { description, name ? …, pkgs, sections }
```

*Type:* function

*Arguments:*

- `description`: statement of what the flake is for, printed under the title; when name is empty its first line titles the document and the rest of it is printed under that title
- `name`: title of the document, the first line of the description when it is empty
- `pkgs`: nixpkgs package set the document derivation is built with
- `sections`: sections to render, in order

Writes one document: a heading, the statement of purpose, and the sections rendered in order.

*Source:* [lib/default.nix:1524](lib/default.nix)

