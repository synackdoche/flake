{
  description = ''
    SYNACKDOCHE GAMES - Base Flake

    shared formatter, pre-commit, docgate checks and flake scaffolding
  '';
  inputs = {
    blueprint = {
      inputs.nixpkgs.follows = "nixpkgs";
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
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
  outputs =
    { blueprint, ... }@inputs:
    let
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
        pkgs:
        import ./formatter.nix {
          inherit pkgs;
          flake.inputs = {
            inherit (inputs) pedantix treefmt-nix;
          };
        };
      lib = inputs.nixpkgs.lib;
      mixin =
        args:
        let
          defaults = lib.listToAttrs (
            map (system: {
              name = system;
              value = defaultsFor system;
            }) (args.systems or [ ])
          );
          defaultsFor =
            system:
            let
              existingChecks = generated.checks.${system} or { };
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              preCommit = own.lib.internal.dev.preCommit {
                inherit pkgs;
                src = self.outPath;
              };
            in
            {
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
                };
              devShells.default =
                (generated.devShells.${system} or { }).default or (own.lib.internal.shells.dev {
                  inherit pkgs;
                  preCommit = existingChecks.pre-commit or preCommit;
                });
              formatter = formatterFor pkgs;
              packages.docs = (generated.packages.${system} or { }).docs or (docsFor system);
            };
          generated = blueprint args;
          hasOwnFormatter = builtins.pathExists (self.outPath + "/formatter.nix");
          self = args.inputs.self;
        in
        generated
        // {
          checks =
            (generated.checks or { })
            // lib.mapAttrs (system: d: (generated.checks.${system} or { }) // d.checks) defaults;
          devShells =
            (generated.devShells or { })
            // lib.mapAttrs (system: d: (generated.devShells.${system} or { }) // d.devShells) defaults;
          formatter =
            (generated.formatter or { })
            // lib.mapAttrs (
              system: d: if hasOwnFormatter then generated.formatter.${system} else d.formatter
            ) defaults;
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
        systems = [ "x86_64-linux" ];
      };
      strippedMetaOptions = ./lib/meta-options.nix;
    in
    own
    // {
      __functor = _: mixin;
      docsSettings.requireInternalDocumentation = true;
      url = "github:synackdoche/flake";
    };
}
