# Modules

SYNACKDOCHE GAMES - Base Flake — modules

## meta-options

```nix
imports = [ inputs.<flake>.nixosModules.meta-options ];
```

*Type:* NixOS module

Declares the module metadata options the documentation pipeline reads, so a module states its summary and its worked example without declaring options itself.

*Source:* [modules/nixos/meta-options.nix](nixos/meta-options.nix)

### Options

#### meta.description

Summary the documentation pipeline shows as the module's heading description.

*Type:* null or string

**Internal.**

#### meta.example

Worked configuration the documentation pipeline renders under the module and checks against the module's declared options.

*Type:* null or anything

**Internal.**


### example

```nix
{
  meta = {
    description = "An example";
    example = {
      optionA = "example";
      optionB = 42;
    };
  };
}
```

*Type:* example configuration

A configuration that satisfies the interface above.

