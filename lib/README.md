# Library

SYNACKDOCHE GAMES - Base Flake — library

## buildDocumented

### function

```nix
lib.internal.buildDocumented.function { name, value }
```

*Type:* function

*Arguments:*

- `name` (`*string*`): attribute name the function is exported under, used in the type error it raises
- `value` (`*attribute set*`): declaration carrying meta.args and __functor, the source of the rendered arguments

Builds a real curried function from a documented declaration, so consumers get a plain lambda instead of a functor attribute set and every argument is checked against the type its meta.args entry states.

*Source:* [lib/default.nix:241](default.nix)

### functions

```nix
lib.internal.buildDocumented.functions { surface }
```

*Type:* function

*Arguments:*

- `surface` (`*attribute set*`): attribute set of library exports to build, usually the flake's lib output

Builds every documented declaration in a surface into a real function, and recurses into a namespace of declarations to any depth, leaving exports that declare no meta and hold no declarations untouched.

*Source:* [lib/default.nix:257](default.nix)

### namespace

```nix
lib.internal.buildDocumented.namespace { value }
```

*Type:* function

*Arguments:*

- `value` (`*attribute set*`): an attribute set that may be a namespace of documented declarations

Reports whether an attribute set is a namespace of declarations: at least one member, at any depth, is a declaration carrying meta or __functor.

*Source:* [lib/default.nix:267](default.nix)

## descriptions

### problems

```nix
lib.internal.descriptions.problems { allowComponents, components, options }
```

*Type:* function

*Arguments:*

- `allowComponents` (`*list of string*`): component names that may be mentioned without being reported
- `components` (`*list of string*`): names of the components this flake is built from, whose mention is reported
- `options` (`*attribute set*`): evaluated option set whose descriptions are inspected

Reports descriptions that are missing, too short to state a contract, repeated, or that name another component of the flake.

*Source:* [lib/default.nix:332](default.nix)

## dev

### preCommit

```nix
lib.internal.dev.preCommit { docs, extraHooks, formatter, pkgs, src }
```

*Type:* function

*Arguments:*

- `docs` (`*package*`): the docs app the docs hook runs to check that the documentation is current and staged
- `extraHooks` (`*attribute set*`): additional git-hooks definitions merged into the hook set
- `formatter` (`*package*`): the derivation the treefmt hook runs, so the hook formats with this flake's formatter
- `pkgs` (`*attribute set*`): nixpkgs package set the hooks are taken from
- `src` (`*absolute path*`): the tree the hooks are run against

Runs treefmt through this flake's formatter, plus deadnix, statix and pedantix.

*Source:* [lib/default.nix:401](default.nix)

## docs

### app

```nix
lib.internal.docs.app { pkgs }
```

*Type:* function

*Arguments:*

- `pkgs` (`*attribute set*`): nixpkgs package set the wrapper script runs with; the flake it documents is read from the working directory

Writes one generated README into the working tree, for the repository or for one named module.

*Source:* [lib/default.nix:561](default.nix)

### tree

```nix
lib.internal.docs.tree { apps, checks, configurations, description, flake, formatter, internalLibrary, library, modules, packages, pkgs, requireInternalDocumentation, root, system, templates, url }
```

*Type:* function

*Arguments:*

- `apps` (`*attribute set*`): attrset of apps to document, empty when the flake exports none
- `checks` (`*attribute set*`): attrset of checks to document, empty when the flake exports none
- `configurations` (`*attribute set*`): attrset of NixOS configurations to document
- `description` (`*string*`): sentence saying what this flake is for
- `flake` (`*null or (attribute set)*`): the flake whose modules are documented, supplying the module arguments a blueprint system provides
- `formatter` (`*null or package*`): the derivation exposed as the flake formatter for this system
- `internalLibrary` (`*attribute set*`): attrset of functions documented only in lib/README.md
- `library` (`*attribute set*`): attrset of functions to document in the index
- `modules` (`*attribute set*`): attrset of NixOS modules to document
- `packages` (`*attribute set*`): attrset of packages to document
- `pkgs` (`*attribute set*`): nixpkgs package set used to render option documentation
- `requireInternalDocumentation` (`*boolean*`): whether an internal export must state meta.description too, false when the internal surface may stay opaque
- `root` (`*absolute path*`): path to the repository root, used to locate module files
- `system` (`*string*`): system string selecting the packages, apps and checks to document
- `templates` (`*attribute set*`): attrset of templates to document
- `url` (`*string*`): flake reference the templates are published under, empty when the flake states none

Builds the documentation tree: the repository README plus one README per output kind, ready to install.

*Source:* [lib/default.nix:571](default.nix)

## document

### app

```nix
lib.internal.document.app { app, name }
```

*Type:* function

*Arguments:*

- `app` (`*attribute set*`): the app record being documented
- `name` (`*string*`): attribute name of the app

Documents one app: how to run it and what its meta.description says.

*Source:* [lib/default.nix:802](default.nix)

### check

```nix
lib.internal.document.check { check, name, system }
```

*Type:* function

*Arguments:*

- `check` (`*package*`): the check derivation being documented
- `name` (`*string*`): attribute name of the check
- `system` (`*string*`): system string selecting the check set

Documents one check: how to build it and the assertions it makes.

*Source:* [lib/default.nix:818](default.nix)

### configuration

```nix
lib.internal.document.configuration { configuration, name, source }
```

*Type:* function

*Arguments:*

- `configuration` (`*attribute set*`): the evaluated configuration being documented
- `name` (`*string*`): attribute name of the configuration
- `source` (`*null or string*`): path of the configuration file whose `meta.description` is read, null when the location is unknown

Documents one NixOS configuration: how to build it, the description the host states for itself and its host name and system.

*Source:* [lib/default.nix:838](default.nix)

### function

```nix
lib.internal.document.function { fn, internal, name, namespace, position, sections }
```

*Type:* function

*Arguments:*

- `fn` (`*anything*`): the declaration being documented, carrying meta.description and, when callable, meta.args
- `internal` (`*boolean*`): whether the function is outside the public surface, whose documentation may be omitted
- `name` (`*string*`): attribute name of the function, used to find its doc block
- `namespace` (`*string*`): attribute path the function is reachable from, `lib` by default
- `position` (`*null or (attribute set)*`): { file, line, path } where the function is bound, null when it is not bound in a source file
- `sections` (`*list of (attribute set)*`): child sections already rendered for the function, such as the options of an exported type

Documents one exported function from the metadata it declares: how to call it, what it is for and what each argument is.

*Source:* [lib/default.nix:858](default.nix)

### package

```nix
lib.internal.document.package { checks, formatter, name, package }
```

*Type:* function

*Arguments:*

- `checks` (`*list of string*`): names of the checks this document links to, so passthru.tests entries become links
- `formatter` (`*null or package*`): the flake's formatter for this system, so it is documented as `nix fmt` instead of a build
- `name` (`*string*`): attribute name of the package
- `package` (`*package*`): the derivation being documented

Documents one package: how to run it when it has a mainProgram, how to build it otherwise, what its meta.description says, and which checks it is tested by.

*Source:* [lib/default.nix:890](default.nix)

### template

```nix
lib.internal.document.template { name, template, url }
```

*Type:* function

*Arguments:*

- `name` (`*string*`): attribute name of the function, used to find its doc block
- `template` (`*attribute set*`): the template record, carrying the description its flake states
- `url` (`*string*`): flake reference the templates are published under, `.` when the flake states none

Documents one template: how to initialise a flake from it and the description its flake states.

*Source:* [lib/default.nix:914](default.nix)

### value

```nix
lib.internal.document.value { internal, name, namespace, position, sections, value }
```

*Type:* function

*Arguments:*

- `internal` (`*boolean*`): whether the value is part of the internal surface
- `name` (`*string*`): attribute name of the value
- `namespace` (`*string*`): how the value is reached from the flake's library
- `position` (`*null or (attribute set)*`): { file, line, path } where the value is bound, null when it is not bound in a source file
- `sections` (`*list of (attribute set)*`): child sections already rendered for the value, such as the options of an exported type
- `value` (`*anything*`): the export being documented, carrying meta.description and meta.type

Documents one exported value from the metadata it declares: what it is, the type label it states and where it is defined.

*Source:* [lib/default.nix:934](default.nix)

## documentation

### build

```nix
lib.internal.documentation.build { apps, checks, configurations, description, flake, formatter, internalLibrary, library, modules, packages, pkgs, requireInternalDocumentation, root, system, templates, url }
```

*Type:* function

*Arguments:*

- `apps` (`*attribute set*`): attrset of apps to document
- `checks` (`*attribute set*`): attrset of checks to document
- `configurations` (`*attribute set*`): attrset of NixOS configurations to document
- `description` (`*string*`): statement of what the flake is for, shown at the top of every document
- `flake` (`*null or (attribute set)*`): the flake whose modules are documented, supplying the module arguments a blueprint system provides
- `formatter` (`*null or package*`): derivation exposed as the flake formatter, documented as `nix fmt`
- `internalLibrary` (`*attribute set*`): attrset of functions documented as part of the internal surface
- `library` (`*attribute set*`): attrset of functions documented as part of the public surface
- `modules` (`*attribute set*`): attrset of NixOS modules to document
- `packages` (`*attribute set*`): attrset of packages to document
- `pkgs` (`*attribute set*`): nixpkgs package set used to build the documents
- `requireInternalDocumentation` (`*boolean*`): whether an internal export must state meta.description too, false when the internal surface may stay opaque
- `root` (`*absolute path*`): source tree the documents describe, read for module options
- `system` (`*string*`): system the documented outputs belong to
- `templates` (`*attribute set*`): attrset of templates to document
- `url` (`*string*`): flake reference the templates are published under, empty when the flake states none

Builds the documentation of a flake: one document per group of outputs, the modules, and the root index that links them.

*Source:* [lib/default.nix:1494](default.nix)

### problems

```nix
lib.internal.documentation.problems { description, requireInternalDocumentation, sections }
```

*Type:* function

*Arguments:*

- `description` (`*string*`): sentence stating what the flake is for
- `requireInternalDocumentation` (`*boolean*`): whether an internal export must state meta.description too, false when the internal surface may stay opaque
- `sections` (`*list of (attribute set)*`): the rendered sections that are inspected

Reports every way a rendered document falls short of being usable: purpose unstated, usage missing, arguments untyped.

*Source:* [lib/default.nix:1566](default.nix)

## flake

### args

```nix
lib.internal.flake.args { checks, description, flake, pkgs, root }
```

*Type:* function

*Arguments:*

- `checks` (`*null or (attribute set)*`): checks to document, every check of the flake by default; pass an empty set from a check, which cannot enumerate the checks without forcing itself
- `description` (`*string*`): statement of what the flake is for, the multiline description in flake.nix by default
- `flake` (`*attribute set*`): the flake whose outputs are documented
- `pkgs` (`*attribute set*`): nixpkgs package set for the system being documented
- `root` (`*absolute path*`): source tree the documentation describes, the store copy of the flake by default

Derives the arguments that document a flake, from the flake itself, so a repository states nothing about its own documentation.

*Source:* [lib/default.nix:1671](default.nix)

### description

```nix
lib.internal.flake.description { root }
```

*Type:* function

*Arguments:*

- `root` (`*absolute path*`): source tree containing flake.nix

Reads the description a flake states about itself, which is the only statement of what the flake is for.

*Source:* [lib/default.nix:1699](default.nix)

## gate

### docs

```nix
lib.internal.gate.docs { checks, flake, pkgs, root }
```

*Type:* function

*Arguments:*

- `checks` (`*attribute set*`): checks to document, none by default, because a check cannot enumerate the checks without forcing itself
- `flake` (`*attribute set*`): the flake whose documentation is inspected
- `pkgs` (`*attribute set*`): nixpkgs package set for the system being documented
- `root` (`*absolute path*`): source tree the documentation describes, the store copy of the flake by default

Fails evaluation when the documentation of a flake is incomplete, so a repository can make its documentation a check instead of a convention.

*Source:* [lib/default.nix:1936](default.nix)

### flakeInputs

```nix
lib.internal.gate.flakeInputs { ignore, pkgs, root }
```

*Type:* function

*Arguments:*

- `ignore` (`*list of string*`): input names exempted from the check, for inputs that are intentionally the local working copy of another repository
- `pkgs` (`*attribute set*`): nixpkgs package set for the system the check is built on
- `root` (`*absolute path*`): repository root whose flake.lock is inspected

Fails a flake whose flake.lock pins a path input that resolves outside the repository, because such a flake builds only where that path exists.

*Source:* [lib/default.nix:1960](default.nix)

### readme

```nix
lib.internal.gate.readme { apps, checks, configurations, description, flake, formatter, internalLibrary, library, modules, packages, pkgs, requireInternalDocumentation, root, system, templates, url }
```

*Type:* function

*Arguments:*

- `apps` (`*attribute set*`): attrset of apps to document, empty when the flake exports none
- `checks` (`*attribute set*`): attrset of checks to document, empty when the flake exports none
- `configurations` (`*attribute set*`): attrset of NixOS configurations to document
- `description` (`*string*`): sentence saying what this flake is for
- `flake` (`*null or (attribute set)*`): the flake whose modules are documented, supplying the module arguments a blueprint system provides
- `formatter` (`*null or package*`): the derivation exposed as the flake formatter for this system
- `internalLibrary` (`*attribute set*`): attrset of functions documented only in lib/README.md
- `library` (`*attribute set*`): attrset of functions to document in the index
- `modules` (`*attribute set*`): attrset of NixOS modules to document
- `packages` (`*attribute set*`): attrset of packages to document
- `pkgs` (`*attribute set*`): nixpkgs package set used to render and compare the documents
- `requireInternalDocumentation` (`*boolean*`): whether an internal export must state meta.description too, false when the internal surface may stay opaque
- `root` (`*absolute path*`): path to the repository root holding the committed READMEs
- `system` (`*string*`): system string selecting the documented outputs
- `templates` (`*attribute set*`): attrset of templates to document
- `url` (`*string*`): flake reference the templates are published under, empty when the flake states none

Fails when a committed README differs from the generated documentation, or when README.md and checks/README.md disagree about a check.

*Source:* [lib/default.nix:1980](default.nix)

## message

### assertion

```nix
lib.internal.message.assertion { at, condition, expected, fix, violation }
```

*Type:* function

*Arguments:*

- `at` (`*list of string*`): list of attribute names naming the option the assertion is about
- `condition` (`*boolean*`): the property being asserted, true when it holds
- `expected` (`*string*`): sentence saying what the configuration should look like instead
- `fix` (`*string*`): sentence saying how to make it look that way
- `violation` (`*string*`): sentence saying what is wrong when the condition is false

Builds an assertion record whose message states the violation, what was expected and how to fix it.

*Source:* [lib/default.nix:2098](default.nix)

### problems

```nix
lib.internal.message.problems { assertions, options }
```

*Type:* function

*Arguments:*

- `assertions` (`*list of (attribute set)*`): list of { assertion, message } records whose messages are inspected
- `options` (`*attribute set*`): evaluated option set the message paths are resolved against

Reports assertion messages that do not name a declared option, or that omit the expected value and the fix.

*Source:* [lib/default.nix:2126](default.nix)

## section

### group

```nix
lib.internal.section.group { body, sections, title }
```

*Type:* function

*Arguments:*

- `body` (`*null or string*`): markdown emitted under the title instead of child headings, null when there is none
- `sections` (`*list of (attribute set)*`): child sections, rendered one heading level deeper, empty when the group only holds prose
- `title` (`*string*`): heading text of the group

Groups child sections under one title, for a part of the document that is itself not a usable thing.

*Source:* [lib/default.nix:2302](default.nix)

### make

```nix
lib.internal.section.make { arguments, body, bodyFile, description, documented, internal, kind, language, problems, sections, source, tests, title, type, usage }
```

*Type:* function

*Arguments:*

- `arguments` (`*list of (attribute set)*`): list of { argument, argumentType } describing the call shape
- `body` (`*null or string*`): markdown emitted under the title, null when there is none
- `bodyFile` (`*null or absolute path*`): path to a rendered markdown fragment appended after the description
- `description` (`*string*`): sentence saying what the thing is for, empty when the title says it
- `documented` (`*boolean*`): whether authored prose exists for the thing, false when it is undocumented
- `internal` (`*boolean*`): whether the thing belongs to the internal surface, which is published but not part of the flake's contract
- `kind` (`*null or string*`): what sort of thing it is when the doc block describes it, function or value, null for sections that are not library exports
- `language` (`*string*`): code fence language of the usage snippet, for example nix or sh
- `problems` (`*list of string*`): problems found while documenting this thing, each reported as a check failure
- `sections` (`*list of (attribute set)*`): child sections, rendered one heading level deeper
- `source` (`*null or (attribute set)*`): { file, line } naming where the thing is defined in this repository, null when the location is unknown
- `tests` (`*list of (attribute set)*`): list of { test, documented } naming the checks the thing is tested by
- `title` (`*string*`): heading text naming the thing
- `type` (`*string*`): what the thing is, for example derivation, app or NixOS module
- `usage` (`*string*`): snippet that uses the thing, shown in a fenced block

One documented thing: what it is, how to call or import it, what its arguments are and any child sections.

*Source:* [lib/default.nix:2322](default.nix)

### render

```nix
lib.internal.section.render { depth, fromDir, s }
```

*Type:* function

*Arguments:*

- `depth` (`*signed integer*`): heading level of the section, 2 for a top-level section of a document
- `fromDir` (`*string*`): directory the rendered document lives in, so source links resolve relative to it
- `s` (`*attribute set*`): the section to render

Renders a list of sections into a README derivation.

*Source:* [lib/default.nix:2390](default.nix)

### tests

```nix
lib.internal.section.tests { tests }
```

*Type:* function

*Arguments:*

- `tests` (`*list of (attribute set)*`): list of { test, documented } records naming the checks a package is tested by

Renders the test links of a section: a markdown link when the check is documented, plain text when it is not.

*Source:* [lib/default.nix:2410](default.nix)

### write

```nix
lib.internal.section.write { description, fromDir, name, pkgs, sections }
```

*Type:* function

*Arguments:*

- `description` (`*string*`): statement of what the flake is for, printed under the title; when name is empty its first line titles the document and the rest of it is printed under that title
- `fromDir` (`*string*`): directory the rendered document lives in, so source links resolve relative to it
- `name` (`*string*`): title of the document, the first line of the description when it is empty
- `pkgs` (`*attribute set*`): nixpkgs package set the document derivation is built with
- `sections` (`*list of (attribute set)*`): sections to render, in order

Writes one document: a heading, the statement of purpose, and the sections rendered in order.

*Source:* [lib/default.nix:2420](default.nix)

## shells

### dev

```nix
lib.internal.shells.dev { devShellConfig, pkgs, preCommit }
```

*Type:* function

*Arguments:*

- `devShellConfig` (`*attribute set*`): evalModule-shaped configuration merged into the default development shell
- `pkgs` (`*attribute set*`): nixpkgs package set the shell is built with
- `preCommit` (`*attribute set*`): pre-commit check whose packages and hook the shell exposes

Shell environment carrying the formatter's packages and its shell hook.

*Source:* [lib/default.nix:2485](default.nix)

