{
  description = ''
    SYNACKDOCHE GAMES - Base Flake

    shared formatter, pre-commit, docgate checks and flake scaffolding
  '';
  inputs = {
    blueprint = {
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:numtide/blueprint";
    };
    flake-compat.url = "github:NixOS/flake-compat";
    git-hooks = {
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    nixpkgs.url = "github:synackdoche/nixpkgs/nixos-26.05";
    pedantix = {
      inputs = {
        git-hooks-nix.inputs.flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
      url = "github:swarsel/pedantix";
    };
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
  outputs =
    { blueprint, ... }@inputs:
    let
      baseSystems = import inputs.systems;
      docsFor =
        system:
        let
          docs = own.lib.internal.docs.app { pkgs = inputs.nixpkgs.legacyPackages.${system}; };
        in
        docs
        // {
          meta = (docs.meta or { }) // {
            mainProgram = "docs";
          };
        };
      formatterFor =
        pkgs: formatterConfig:
        import ./formatter.nix {
          inherit pkgs formatterConfig;
          flake.inputs = {
            inherit (inputs) pedantix treefmt-nix;
          };
        };
      functorArgs = {
        devShellConfig = {
          description = "evalModule-shaped configuration merged into the default development shell, so a client adds packages or a shell hook";
          type = lib.types.attrs;
        };
        flakeInputs = {
          description = "settings of the flake-inputs gate, whose ignore list names inputs allowed to resolve outside the repository";
          type = lib.types.attrs;
        };
        formatterConfig = {
          description = "evalModule-shaped treefmt configuration merged into the canonical formatter";
          type = lib.types.attrs;
        };
        inputs = {
          description = "the client flake's inputs, which the mixin reads for the client's own outputs and nixpkgs";
          type = lib.types.attrs;
        };
        preCommitHooks = {
          description = "function of the system's package set returning git-hooks definitions merged into the pre-commit hook set";
          type = lib.types.functionTo lib.types.attrs;
        };
        systems = {
          description = "systems the mixin emits outputs for, empty when the client states none";
          type = lib.types.listOf lib.types.str;
        };
      };
      lib = inputs.nixpkgs.lib;
      mixin =
        {
          inputs,
          devShellConfig ? { },
          flakeInputs ? { },
          formatterConfig ? { },
          preCommitHooks ? (_: { }),
          systems ? [ ],
        }:
        let
          inherit (inputs) self;
          defaults = lib.listToAttrs (
            map (system: {
              name = system;
              value = defaultsFor system;
            }) systems
          );
          defaultsFor =
            system:
            let
              docs = docsFor system;
              existingChecks = generated.checks.${system} or { };
              formatter =
                if hasOwnFormatter then generated.formatter.${system} else formatterFor pkgs formatterConfig;
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              preCommit = own.lib.internal.dev.preCommit {
                inherit docs formatter pkgs;
                extraHooks = preCommitHooks pkgs;
                src = self.outPath;
              };
            in
            {
              inherit formatter;
              checks =
                { }
                // lib.optionalAttrs (!(existingChecks ? readme)) {
                  readme = own.lib.internal.gate.readme (
                    own.lib.internal.flake.args {
                      inherit pkgs;
                      checks = { };
                      flake = self;
                      root = self.outPath;
                    }
                  );
                }
                // lib.optionalAttrs (!(existingChecks ? "pre-commit")) {
                  pre-commit = preCommit;
                }
                // lib.optionalAttrs (!(existingChecks ? documentation)) {
                  documentation = own.lib.internal.gate.docs {
                    inherit pkgs;
                    flake = self;
                    root = self.outPath;
                  };
                }
                // lib.optionalAttrs (!(existingChecks ? "flake-inputs")) {
                  flake-inputs = own.lib.internal.gate.flakeInputs {
                    inherit pkgs;
                    ignore = flakeInputs.ignore or [ ];
                    root = self.outPath;
                  };
                };
              devShells.default =
                (generated.devShells.${system} or { }).default or (own.lib.internal.shells.dev {
                  inherit pkgs;
                  inherit devShellConfig;
                  preCommit = existingChecks.pre-commit or preCommit;
                });
              packages.docs = (generated.packages.${system} or { }).docs or docs;
            };
          generated = blueprint { inherit inputs systems; };
          hasOwnFormatter = builtins.pathExists (self.outPath + "/formatter.nix");
        in
        generated
        // {
          checks =
            (generated.checks or { })
            // lib.mapAttrs (system: d: (generated.checks.${system} or { }) // d.checks) defaults;
          devShells =
            (generated.devShells or { })
            // lib.mapAttrs (system: d: (generated.devShells.${system} or { }) // d.devShells) defaults;
          formatter = (generated.formatter or { }) // lib.mapAttrs (_system: d: d.formatter) defaults;
          nixosConfigurations = lib.mapAttrs (
            _name: configuration:
            configuration.extendModules {
              modules = [ strippedMetaOptions ];
            }
          ) (generated.nixosConfigurations or { });
          nixosModules = lib.mapAttrs (_name: module: {
            imports = [ strippedMetaOptions ] ++ lib.toList module;
          }) (generated.nixosModules or { });
          packages =
            (generated.packages or { })
            // lib.mapAttrs (system: d: (generated.packages.${system} or { }) // d.packages) defaults;
        }
        // lib.optionalAttrs (generated ? lib) {
          lib = own.lib.internal.buildDocumented.functions (
            builtins.removeAttrs generated.lib [ "internal" ]
          );
          libDeclarations = generated.lib;
        };
      own = blueprint {
        inherit inputs;
        systems = baseSystems;
      };
      strippedMetaOptions = ./lib/meta-options.nix;
    in
    own
    // {
      __functor = _: mixin;
      docsSettings.requireInternalDocumentation = true;
      meta = {
        args = lib.mapAttrs (name: _hasDefault: functorArgs.${name}) (builtins.functionArgs mixin);
        description = "Mixes the shared formatter, pre-commit hook set, documentation gate, checks and development shell into a client flake.";
      };
      url = "github:synackdoche/flake";
    };
}
